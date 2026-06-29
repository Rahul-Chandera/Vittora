import CoreGraphics
import SwiftUI

/// Renders a SwiftUI report layout to a temporary PDF file for ShareLink export (K4).
@MainActor
enum ReportPDFExporter {
    enum ExportError: LocalizedError {
        case renderFailed

        var errorDescription: String? {
            String(localized: "We couldn't create the PDF report.")
        }
    }

    private static let pageWidth: CGFloat = 595.2

    static func export<V: View>(_ content: V, fileName: String) throws -> URL {
        let exportContent = content
            .frame(width: pageWidth, alignment: .leading)
            .padding(32)
            .background(Color.white)
            .environment(\.colorScheme, .light)

        let sanitized = fileName.filter { character in
            character.isLetter || character.isNumber || character == "-" || character == "_"
        }
        let baseName = sanitized.isEmpty ? "vittora-report" : sanitized
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(baseName)
            .appendingPathExtension("pdf")

        let renderer = ImageRenderer(content: exportContent)
        renderer.proposedSize = ProposedViewSize(width: pageWidth, height: nil)

        var didRender = false
        renderer.render { size, draw in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
            else {
                return
            }

            pdfContext.beginPDFPage(nil)
            draw(pdfContext)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
            didRender = true
        }

        guard didRender else {
            throw ExportError.renderFailed
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let fileSize = attributes[.size] as? Int, fileSize > 0 else {
            throw ExportError.renderFailed
        }

        return url
    }
}
