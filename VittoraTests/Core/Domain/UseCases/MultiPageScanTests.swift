import CoreGraphics
import Foundation
import Testing
import VittoraCore
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#if canImport(PDFKit)
import PDFKit
#endif
@testable import Vittora

// MARK: - PDF assembly

@Suite("MultiPageDocumentBuilder")
struct MultiPageDocumentBuilderTests {

    @Test("one PDF page per scanned page, in order")
    func pageCountMatchesInput() throws {
        let builder = MultiPageDocumentBuilder()
        let pages = try (1...3).map { _ in try #require(makeTestImage()) }

        let data = try builder.pdfData(from: pages)

        #if canImport(PDFKit)
        let document = try #require(PDFDocument(data: data))
        #expect(document.pageCount == 3)
        #endif
    }

    /// The whole point of the feature is that several pages become ONE attachment.
    /// If this ever produced one document per page it would be batch scan, which
    /// already exists separately.
    @Test("a single page still produces a valid one-page PDF")
    func singlePage() throws {
        let data = try MultiPageDocumentBuilder().pdfData(from: [try #require(makeTestImage())])
        #if canImport(PDFKit)
        #expect(PDFDocument(data: data)?.pageCount == 1)
        #endif
    }

    /// Pages keep their own dimensions rather than being forced onto a shared
    /// mediaBox, so a portrait receipt followed by a landscape one is not cropped.
    @Test("each page keeps its own size")
    func mixedPageSizes() throws {
        let tall = try #require(makeTestImage(width: 8, height: 40))
        let wide = try #require(makeTestImage(width: 40, height: 8))

        let data = try MultiPageDocumentBuilder().pdfData(from: [tall, wide])

        #if canImport(PDFKit)
        let document = try #require(PDFDocument(data: data))
        let first = try #require(document.page(at: 0)).bounds(for: .mediaBox)
        let second = try #require(document.page(at: 1)).bounds(for: .mediaBox)
        #expect(first.height > first.width)
        #expect(second.width > second.height)
        #endif
    }

    @Test("no pages is an error, not an empty PDF")
    func emptyInputThrows() {
        #expect(throws: DocumentError.self) {
            try MultiPageDocumentBuilder().pdfData(from: [])
        }
    }
}

// MARK: - Multi-page OCR

// @MainActor because ReceiptData's properties are main-actor isolated under the
// app target's SWIFT_DEFAULT_ACTOR_ISOLATION, matching BatchScanUseCaseTests.
@Suite("ScanMultiPageReceiptUseCase")
@MainActor
struct ScanMultiPageReceiptUseCaseTests {

    /// Returns one block per page, so the parser's input proves whether every page
    /// was recognised or only the first.
    private struct PerPageOCR: OCRServiceProtocol {
        func scanReceipt(from image: CGImage) async throws -> ReceiptData {
            ReceiptData(totalAmount: nil, date: nil, merchantName: nil, lineItems: [], rawText: "")
        }

        func extractText(from image: CGImage) async throws -> [RecognizedTextBlock] {
            // Width identifies the page, so text differs per page.
            [RecognizedTextBlock(text: "page\(image.width)", confidence: 1, boundingBox: .zero)]
        }
    }

    private struct FailingFirstPageOCR: OCRServiceProtocol {
        func scanReceipt(from image: CGImage) async throws -> ReceiptData {
            ReceiptData(totalAmount: nil, date: nil, merchantName: nil, lineItems: [], rawText: "")
        }

        func extractText(from image: CGImage) async throws -> [RecognizedTextBlock] {
            if image.width == 1 { throw DocumentError.ocrFailed("blurred page") }
            return [RecognizedTextBlock(text: "TOTAL 42.00", confidence: 1, boundingBox: .zero)]
        }
    }

    private struct AlwaysFailingOCR: OCRServiceProtocol {
        func scanReceipt(from image: CGImage) async throws -> ReceiptData {
            throw DocumentError.ocrFailed("nope")
        }

        func extractText(from image: CGImage) async throws -> [RecognizedTextBlock] {
            throw DocumentError.ocrFailed("nope")
        }
    }

    /// A receipt running to several pages has the merchant on page 1 and the total
    /// on the last, so OCRing only page 1 would find a merchant and no total.
    @Test("every page is recognised, not just the first")
    func allPagesContribute() async throws {
        let pages = [
            try #require(makeTestImage(width: 4)),
            try #require(makeTestImage(width: 8)),
            try #require(makeTestImage(width: 16)),
        ]

        let receipt = try await ScanMultiPageReceiptUseCase(ocrService: PerPageOCR())
            .execute(pages: pages)

        #expect(receipt.rawText.contains("page4"))
        #expect(receipt.rawText.contains("page8"))
        #expect(receipt.rawText.contains("page16"))
    }

    @Test("pages are concatenated in scan order")
    func pageOrderPreserved() async throws {
        let pages = [
            try #require(makeTestImage(width: 4)),
            try #require(makeTestImage(width: 16)),
        ]

        let receipt = try await ScanMultiPageReceiptUseCase(ocrService: PerPageOCR())
            .execute(pages: pages)

        let first = try #require(receipt.rawText.range(of: "page4"))
        let second = try #require(receipt.rawText.range(of: "page16"))
        #expect(first.lowerBound < second.lowerBound)
    }

    /// One blurred page out of several should not discard the whole scan.
    @Test("a page that fails recognition is skipped, not fatal")
    func partialFailureStillParses() async throws {
        let pages = [
            try #require(makeTestImage(width: 1)),
            try #require(makeTestImage(width: 8)),
        ]

        let receipt = try await ScanMultiPageReceiptUseCase(ocrService: FailingFirstPageOCR())
            .execute(pages: pages)

        #expect(receipt.totalAmount == Decimal(string: "42.00"))
    }

    @Test("no text on any page throws rather than returning an empty receipt")
    func totalFailureThrows() async throws {
        let pages = [try #require(makeTestImage())]
        await #expect(throws: DocumentError.self) {
            try await ScanMultiPageReceiptUseCase(ocrService: AlwaysFailingOCR())
                .execute(pages: pages)
        }
    }

    @Test("no pages throws")
    func emptyPagesThrows() async {
        await #expect(throws: DocumentError.self) {
            try await ScanMultiPageReceiptUseCase(ocrService: PerPageOCR()).execute(pages: [])
        }
    }
}

// MARK: - Shared helper

private func makeTestImage(width: Int = 8, height: Int = 8) -> CGImage? {
    #if canImport(UIKit)
    let size = CGSize(width: width, height: height)
    UIGraphicsBeginImageContext(size)
    defer { UIGraphicsEndImageContext() }
    UIColor.white.setFill()
    UIRectFill(CGRect(origin: .zero, size: size))
    return UIGraphicsGetImageFromCurrentImageContext()?.cgImage
    #elseif canImport(AppKit)
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    image.unlockFocus()
    return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    #else
    return nil
    #endif
}
