import SwiftUI

struct TransferFormView: View {
    @Environment(AppState.self) private var appState
    var onSave: (() -> Void)? = nil

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TransferViewModel?
    @State private var isTransferring = false
    @State private var showSourcePicker = false
    @State private var showDestinationPicker = false

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
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel")) { dismiss() }
                    .accessibilityIdentifier("transfer-cancel-button")
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
        .accessibilityIdentifier("transfer-form-root")
    }

    @MainActor
    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let deps = dependencies
        guard let accountRepo = deps.accountRepository,
              let transactionRepo = deps.transactionRepository else { return }

        let vm = TransferViewModel(
            transferUseCase: TransferFundsUseCase(
                transactionRepository: transactionRepo,
                accountRepository: accountRepo
            ),
            fetchUseCase: FetchAccountsUseCase(accountRepository: accountRepo)
        )
        viewModel = vm
        await vm.loadAccounts()
    }

    @ViewBuilder
    private func formContent(vm: TransferViewModel) -> some View {
        Form {
            Section(String(localized: "From")) {
                Button {
                    showSourcePicker = true
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
                            Text("Select Account")
                                .foregroundColor(VColors.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(VColors.textTertiary)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("transfer-source-account-button")
            }

            Section(String(localized: "To")) {
                Button {
                    showDestinationPicker = true
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
                            Text("Select Account")
                                .foregroundColor(VColors.textTertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(VColors.textTertiary)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("transfer-destination-account-button")
            }

            Section(String(localized: "Amount")) {
                TextField(String(localized: "0.00"), text: Bindable(vm).amount)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .accessibilityIdentifier("transfer-amount-field")
            }

            Section(String(localized: "Details")) {
                DatePicker(String(localized: "Date"), selection: Bindable(vm).date, displayedComponents: .date)
                TextField(String(localized: "Note (optional)"), text: Bindable(vm).note)
                    .accessibilityIdentifier("transfer-note-field")
            }

            if let error = vm.error {
                Section {
                    Text(error)
                        .foregroundColor(VColors.expense)
                        .font(VTypography.caption1)
                }
            }
        }
        .sheet(isPresented: $showSourcePicker) {
            NavigationStack {
                AccountPickerView(
                    selectedAccountID: Binding(
                        get: { vm.sourceAccount?.id },
                        set: { id in
                            vm.sourceAccount = vm.accounts.first { $0.id == id }
                            showSourcePicker = false
                        }
                    ),
                    accounts: vm.accounts,
                    excludeID: vm.destinationAccount?.id,
                    title: String(localized: "From Account"),
                    accessibilityIdentifierPrefix: "transfer-source-account"
                )
            }
        }
        .sheet(isPresented: $showDestinationPicker) {
            NavigationStack {
                AccountPickerView(
                    selectedAccountID: Binding(
                        get: { vm.destinationAccount?.id },
                        set: { id in
                            vm.destinationAccount = vm.accounts.first { $0.id == id }
                            showDestinationPicker = false
                        }
                    ),
                    accounts: vm.accounts,
                    excludeID: vm.sourceAccount?.id,
                    title: String(localized: "To Account"),
                    accessibilityIdentifierPrefix: "transfer-destination-account"
                )
            }
        }
    }

    private func performTransfer() async {
        guard let vm = viewModel else { return }
        isTransferring = true
        do {
            try await vm.transfer()
            appState.transactionRefreshVersion += 1
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
