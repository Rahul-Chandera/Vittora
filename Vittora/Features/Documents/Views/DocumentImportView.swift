import SwiftUI
import UniformTypeIdentifiers

struct DocumentImportView: View {
    @Environment(\.dismiss) private var dismiss
    let onDocumentSelected: (Data, String) -> Void

    #if os(iOS)
    @State private var showFilePicker = false
    #endif

    var body: some View {
        NavigationStack {
            VStack(spacing: VSpacing.xl) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 56))
                    .foregroundColor(VColors.primary)

                Text(String(localized: "Import Document"))
                    .font(VTypography.title3)
                    .foregroundColor(VColors.textPrimary)

                Text(String(localized: "Supported: JPEG, PNG, PDF"))
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)

                #if os(iOS)
                Button(String(localized: "Choose File")) {
                    showFilePicker = true
                }
                .buttonStyle(.borderedProminent)
                .tint(VColors.primary)
                .fileImporter(
                    isPresented: $showFilePicker,
                    allowedContentTypes: [.jpeg, .png, .pdf],
                    allowsMultipleSelection: false
                ) { result in
                    handleFileImport(result)
                }
                #else
                Button(String(localized: "Choose File")) {
                    openMacFilePicker()
                }
                .buttonStyle(.borderedProminent)
                .tint(VColors.primary)
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(VColors.background)
            .navigationTitle(String(localized: "Import"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result,
              let url = urls.first else { return }

        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return }
        let mimeType = mimeType(for: url)
        onDocumentSelected(data, mimeType)
        dismiss()
    }

    #if os(macOS)
    private func openMacFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK,
              let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }

        let mimeType = mimeType(for: url)
        onDocumentSelected(data, mimeType)
        dismiss()
    }
    #endif

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "pdf": return "application/pdf"
        default: return "application/octet-stream"
        }
    }
}

#Preview {
    DocumentImportView(onDocumentSelected: { _, _ in })
}
