import SwiftUI

/// Generates a report PDF on demand, then exposes it through ShareLink.
struct ReportPDFShareLink<Document: View>: View {
    let fileName: String
    /// Bumps when report inputs change so a cached PDF is discarded.
    let contentVersion: String
    let isEnabled: Bool
    @ViewBuilder let document: () -> Document

    @State private var exportURL: URL?
    @State private var cachedContentVersion: String?
    @State private var showExportFailed = false
    @State private var isPreparing = false

    var body: some View {
        Group {
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
    }

    @MainActor
    private func prepareExport() async {
        guard isEnabled, !isPreparing else { return }
        invalidateExport()
        isPreparing = true
        defer { isPreparing = false }
        do {
            exportURL = try ReportPDFExporter.export(document(), fileName: fileName)
            cachedContentVersion = contentVersion
        } catch {
            showExportFailed = true
        }
    }

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
