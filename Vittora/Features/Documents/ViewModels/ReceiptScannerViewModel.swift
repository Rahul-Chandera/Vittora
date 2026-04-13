import Foundation
import CoreGraphics
import Observation

@Observable
@MainActor
final class ReceiptScannerViewModel {
    var scannedReceiptData: ReceiptData?
    var isProcessing = false
    var error: String?
    var showReview = false

    private let scanUseCase: ScanReceiptUseCase

    init(scanUseCase: ScanReceiptUseCase) {
        self.scanUseCase = scanUseCase
    }

    func processImage(_ cgImage: CGImage) async {
        isProcessing = true
        error = nil
        do {
            scannedReceiptData = try await scanUseCase.execute(image: cgImage)
            showReview = true
        } catch {
            self.error = error.localizedDescription
        }
        isProcessing = false
    }

    func reset() {
        scannedReceiptData = nil
        error = nil
        showReview = false
    }
}
