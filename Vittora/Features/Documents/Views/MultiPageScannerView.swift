import SwiftUI
import VittoraCore
#if os(iOS)
import VisionKit
#endif

/// Multi-page document scanning (M1.6.6).
///
/// Uses `VNDocumentCameraViewController` rather than the `DataScannerViewController`
/// behind `ReceiptScannerView`. DataScanner is a live-text scanner that captures one
/// frame on tap; the document camera is the multi-page one, and it brings edge
/// detection, per-page retake, reordering and a page count with it. Reimplementing
/// any of that on top of DataScanner would be strictly worse.
///
/// The pages become a single PDF, so one scan is one attachment.
struct MultiPageScannerView: View {
    let onPagesCaptured: (Data, ReceiptData?) -> Void

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var error: String?

    var body: some View {
        ZStack {
            #if os(iOS)
            iOSContent
            #else
            macFallbackContent
            #endif

            if isProcessing {
                ScannerOverlayView(isProcessing: true)
            }
        }
        .errorAlert(message: $error)
    }

    #if os(iOS)
    @ViewBuilder
    private var iOSContent: some View {
        // The document camera needs a real camera. Without this guard the sheet
        // presents an unresponsive black screen on the Simulator and on any device
        // where it is unavailable, with no way out but force-quitting. Import is
        // the same end state — a multi-page PDF — so fall back to it.
        if VNDocumentCameraViewController.isSupported {
            DocumentCameraRepresentable(
                onScan: { pages in
                    Task { await process(pages: pages) }
                },
                onCancel: { dismiss() },
                onError: { error = $0 }
            )
            .ignoresSafeArea()
        } else {
            DocumentImportView(onDocumentSelected: { data, _ in
                onPagesCaptured(data, nil)
                dismiss()
            })
        }
    }
    #else
    @ViewBuilder
    private var macFallbackContent: some View {
        // No document camera on macOS. Import already accepts a multi-page PDF,
        // which is the same end state as a scan.
        DocumentImportView(onDocumentSelected: { data, _ in
            onPagesCaptured(data, nil)
            dismiss()
        })
    }
    #endif

    #if os(iOS)
    @MainActor
    private func process(pages: [CGImage]) async {
        isProcessing = true
        defer { isProcessing = false }

        let builder = MultiPageDocumentBuilder()
        let pdfData: Data
        do {
            pdfData = try builder.pdfData(from: pages)
        } catch let assemblyError {
            error = assemblyError.userFacingMessage(
                fallback: String(localized: "We couldn't combine the scanned pages into one document.")
            )
            return
        }

        // OCR is best-effort. A multi-page contract or statement may carry no
        // receipt fields at all, and the pages are still worth attaching — so a
        // failure here does not discard the scan.
        let scanUseCase = ScanMultiPageReceiptUseCase(ocrService: OCRService())
        let receipt = try? await scanUseCase.execute(pages: pages)

        // One scan is one unit against the free OCR quota, however many pages it
        // held. Counting per page would make a 4-page receipt cost most of a
        // free month.
        dependencies.paywallPresenter.presentWhenSheetCloses(
            dependencies.conversionEventRecorder.afterOCRScanCompleted()
        )

        onPagesCaptured(pdfData, receipt)
        dismiss()
    }
    #endif
}

// MARK: - iOS document camera wrapper

#if os(iOS)
import CoreGraphics
import UIKit

struct DocumentCameraRepresentable: UIViewControllerRepresentable {
    let onScan: ([CGImage]) -> Void
    let onCancel: () -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {
        context.coordinator.onScan = onScan
        context.coordinator.onCancel = onCancel
        context.coordinator.onError = onError
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel, onError: onError)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var onScan: ([CGImage]) -> Void
        var onCancel: () -> Void
        var onError: (String) -> Void

        init(
            onScan: @escaping ([CGImage]) -> Void,
            onCancel: @escaping () -> Void,
            onError: @escaping (String) -> Void
        ) {
            self.onScan = onScan
            self.onCancel = onCancel
            self.onError = onError
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            // `scan` is only valid inside this callback, so the pages are copied
            // out before returning rather than held for later.
            let pages = (0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).cgImage }
            guard !pages.isEmpty else {
                onError(String(localized: "We couldn't read the scanned pages."))
                return
            }
            onScan(pages)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onError(
                error.userFacingMessage(
                    fallback: String(localized: "We couldn't start the document scanner.")
                )
            )
        }
    }
}
#endif

#Preview {
    MultiPageScannerView(onPagesCaptured: { _, _ in })
}
