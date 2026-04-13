import Foundation
import CoreGraphics

struct ReceiptData: Sendable {
    let totalAmount: Decimal?
    let date: Date?
    let merchantName: String?
    let lineItems: [(name: String, amount: Decimal)]
    let rawText: String
}

struct RecognizedTextBlock: Sendable {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

protocol OCRServiceProtocol: Sendable {
    func scanReceipt(from image: CGImage) async throws -> ReceiptData
    func extractText(from image: CGImage) async throws -> [RecognizedTextBlock]
}
