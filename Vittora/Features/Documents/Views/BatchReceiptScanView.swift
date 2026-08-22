import SwiftUI
import PhotosUI
import CoreGraphics
import VittoraCore
#if canImport(UIKit)
import UIKit
#endif

struct BatchReceiptScanView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    let transactionID: UUID
    let onComplete: () -> Void

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isProcessing = false
    @State private var attachedCount = 0
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: VSpacing.lg) {
                Text(String(localized: "Select multiple receipt photos to scan and attach."))
                    .font(VTypography.body)
                    .foregroundColor(VColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VSpacing.lg)

                #if os(iOS)
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    Label(String(localized: "Choose Photos"), systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(VColors.primary)
                .padding(.horizontal, VSpacing.lg)
                .disabled(isProcessing)
                #else
                Button {
                    importMultipleOnMac()
                } label: {
                    Label(String(localized: "Choose Files"), systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(VColors.primary)
                .padding(.horizontal, VSpacing.lg)
                .disabled(isProcessing)
                #endif

                if !selectedItems.isEmpty {
                    Text(String(localized: "\(selectedItems.count) selected"))
                        .font(VTypography.caption1)
                        .foregroundColor(VColors.textSecondary)
                }

                if isProcessing {
                    ProgressView(String(localized: "Scanning receipts…"))
                        .tint(VColors.primary)
                } else if attachedCount > 0 {
                    Text(String(localized: "\(attachedCount) receipts attached"))
                        .font(VTypography.caption1)
                        .foregroundColor(VColors.income)
                }

                Spacer()
            }
            .padding(.top, VSpacing.lg)
            .navigationTitle(String(localized: "Batch Scan"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                        .disabled(isProcessing)
                    .vDialogCancelButton()
                }
                #if os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Scan")) {
                        Task { await processSelectedPhotos() }
                    }
                    .disabled(selectedItems.isEmpty || isProcessing)
                    .vDialogConfirmButton()
                }
                #endif
            }
            .errorAlert(message: $error)
        }
    }

    private func runBatchScan(inputs: [BatchScanInput]) async {
        let attachUseCase = AttachDocumentUseCase(
            documentRepository: dependencies.documentRepository,
            documentStorageService: dependencies.documentStorageService
        )
        let outcome = await dependencies.makeBatchScanUseCase().scanAndAttach(
            inputs: inputs,
            transactionID: transactionID,
            attachUseCase: attachUseCase
        )

        guard outcome.attachedCount > 0 else {
            error = String(localized: "We couldn't attach any of the selected receipts.")
            return
        }

        attachedCount = outcome.attachedCount
        if outcome.hadPartialFailure {
            error = String(
                localized: "\(outcome.attachedCount) attached; \(outcome.failureCount) couldn't be processed."
            )
        }
        dependencies.conversionEventRecorder.afterOCRScanCompleted()
        onComplete()
        if !outcome.hadPartialFailure {
            dismiss()
        }
    }

    #if os(iOS)
    private func processSelectedPhotos() async {
        isProcessing = true
        attachedCount = 0
        error = nil
        defer { isProcessing = false }

        var inputs: [BatchScanInput] = []
        for item in selectedItems {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let cgImage = cgImage(from: data) else {
                continue
            }
            inputs.append(BatchScanInput(cgImage: cgImage, imageData: data, mimeType: "image/jpeg"))
        }

        guard !inputs.isEmpty else {
            error = String(localized: "We couldn't read the selected photos.")
            return
        }

        await runBatchScan(inputs: inputs)
    }

    private func cgImage(from data: Data) -> CGImage? {
        #if canImport(UIKit)
        return UIImage(data: data)?.cgImage
        #else
        return nil
        #endif
    }
    #endif

    #if os(macOS)
    private func importMultipleOnMac() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else { return }
        Task {
            await processMacURLs(panel.urls)
        }
    }

    private func processMacURLs(_ urls: [URL]) async {
        isProcessing = true
        attachedCount = 0
        error = nil
        defer { isProcessing = false }

        var inputs: [BatchScanInput] = []
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url),
                  let cgImage = NSImage(data: data)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                continue
            }
            inputs.append(BatchScanInput(
                cgImage: cgImage,
                imageData: data,
                mimeType: mimeType(for: url)
            ))
        }

        guard !inputs.isEmpty else {
            error = String(localized: "We couldn't read the selected files.")
            return
        }

        await runBatchScan(inputs: inputs)
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        default: return "image/jpeg"
        }
    }
    #endif
}

#if os(macOS)
import AppKit
#endif
