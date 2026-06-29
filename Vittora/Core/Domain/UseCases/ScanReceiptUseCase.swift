import Foundation
import CoreGraphics
import VittoraCore

struct ScanReceiptUseCase: Sendable {
    let ocrService: any OCRServiceProtocol

    func execute(image: CGImage) async throws -> ReceiptData {
        do {
            return try await ocrService.scanReceipt(from: image)
        } catch {
            throw DocumentError.ocrFailed(error.localizedDescription)
        }
    }
}
