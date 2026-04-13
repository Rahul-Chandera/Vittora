import Foundation
import Vision
import CoreGraphics

actor OCRService: OCRServiceProtocol {

    private let parser = ReceiptParserService()

    func extractText(from image: CGImage) async throws -> [RecognizedTextBlock] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = ImageRequestHandler(image)
        let observations = try await handler.perform(request)

        return observations.compactMap { observation -> RecognizedTextBlock? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedTextBlock(
                text: candidate.string,
                confidence: candidate.confidence,
                boundingBox: .zero
            )
        }
    }

    func scanReceipt(from image: CGImage) async throws -> ReceiptData {
        let blocks = try await extractText(from: image)
        return parser.parse(blocks: blocks)
    }
}
