import SwiftUI

// MARK: - Shared shell

struct ReceiptScannerView: View {
    let onImageCaptured: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var scannerVM: ReceiptScannerViewModel?
    @State private var scannedData: Data?
    @State private var showReview = false
    @State private var receiptData: ReceiptData?

    var body: some View {
        ZStack {
            #if os(iOS)
            iOSScannerContent
            #else
            macFallbackContent
            #endif
        }
        .task {
            let ocrService = OCRService()
            let scanUseCase = ScanReceiptUseCase(ocrService: ocrService)
            scannerVM = ReceiptScannerViewModel(scanUseCase: scanUseCase)
        }
        .errorAlert(message: scannerErrorBinding)
        .sheet(isPresented: $showReview) {
            if let data = receiptData {
                ReceiptReviewView(receiptData: data) { _, _, _ in
                    if let imageData = scannedData {
                        onImageCaptured(imageData)
                    }
                    showReview = false
                    dismiss()
                }
            }
        }
    }

    #if os(iOS)
    @ViewBuilder
    private var iOSScannerContent: some View {
        if let vm = scannerVM {
            DataScannerRepresentable(
                isProcessing: vm.isProcessing,
                onCapture: { cgImage, imageData in
                    scannedData = imageData
                    Task {
                        await vm.processImage(cgImage)
                        if let data = vm.scannedReceiptData {
                            receiptData = data
                            showReview = true
                        }
                    }
                },
                onError: { message in
                    vm.error = message
                }
            )
            .ignoresSafeArea()
            .overlay { ScannerOverlayView(isProcessing: vm.isProcessing) }
            .overlay(alignment: .topTrailing) {
                Button(String(localized: "Cancel")) { dismiss() }
                    .foregroundColor(.white)
                    .padding(VSpacing.lg)
            }
        }
    }
    #else
    @ViewBuilder
    private var macFallbackContent: some View {
        DocumentImportView(onDocumentSelected: { data, _ in
            onImageCaptured(data)
            dismiss()
        })
    }
    #endif

    private var scannerErrorBinding: Binding<String?> {
        Binding(
            get: { scannerVM?.error },
            set: { newValue in
                scannerVM?.error = newValue
            }
        )
    }
}

// MARK: - iOS DataScanner wrapper

#if os(iOS)
import UIKit
import VisionKit
import CoreGraphics

struct DataScannerRepresentable: UIViewControllerRepresentable {
    let isProcessing: Bool
    let onCapture: (CGImage, Data) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighlightingEnabled: false
        )
        scanner.delegate = context.coordinator
        do {
            try scanner.startScanning()
        } catch {
            context.coordinator.report(
                error,
                fallback: String(localized: "We couldn't start the receipt scanner right now.")
            )
        }
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        context.coordinator.onCapture = onCapture
        context.coordinator.onError = onError
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onError: onError)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCapture: (CGImage, Data) -> Void
        var onError: (String) -> Void

        init(
            onCapture: @escaping (CGImage, Data) -> Void,
            onError: @escaping (String) -> Void
        ) {
            self.onCapture = onCapture
            self.onError = onError
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            Task { @MainActor in
                do {
                    let image = try await dataScanner.capturePhoto()
                    guard let cgImage = image.cgImage,
                          let data = image.jpegData(compressionQuality: 0.9) else {
                        onError(String(localized: "We couldn't capture a photo from the scanner."))
                        return
                    }
                    onCapture(cgImage, data)
                } catch {
                    report(
                        error,
                        fallback: String(localized: "We couldn't capture a photo from the scanner.")
                    )
                }
            }
        }

        func report(_ error: Error, fallback: String) {
            let message = error.userFacingMessage(fallback: fallback)
            Task { @MainActor in
                onError(message)
            }
        }
    }
}
#endif

#Preview {
    ReceiptScannerView(onImageCaptured: { _ in })
}
