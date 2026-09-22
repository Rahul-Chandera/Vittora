import CoreGraphics
import Foundation
import VittoraCore

/// Combines scanned pages into a single PDF.
///
/// Multi-page scanning stores one document, not one per page, so the existing
/// `DocumentEntity` carries it unchanged: `mimeType` becomes `application/pdf`,
/// which `AttachDocumentUseCase` and `DocumentPreviewView` already handle. No
/// schema change and no migration — PDF is the container the format was designed
/// for, and PDFKit gives paging in the preview for free.
///
/// Built on CoreGraphics rather than `UIGraphicsPDFRenderer` so the same code
/// compiles for macOS, where scanning falls back to file import but assembly is
/// still reachable.
nonisolated struct MultiPageDocumentBuilder: Sendable {

    /// Each page keeps its own dimensions. Receipts are photographed at whatever
    /// aspect the page happens to be, and forcing them onto a uniform mediaBox
    /// letterboxes some and crops others.
    func pdfData(from pages: [CGImage]) throws -> Data {
        guard !pages.isEmpty else { throw DocumentError.pdfAssemblyFailed }

        let buffer = NSMutableData()
        guard let consumer = CGDataConsumer(data: buffer) else {
            throw DocumentError.pdfAssemblyFailed
        }

        // The context needs an initial mediaBox; every page then overrides it.
        var initialBox = Self.box(for: pages[0])
        guard let context = CGContext(consumer: consumer, mediaBox: &initialBox, nil) else {
            throw DocumentError.pdfAssemblyFailed
        }

        for page in pages {
            var box = Self.box(for: page)
            context.beginPage(mediaBox: &box)
            context.draw(page, in: box)
            context.endPage()
        }
        context.closePDF()

        guard !buffer.isEmpty else { throw DocumentError.pdfAssemblyFailed }
        return buffer as Data
    }

    private static func box(for image: CGImage) -> CGRect {
        CGRect(x: 0, y: 0, width: image.width, height: image.height)
    }
}
