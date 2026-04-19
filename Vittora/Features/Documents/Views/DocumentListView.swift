import SwiftUI
import PhotosUI

struct DocumentListView: View {
    @Environment(\.dependencies) private var dependencies
    let transactionID: UUID
    @State private var vm: DocumentListViewModel?
    @State private var showScanner = false
    @State private var showImport = false
    @State private var showPreviewURL: URL?
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            sectionHeader

            if let vm = vm {
                if vm.isLoading {
                    ProgressView().tint(VColors.primary)
                } else {
                    thumbnailGrid(vm)
                }

                if let errorMessage = vm.error {
                    Text(errorMessage)
                        .font(VTypography.caption2)
                        .foregroundColor(VColors.expense)
                }
            }
        }
        .task {
            if vm == nil {
                guard let docRepo = dependencies.documentRepository else { return }
                let fetchUseCase = FetchDocumentsUseCase(documentRepository: docRepo)
                let attachUseCase = AttachDocumentUseCase(documentRepository: docRepo)
                let deleteUseCase = DeleteDocumentUseCase(documentRepository: docRepo)
                vm = DocumentListViewModel(
                    transactionID: transactionID,
                    fetchUseCase: fetchUseCase,
                    attachUseCase: attachUseCase,
                    deleteUseCase: deleteUseCase
                )
                await vm?.load()
            }
        }
        .sheet(isPresented: $showScanner) {
            ReceiptScannerView(onImageCaptured: { data in
                Task { await vm?.attach(imageData: data, mimeType: "image/jpeg") }
            })
        }
        .sheet(isPresented: $showImport) {
            DocumentImportView(onDocumentSelected: { data, mimeType in
                Task { await vm?.attach(imageData: data, mimeType: mimeType) }
            })
        }
        .sheet(item: $showPreviewURL) { url in
            DocumentPreviewView(url: url)
        }
        .photosPicker(isPresented: Binding(
            get: { false },
            set: { _ in }
        ), selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, item in
            Task {
                do {
                    if let data = try await item?.loadTransferable(type: Data.self) {
                        await vm?.attach(imageData: data, mimeType: "image/jpeg")
                    }
                } catch {
                    vm?.error = error.localizedDescription
                }
                selectedPhoto = nil
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text(String(localized: "Attachments"))
                .font(VTypography.subheadline)
                .foregroundColor(VColors.textSecondary)

            Spacer()

            Menu {
                #if os(iOS)
                Button {
                    showScanner = true
                } label: {
                    Label(String(localized: "Scan Receipt"), systemImage: "camera.viewfinder")
                }
                #endif

                Button {
                    showImport = true
                } label: {
                    Label(String(localized: "Import File"), systemImage: "folder")
                }
            } label: {
                Image(systemName: "plus")
                    .foregroundColor(VColors.primary)
            }
            .menuStyle(.button)
        }
    }

    @ViewBuilder
    private func thumbnailGrid(_ vm: DocumentListViewModel) -> some View {
        if vm.documents.isEmpty {
            Text(String(localized: "No attachments"))
                .font(VTypography.caption1)
                .foregroundColor(VColors.textTertiary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VSpacing.sm) {
                    ForEach(vm.documents) { entity in
                        DocumentThumbnailView(
                            entity: entity,
                            onTap: {
                                if let url = vm.fileURL(for: entity) {
                                    showPreviewURL = url
                                }
                            },
                            onDelete: {
                                Task { await vm.delete(id: entity.id) }
                            }
                        )
                    }
                }
            }
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    DocumentListView(transactionID: UUID())
        .padding()
}
