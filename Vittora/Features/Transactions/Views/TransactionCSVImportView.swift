import SwiftUI
import UniformTypeIdentifiers
import VittoraCore
#if os(macOS)
import AppKit
#endif

struct TransactionCSVImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @Environment(AppState.self) private var appState

    let onComplete: () -> Void

    @State private var vm: TransactionCSVImportViewModel?
    #if os(iOS)
    @State private var showFilePicker = false
    #endif

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    formContent(vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(String(localized: "Import CSV"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                    .vDialogCancelButton()
                }
                if let vm, vm.canImport {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Import")) {
                            Task {
                                if await vm.importTransactions(currencyCode: currencyCode) {
                                    // .budgets too: an import can land dozens of expenses, and
                                    // every budget covering their categories is stale.
                                    appState.notifyChanged([.transactions, .accounts, .payees, .budgets])
                                    onComplete()
                                    dismiss()
                                }
                            }
                        }
                        .disabled(vm.isLoading)
                        .vDialogConfirmButton()
                    }
                }
            }
            .task {
                if vm == nil {
                    vm = dependencies.makeTransactionCSVImportViewModel()
                }
                await vm?.loadAccounts()
            }
            .errorAlert(message: Binding(
                get: { vm?.error },
                set: { vm?.error = $0 }
            ))
        }
    }

    @ViewBuilder
    private func formContent(_ vm: TransactionCSVImportViewModel) -> some View {
        Form {
            Section(header: VFormSectionHeader(String(localized: "Format"))) {
                Picker(String(localized: "Profile"), selection: Bindable(vm).profile) {
                    ForEach(CSVImportProfile.allCases) { profile in
                        Text(profile.displayName).tag(profile)
                    }
                }
                .onChange(of: vm.profile) { _, _ in
                    Task { await vm.refreshPreview() }
                }
            }

            Section(header: VFormSectionHeader(String(localized: "Target Account"))) {
                if vm.accounts.isEmpty {
                    Text(String(localized: "Add an account before importing transactions."))
                        .foregroundStyle(VColors.textSecondary)
                } else {
                    Picker(String(localized: "Account"), selection: Bindable(vm).selectedAccountID) {
                        ForEach(vm.accounts) { account in
                            Text(account.name).tag(Optional(account.id))
                        }
                    }
                }
            }

            Section(header: VFormSectionHeader(String(localized: "CSV File"))) {
                #if os(iOS)
                Button(String(localized: "Choose CSV File")) {
                    showFilePicker = true
                }
                .fileImporter(
                    isPresented: $showFilePicker,
                    allowedContentTypes: [.commaSeparatedText, .plainText, .text],
                    allowsMultipleSelection: false
                ) { result in
                    handleFileImport(result, vm: vm)
                }
                #else
                Button(String(localized: "Choose CSV File")) {
                    openMacFilePicker(vm: vm)
                }
                #endif

                if let fileName = vm.fileName {
                    Text(fileName)
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                }
            }

            if let preview = vm.preview {
                Section(header: VFormSectionHeader(String(localized: "Preview"))) {
                    LabeledContent(String(localized: "Valid rows")) {
                        Text(verbatim: "\(preview.rows.count)")
                    }
                    if preview.invalidRowCount > 0 {
                        LabeledContent(String(localized: "Skipped rows")) {
                            Text(verbatim: "\(preview.invalidRowCount)")
                        }
                    }

                    ForEach(preview.rows.prefix(5)) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.payeeName)
                                .font(VTypography.bodyBold)
                            HStack {
                                Text(row.date.formatted(date: .abbreviated, time: .omitted))
                                Spacer()
                                Text(row.amount.formatted(.currency(code: currencyCode)))
                                    .foregroundStyle(row.type == .income ? VColors.income : VColors.expense)
                            }
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                        }
                    }

                    if preview.rows.count > 5 {
                        Text(String(localized: "…and \(preview.rows.count - 5) more"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                    }
                }
            }

            if let result = vm.result {
                Section(header: VFormSectionHeader(String(localized: "Last Import"))) {
                    LabeledContent(String(localized: "Imported")) {
                        Text(verbatim: "\(result.importedCount)")
                    }
                    if result.skippedDuplicateCount > 0 {
                        LabeledContent(String(localized: "Duplicates skipped")) {
                            Text(verbatim: "\(result.skippedDuplicateCount)")
                        }
                    }
                    if result.createdPayeeCount > 0 {
                        LabeledContent(String(localized: "Payees created")) {
                            Text(verbatim: "\(result.createdPayeeCount)")
                        }
                    }
                }
            }
        }
        .overlay {
            if vm.isLoading {
                ProgressView()
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>, vm: TransactionCSVImportViewModel) {
        switch result {
        case .failure(let error):
            vm.error = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                Task { await vm.loadCSV(data: data, fileName: url.lastPathComponent) }
            } catch {
                vm.error = error.localizedDescription
            }
        }
    }

    #if os(macOS)
    private func openMacFilePicker(vm: TransactionCSVImportViewModel) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText, .text]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            Task { await vm.loadCSV(data: data, fileName: url.lastPathComponent) }
        } catch {
            vm.error = error.localizedDescription
        }
    }
    #endif
}
