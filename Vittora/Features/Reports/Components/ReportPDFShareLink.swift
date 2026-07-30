import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

/// Generates a report PDF on demand, then shares (iOS) or saves (macOS).
struct ReportPDFShareLink: View {
    let fileName: String
    /// Bumps when report inputs change so a cached PDF is discarded.
    let contentVersion: String
    let isEnabled: Bool
    let makePDF: () throws -> URL

    @State private var exportURL: URL?
    @State private var cachedContentVersion: String?
    @State private var showExportFailed = false
    @State private var isPreparing = false
    #if os(macOS)
    @State private var saveSucceeded = false
    #endif

    init(
        fileName: String,
        contentVersion: String,
        isEnabled: Bool,
        makePDF: @escaping () throws -> URL
    ) {
        self.fileName = fileName
        self.contentVersion = contentVersion
        self.isEnabled = isEnabled
        self.makePDF = makePDF
    }

    /// Convenience for single SwiftUI document layouts (custom / split reports).
    init<Document: View>(
        fileName: String,
        contentVersion: String,
        isEnabled: Bool,
        @ViewBuilder document: @escaping () -> Document
    ) {
        self.fileName = fileName
        self.contentVersion = contentVersion
        self.isEnabled = isEnabled
        self.makePDF = {
            try ReportPDFExporter.export(document(), fileName: fileName)
        }
    }

    var body: some View {
        Group {
            #if os(macOS)
            macOSExportButton
            #else
            iOSExportControl
            #endif
        }
        .onChange(of: contentVersion) { _, newValue in
            invalidateExportIfNeeded(currentVersion: newValue)
        }
        .onChange(of: fileName) { _, _ in
            invalidateExport()
        }
        .alert(String(localized: "Export Failed"), isPresented: $showExportFailed) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "We couldn't create the PDF report. Please try again."))
        }
        #if os(macOS)
        .alert(String(localized: "PDF Saved"), isPresented: $saveSucceeded) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "Your report PDF was saved successfully."))
        }
        #endif
    }

    #if os(iOS)
    @ViewBuilder
    private var iOSExportControl: some View {
        if let exportURL, cachedContentVersion == contentVersion {
            ShareLink(
                item: exportURL,
                preview: SharePreview(
                    String(localized: "Vittora Report"),
                    image: Image(systemName: "doc.richtext")
                )
            ) {
                Label(String(localized: "Export PDF"), systemImage: "square.and.arrow.up")
            }
        } else {
            Button {
                Task { await prepareExport() }
            } label: {
                if isPreparing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label(String(localized: "Export PDF"), systemImage: "square.and.arrow.up")
                }
            }
            .disabled(!isEnabled || isPreparing)
        }
    }
    #endif

    #if os(macOS)
    private var macOSExportButton: some View {
        Button {
            Task { await prepareAndSaveOnMac() }
        } label: {
            if isPreparing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label(String(localized: "Export PDF"), systemImage: "square.and.arrow.up")
            }
        }
        .disabled(!isEnabled || isPreparing)
    }
    #endif

    @MainActor
    private func prepareExport() async {
        guard isEnabled, !isPreparing else { return }
        invalidateExport()
        isPreparing = true
        defer { isPreparing = false }
        do {
            exportURL = try makePDF()
            cachedContentVersion = contentVersion
        } catch {
            showExportFailed = true
        }
    }

    #if os(macOS)
    @MainActor
    private func prepareAndSaveOnMac() async {
        guard isEnabled, !isPreparing else { return }
        invalidateExport()
        isPreparing = true
        defer { isPreparing = false }
        do {
            let tempURL = try makePDF()
            exportURL = tempURL
            cachedContentVersion = contentVersion
            try presentSavePanel(for: tempURL)
            saveSucceeded = true
        } catch is CancellationError {
            // User dismissed the save panel.
        } catch {
            showExportFailed = true
        }
    }

    @MainActor
    private func presentSavePanel(for tempURL: URL) throws {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = String(localized: "Save PDF Report")
        panel.nameFieldStringValue = "\(fileName).pdf"

        guard panel.runModal() == .OK, let destination = panel.url else {
            throw CancellationError()
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: tempURL, to: destination)
    }
    #endif

    @MainActor
    private func invalidateExportIfNeeded(currentVersion: String) {
        guard cachedContentVersion != currentVersion else { return }
        invalidateExport()
    }

    @MainActor
    private func invalidateExport() {
        if let exportURL {
            try? FileManager.default.removeItem(at: exportURL)
        }
        exportURL = nil
        cachedContentVersion = nil
    }
}
