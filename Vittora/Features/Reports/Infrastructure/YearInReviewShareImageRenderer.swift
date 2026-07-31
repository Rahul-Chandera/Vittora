import SwiftUI
import VittoraCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

enum YearInReviewShareImageRenderer {
    @MainActor
    static func render(
        summary: YearInReviewSummary,
        includeAmounts: Bool
    ) throws -> URL {
        let card = YearInReviewShareCard(summary: summary, includeAmounts: includeAmounts)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2

        #if canImport(UIKit)
        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw YearInReviewShareError.renderFailed
        }
        #elseif canImport(AppKit)
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw YearInReviewShareError.renderFailed
        }
        #else
        throw YearInReviewShareError.renderFailed
        #endif

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vittora-year-in-review-\(UUID().uuidString).png")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Text inventory that must match what `YearInReviewShareCard` draws.
    static func renderedTextLines(
        summary: YearInReviewSummary,
        includeAmounts: Bool
    ) -> [String] {
        YearInReviewShareCopy.lines(
            summary: summary,
            includeAmounts: includeAmounts,
            currencyCode: summary.currencyCode
        )
    }
}

enum YearInReviewShareError: Error {
    case renderFailed
}
