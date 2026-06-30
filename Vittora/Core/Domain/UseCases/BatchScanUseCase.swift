import Foundation
import CoreGraphics
import VittoraCore

struct BatchScanInput: Sendable {
    let cgImage: CGImage
    let imageData: Data
    let mimeType: String
}

struct BatchScanUseCase: Sendable {
    let ocrService: any OCRServiceProtocol

    /// OCR-only batch scan (parallel).
    func scanReceipts(from images: [CGImage]) async throws -> [ReceiptData] {
        guard !images.isEmpty else { return [] }
        return try await withThrowingTaskGroup(of: (Int, ReceiptData).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    let receipt = try await self.ocrService.scanReceipt(from: image)
                    return (index, receipt)
                }
            }
            var indexed: [(Int, ReceiptData)] = []
            for try await item in group {
                indexed.append(item)
            }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    /// Scan multiple receipt images, attach each to a transaction, return OCR results in order.
    func scanAndAttach(
        inputs: [BatchScanInput],
        transactionID: UUID,
        attachUseCase: AttachDocumentUseCase
    ) async throws -> [ReceiptData] {
        guard !inputs.isEmpty else { return [] }
        return try await withThrowingTaskGroup(of: (Int, ReceiptData).self) { group in
            for (index, input) in inputs.enumerated() {
                group.addTask {
                    let receipt = try await self.ocrService.scanReceipt(from: input.cgImage)
                    _ = try await attachUseCase.execute(
                        imageData: input.imageData,
                        mimeType: input.mimeType,
                        transactionID: transactionID
                    )
                    return (index, receipt)
                }
            }
            var indexed: [(Int, ReceiptData)] = []
            for try await item in group {
                indexed.append(item)
            }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}
