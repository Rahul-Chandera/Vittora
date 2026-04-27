import SwiftUI
#if canImport(PDFKit)
import PDFKit
#endif

struct DocumentPreviewItem: Identifiable, Sendable {
    let id: UUID
    let fileName: String
    let mimeType: String
    let data: Data
}

struct DocumentPreviewView: View {
    let item: DocumentPreviewItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            previewContent
                .ignoresSafeArea()
                .navigationTitle(item.fileName)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Done")) {
                            dismiss()
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch item.mimeType {
        case "application/pdf":
            PDFPreviewRepresentable(data: item.data)
        case let mimeType where mimeType.hasPrefix("image/"):
            imagePreview
        default:
            previewUnavailable(
                title: String(localized: "Preview Unavailable"),
                systemImage: "doc.text.magnifyingglass",
                description: String(localized: "This document type cannot be previewed.")
            )
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        #if os(iOS)
        if let image = UIImage(data: item.data) {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(VColors.background)
        } else {
            previewUnavailable(
                title: String(localized: "Preview Unavailable"),
                systemImage: "photo",
                description: String(localized: "The encrypted document could not be decoded for preview.")
            )
        }
        #elseif os(macOS)
        if let image = NSImage(data: item.data) {
            ScrollView([.horizontal, .vertical]) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(VColors.background)
        } else {
            previewUnavailable(
                title: String(localized: "Preview Unavailable"),
                systemImage: "photo",
                description: String(localized: "The encrypted document could not be decoded for preview.")
            )
        }
        #else
        previewUnavailable(
            title: String(localized: "Preview Unavailable"),
            systemImage: "photo",
            description: String(localized: "The encrypted document could not be decoded for preview.")
        )
        #endif
    }

    private func previewUnavailable(
        title: String,
        systemImage: String,
        description: String
    ) -> some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
        )
    }
}

#if os(iOS)
import UIKit

struct PDFPreviewRepresentable: UIViewRepresentable {
    let data: Data

    final class Coordinator {
        var lastDataSignature: UInt64?
        var document: PDFDocument?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        let signature = pdfDataSignature(data)
        if context.coordinator.lastDataSignature != signature {
            context.coordinator.lastDataSignature = signature
            context.coordinator.document = PDFDocument(data: data)
        }
        pdfView.document = context.coordinator.document
    }
}
#elseif os(macOS)
import AppKit

struct PDFPreviewRepresentable: NSViewRepresentable {
    let data: Data

    final class Coordinator {
        var lastDataSignature: UInt64?
        var document: PDFDocument?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        let signature = pdfDataSignature(data)
        if context.coordinator.lastDataSignature != signature {
            context.coordinator.lastDataSignature = signature
            context.coordinator.document = PDFDocument(data: data)
        }
        pdfView.document = context.coordinator.document
    }
}
#endif

private func pdfDataSignature(_ data: Data) -> UInt64 {
    // Lightweight rolling hash to avoid reparsing identical PDF bytes.
    data.reduce(14_695_981_039_346_656_037) { hash, byte in
        (hash ^ UInt64(byte)) &* 1_099_511_628_211
    }
}

#Preview {
    DocumentPreviewView(
        item: DocumentPreviewItem(
            id: UUID(),
            fileName: "receipt.pdf",
            mimeType: "application/pdf",
            data: Data()
        )
    )
}
