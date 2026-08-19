import SwiftUI
import PhotosUI
import VittoraCore

struct DocumentListView: View {
    @Environment(\.dependencies) private var dependencies
    let transactionID: UUID
    @State private var vm: DocumentListViewModel?
    @State private var showScanner = false
    @State private var showBatchScan = false
    @State private var showImport = false
    @State private var previewItem: DocumentPreviewItem?
    /// An attachment is a receipt the user photographed once. Deleting it on a
    /// single click, with the file gone from disk, was the least recoverable
    /// delete in the app.
    @State private var documentToDelete: DocumentEntity?
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
                        .foregroundColor(VColors.textPrimary)
                }
            }
        }
        .task {
            if vm == nil {
                let fetchUseCase = FetchDocumentsUseCase(documentRepository: dependencies.documentRepository)
                let attachUseCase = AttachDocumentUseCase(
                    documentRepository: dependencies.documentRepository,
                    documentStorageService: dependencies.documentStorageService
                )
                let deleteUseCase = DeleteDocumentUseCase(
                    documentRepository: dependencies.documentRepository,
                    documentStorageService: dependencies.documentStorageService
                )
                vm = DocumentListViewModel(
                    transactionID: transactionID,
                    fetchUseCase: fetchUseCase,
                    attachUseCase: attachUseCase,
                    deleteUseCase: deleteUseCase,
                    documentStorageService: dependencies.documentStorageService
                )
                await vm?.load()
            }
        }
        .sheet(isPresented: $showScanner) {
            ReceiptScannerView(onImageCaptured: { data in
                Task { await vm?.attach(imageData: data, mimeType: "image/jpeg") }
            })
        }
        .sheet(isPresented: $showBatchScan) {
            BatchReceiptScanView(transactionID: transactionID) {
                Task { await vm?.load() }
            }
        }
        .sheet(isPresented: $showImport) {
            DocumentImportView(onDocumentSelected: { data, mimeType in
                Task { await vm?.attach(imageData: data, mimeType: mimeType) }
            })
        }
        .sheet(item: $previewItem) { item in
            DocumentPreviewView(item: item)
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

                Button {
                    showBatchScan = true
                } label: {
                    Label(String(localized: "Batch Scan"), systemImage: "doc.on.doc")
                }
                #endif

                Button {
                    showImport = true
                } label: {
                    Label(String(localized: "Import File"), systemImage: "folder")
                }

                #if os(macOS)
                Button {
                    showBatchScan = true
                } label: {
                    Label(String(localized: "Batch Scan"), systemImage: "doc.on.doc")
                }
                #endif
            } label: {
                Image(systemName: "plus")
                    .foregroundColor(VColors.textPrimary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .menuStyle(.button)
            .accessibilityLabel(String(localized: "Add attachment"))
            .accessibilityHint(String(localized: "Shows attachment options"))
            .accessibilityIdentifier("document-add-button")
        }
    }

    @ViewBuilder
    private func thumbnailGrid(_ vm: DocumentListViewModel) -> some View {
        if vm.documents.isEmpty {
            Text(String(localized: "No attachments"))
                .font(VTypography.caption1)
                .foregroundColor(VColors.textPrimary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VSpacing.sm) {
                    ForEach(vm.documents) { entity in
                        DocumentThumbnailView(
                            entity: entity,
                            onTap: {
                                Task {
                                    do {
                                        previewItem = try await vm.previewItem(for: entity)
                                    } catch {
                                        vm.error = error.localizedDescription
                                    }
                                }
                            },
                            onDelete: { documentToDelete = entity }
                        )
                    }
                }
            }
            .confirmationDialog(
                String(localized: "Delete this attachment?"),
                isPresented: Binding(
                    get: { documentToDelete != nil },
                    set: { if !$0 { documentToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(String(localized: "Delete"), role: .destructive) {
                    guard let entity = documentToDelete else { return }
                    documentToDelete = nil
                    Task { await vm.delete(id: entity.id) }
                }
                Button(String(localized: "Cancel"), role: .cancel) { documentToDelete = nil }
            } message: {
                Text(String(localized: "The file will be removed from this transaction and deleted. This cannot be undone."))
            }
        }
    }
}

#Preview {
    DocumentListView(transactionID: UUID())
        .padding()
}
