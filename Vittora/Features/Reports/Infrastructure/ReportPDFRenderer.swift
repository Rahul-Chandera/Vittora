import CoreGraphics
import SwiftUI

/// Renders purpose-built SwiftUI report pages to an A4 portrait PDF (R1).
@MainActor
enum ReportPDFRenderer {
    /// A4 portrait in points (72 dpi).
    static let pageWidth: CGFloat = 595.28
    static let pageHeight: CGFloat = 841.89
    static let pageInset: CGFloat = 36

    enum ExportError: LocalizedError {
        case renderFailed
        case emptyPages

        var errorDescription: String? {
            String(localized: "We couldn't create the PDF report.")
        }
    }

    /// Renders each page view into a multi-page A4 PDF at a temporary URL.
    static func export<V: View>(pages: [V], fileName: String) throws -> URL {
        guard !pages.isEmpty else {
            throw ExportError.emptyPages
        }

        let sanitized = fileName.filter { character in
            character.isLetter || character.isNumber || character == "-" || character == "_"
        }
        let baseName = sanitized.isEmpty ? "vittora-report" : sanitized
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(baseName)
            .appendingPathExtension("pdf")

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            throw ExportError.renderFailed
        }

        for page in pages {
            let pageView = page
                .frame(width: pageWidth, height: pageHeight, alignment: .topLeading)
                .background(Color.white)
                .environment(\.colorScheme, .light)

            let renderer = ImageRenderer(content: pageView)
            renderer.proposedSize = ProposedViewSize(width: pageWidth, height: pageHeight)

            var didDrawPage = false
            renderer.render { _, draw in
                pdfContext.beginPDFPage(nil)
                draw(pdfContext)
                pdfContext.endPDFPage()
                didDrawPage = true
            }

            guard didDrawPage else {
                pdfContext.closePDF()
                throw ExportError.renderFailed
            }
        }

        pdfContext.closePDF()

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let fileSize = attributes[.size] as? Int, fileSize > 0 else {
            throw ExportError.renderFailed
        }

        return url
    }

    /// Counts PDF pages via Core Graphics (for tests and verification).
    static func pageCount(at url: URL) -> Int {
        guard let document = CGPDFDocument(url as CFURL) else { return 0 }
        return document.numberOfPages
    }
}
