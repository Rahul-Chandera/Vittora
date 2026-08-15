import SwiftUI
import VittoraCore

struct TransferFormView: View {
    @Environment(AppState.self) private var appState
    /// Show a Cancel button. Only pass `true` when presenting modally; a pushed
    /// form already has a back button, so Cancel would be a duplicate.
    var showsCancelButton: Bool = false
    var onSave: (() -> Void)? = nil

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TransferViewModel?
    @State private var isTransferring = false

    var body: some View {
        Group {
            if let vm = viewModel {
                formContent(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "Transfer Funds"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if showsCancelButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                        .accessibilityIdentifier("transfer-cancel-button")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isTransferring {
                    ProgressView()
                } else {
                    Button(String(localized: "Transfer")) {
                        Task { await performTransfer() }
                    }
                    .disabled(viewModel?.canTransfer != true)
                    .accessibilityIdentifier("transfer-submit-button")
                }
            }
        }
        .task {
            await setupViewModel()
        }
        .onChange(of: viewModel?.error) { _, newValue in
            if let msg = newValue {
                AccessibilityNotification.Announcement(AttributedString(msg)).post()
            }
        }
        .accessibilityIdentifier("transfer-form-root")
    }

    @MainActor
    private func setupViewModel() async {
        guard viewModel == nil else { return }

        let vm = TransferViewModel(
            transferUseCase: TransferFundsUseCase(
                accountRepository: dependencies.accountRepository,
                ledgerWriteStore: dependencies.ledgerWriteStore
            ),
            fetchUseCase: FetchAccountsUseCase(accountRepository: dependencies.accountRepository)
        )
        viewModel = vm
        await vm.loadAccounts()
    }

    @ViewBuilder
    private func formContent(vm: TransferViewModel) -> some View {
        Form {
            Section(header: VFormSectionHeader(String(localized: "From"))) {
                NavigationLink {
                    AccountPickerView(
                        selectedAccountID: Binding(
                            get: { vm.sourceAccount?.id },
                            set: { id in
                                vm.sourceAccount = vm.accounts.first { $0.id == id }
                            }
                        ),
                        accounts: vm.accounts,
                        excludeID: vm.destinationAccount?.id,
                        title: String(localized: "From Account"),
                        accessibilityIdentifierPrefix: "transfer-source-account",
                        dismissOnSelection: true,
                        onAccountCreated: { Task { await vm.loadAccounts() } }
                    )
                } label: {
                    HStack {
                        if let source = vm.sourceAccount {
                            AccountTypeIcon(type: source.type, size: 32)
                            VStack(alignment: .leading) {
                                Text(source.name)
                                    .font(VTypography.body)
                                    .foregroundColor(VColors.textPrimary)
                                Text(source.balance.formatted(.currency(code: source.currencyCode)))
                                    .font(VTypography.caption1)
                                    .foregroundColor(VColors.textSecondary)
                            }
                        } else {
                            Text(String(localized: "Select Account"))
                                .foregroundColor(VColors.textTertiary)
                        }
                        Spacer()
                    }
                }
                .accessibilityIdentifier("transfer-source-account-button")
            }

            Section(header: VFormSectionHeader(String(localized: "To"))) {
                NavigationLink {
                    AccountPickerView(
                        selectedAccountID: Binding(
                            get: { vm.destinationAccount?.id },
                            set: { id in
                                vm.destinationAccount = vm.accounts.first { $0.id == id }
                            }
                        ),
                        accounts: vm.accounts,
                        excludeID: vm.sourceAccount?.id,
                        title: String(localized: "To Account"),
                        accessibilityIdentifierPrefix: "transfer-destination-account",
                        dismissOnSelection: true,
                        onAccountCreated: { Task { await vm.loadAccounts() } }
                    )
                } label: {
                    HStack {
                        if let dest = vm.destinationAccount {
                            AccountTypeIcon(type: dest.type, size: 32)
                            VStack(alignment: .leading) {
                                Text(dest.name)
                                    .font(VTypography.body)
                                    .foregroundColor(VColors.textPrimary)
                                Text(dest.balance.formatted(.currency(code: dest.currencyCode)))
                                    .font(VTypography.caption1)
                                    .foregroundColor(VColors.textSecondary)
                            }
                        } else {
                            Text(String(localized: "Select Account"))
                                .foregroundColor(VColors.textTertiary)
                        }
                        Spacer()
                    }
                }
                .accessibilityIdentifier("transfer-destination-account-button")
            }

            Section(header: VFormSectionHeader(String(localized: "Amount"), isRequired: true)) {
                TextField(String(localized: "0.00"), text: Bindable(vm).amount)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    .textContentType(nil)
                    #endif
                    .accessibilityIdentifier("transfer-amount-field")
            }

            Section(header: VFormSectionHeader(String(localized: "Details"))) {
                DatePicker(String(localized: "Date"), selection: Bindable(vm).date, displayedComponents: .date)
                TextField(String(localized: "Note (optional)"), text: Bindable(vm).note)
                    .accessibilityIdentifier("transfer-note-field")
            }

            if let error = vm.error {
                Section {
                    VInlineErrorText(error)
                }
            }
        }
    }

    private func performTransfer() async {
        guard let vm = viewModel else { return }
        isTransferring = true
        do {
            try await vm.transfer()
            appState.notifyChanged([.transactions, .accounts])
            onSave?()
            dismiss()
        } catch {
            vm.error = error.localizedDescription
        }
        isTransferring = false
    }
}

#Preview {
    NavigationStack {
        TransferFormView()
    }
}
