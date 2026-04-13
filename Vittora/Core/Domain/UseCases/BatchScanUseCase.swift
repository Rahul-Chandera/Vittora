import Foundation
import CoreGraphics

struct BatchScanUseCase: Sendable {
    let ocrService: any OCRServiceProtocol
    let attachUseCase: AttachDocumentUseCase

    func execute(
        images: [CGImage],
        mimeType: String = "image/jpeg",
        transactionID: UUID? = nil,
        imageDataProvider: @Sendable (CGImage) -> Data?
    ) async throws -> [ReceiptData] {
        try await withThrowingTaskGroup(of: ReceiptData.self) { group in
            for image in images {
                group.addTask {
                    try await ocrService.scanReceipt(from: image)
                }
            }
            var results: [ReceiptData] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
}
