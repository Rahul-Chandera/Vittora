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
}

// MARK: - iOS DataScanner wrapper

#if os(iOS)
import UIKit
import VisionKit
import CoreGraphics

struct DataScannerRepresentable: UIViewControllerRepresentable {
    let isProcessing: Bool
    let onCapture: (CGImage, Data) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighlightingEnabled: false
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        context.coordinator.onCapture = onCapture
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCapture: (CGImage, Data) -> Void

        init(onCapture: @escaping (CGImage, Data) -> Void) {
            self.onCapture = onCapture
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            Task { @MainActor in
                guard let image = try? await dataScanner.capturePhoto(),
                      let cgImage = image.cgImage,
                      let data = image.jpegData(compressionQuality: 0.9) else { return }
                self.onCapture(cgImage, data)
            }
        }
    }
}
#endif

#Preview {
    ReceiptScannerView(onImageCaptured: { _ in })
}
