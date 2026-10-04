import CoreGraphics
import Foundation
import VittoraCore

/// OCRs every page of a multi-page scan and parses the result as one receipt.
///
/// A receipt that runs to several pages is still one receipt: the merchant is on
/// page 1 and the total is usually on the last. OCRing only the first page would
/// find a merchant and no total, so every page is recognised and the text blocks
/// are concatenated in page order before a single parse.
///
/// Pages that fail recognition are skipped rather than failing the scan — one
/// blurred page out of four should still yield a usable total. The scan only
/// fails when no page produced any text at all.
struct ScanMultiPageReceiptUseCase: Sendable {
    let ocrService: any OCRServiceProtocol
    private let parser = ReceiptParserService()

    func execute(pages: [CGImage]) async throws -> ReceiptData {
        guard !pages.isEmpty else {
            throw DocumentError.ocrFailed(String(localized: "There were no pages to scan."))
        }

        var blocks: [RecognizedTextBlock] = []
        var lastError: Error?

        for page in pages {
            do {
                blocks.append(contentsOf: try await ocrService.extractText(from: page))
            } catch {
                lastError = error
            }
        }

        guard !blocks.isEmpty else {
            throw DocumentError.ocrFailed(
                lastError?.localizedDescription
                    ?? String(localized: "No text was found on any page.")
            )
        }

        return parser.parse(blocks: blocks)
    }
}
