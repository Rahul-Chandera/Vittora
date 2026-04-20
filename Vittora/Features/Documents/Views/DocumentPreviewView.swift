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

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = PDFDocument(data: data)
    }
}
#elseif os(macOS)
import AppKit

struct PDFPreviewRepresentable: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        pdfView.document = PDFDocument(data: data)
    }
}
#endif

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
