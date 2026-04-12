import SwiftUI

struct TransferFormView: View {
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
        .navigationTitle("Transfer Funds")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isTransferring {
                    ProgressView()
                } else {
                    Button("Transfer") {
                        Task { await performTransfer() }
                    }
                    .disabled(viewModel?.canTransfer != true)
                }
            }
        }
        .task {
            await setupViewModel()
        }
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
            Section("From") {
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
            }

            Section("To") {
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
            }

            Section("Amount") {
                TextField("0.00", text: Bindable(vm).amount)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }

            Section("Details") {
                DatePicker("Date", selection: Bindable(vm).date, displayedComponents: .date)
                TextField("Note (optional)", text: Bindable(vm).note)
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
                    title: "From Account"
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
                    title: "To Account"
                )
            }
        }
    }

    private func performTransfer() async {
        guard let vm = viewModel else { return }
        isTransferring = true
        do {
            try await vm.transfer()
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
