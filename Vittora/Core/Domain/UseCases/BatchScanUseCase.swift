import Foundation
import CoreGraphics
import OSLog
import VittoraCore

struct BatchScanInput: Sendable {
    let cgImage: CGImage
    let imageData: Data
    let mimeType: String
}

struct BatchScanOutcome: Sendable {
    let receipts: [ReceiptData]
    let attachedCount: Int
    let failureCount: Int

    var hadPartialFailure: Bool {
        failureCount > 0 && (attachedCount > 0 || !receipts.isEmpty)
    }

    var isTotalFailure: Bool {
        attachedCount == 0 && receipts.isEmpty && failureCount > 0
    }
}

struct BatchScanUseCase: Sendable {
    private nonisolated(unsafe) static let logger = Logger(subsystem: "com.vittora.app", category: "batch_scan")

    let ocrService: any OCRServiceProtocol

    /// OCR-only batch scan (parallel). Individual image failures are logged and skipped.
    func scanReceipts(from images: [CGImage]) async -> BatchScanOutcome {
        guard !images.isEmpty else {
            return BatchScanOutcome(receipts: [], attachedCount: 0, failureCount: 0)
        }
        return await withTaskGroup(of: (Int, ReceiptData?).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    do {
                        let receipt = try await self.ocrService.scanReceipt(from: image)
                        return (index, receipt)
                    } catch {
                        Self.logger.error(
                            "Batch OCR failed for image index=\(index, privacy: .public): \(error.localizedDescription, privacy: .public)"
                        )
                        return (index, nil)
                    }
                }
            }
            var indexed: [(Int, ReceiptData)] = []
            var failures = 0
            for await (index, receipt) in group {
                if let receipt {
                    indexed.append((index, receipt))
                } else {
                    failures += 1
                }
            }
            let receipts = indexed.sorted { $0.0 < $1.0 }.map(\.1)
            return BatchScanOutcome(
                receipts: receipts,
                attachedCount: receipts.count,
                failureCount: failures
            )
        }
    }

    /// Scan and attach each image. OCR or attach failures for one image do not abort the batch.
    func scanAndAttach(
        inputs: [BatchScanInput],
        transactionID: UUID,
        attachUseCase: AttachDocumentUseCase
    ) async -> BatchScanOutcome {
        guard !inputs.isEmpty else {
            return BatchScanOutcome(receipts: [], attachedCount: 0, failureCount: 0)
        }
        return await withTaskGroup(of: (Int, ReceiptData?, Bool).self) { group in
            for (index, input) in inputs.enumerated() {
                group.addTask {
                    var receipt: ReceiptData?
                    do {
                        receipt = try await self.ocrService.scanReceipt(from: input.cgImage)
                    } catch {
                        Self.logger.error(
                            "Batch OCR failed for image index=\(index, privacy: .public): \(error.localizedDescription, privacy: .public)"
                        )
                    }
                    do {
                        _ = try await attachUseCase.execute(
                            imageData: input.imageData,
                            mimeType: input.mimeType,
                            transactionID: transactionID
                        )
                        return (index, receipt, true)
                    } catch {
                        Self.logger.error(
                            "Batch attach failed for image index=\(index, privacy: .public): \(error.localizedDescription, privacy: .public)"
                        )
                        return (index, receipt, false)
                    }
                }
            }
            var indexed: [(Int, ReceiptData)] = []
            var attached = 0
            var failures = 0
            for await (index, receipt, didAttach) in group {
                if didAttach {
                    attached += 1
                    if let receipt {
                        indexed.append((index, receipt))
                    }
                } else {
                    failures += 1
                }
            }
            let receipts = indexed.sorted { $0.0 < $1.0 }.map(\.1)
            return BatchScanOutcome(
                receipts: receipts,
                attachedCount: attached,
                failureCount: failures
            )
        }
    }
}
