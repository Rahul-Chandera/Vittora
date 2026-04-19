import SwiftUI

struct AccountFormView: View {
    var editingAccount: AccountEntity? = nil
    var onSave: (() -> Void)? = nil

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AccountFormViewModel?
    @State private var isSaving = false
    @State private var saveError: String?

    private let availableIcons = [
        "building.columns.fill", "creditcard.fill", "banknote.fill",
        "iphone.gen2", "chart.line.uptrend.xyaxis", "arrow.up.circle.fill",
        "arrow.down.circle.fill", "wallet.pass.fill", "briefcase.fill",
        "house.fill", "car.fill", "airplane"
    ]

    private let commonCurrencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "INR", "CNY", "MXN"]

    var body: some View {
        Group {
            if let vm = viewModel {
                formContent(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(editingAccount == nil ? "New Account" : "Edit Account")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(viewModel?.canSave != true || isSaving)
            }
        }
        .task {
            setupViewModel()
        }
        .onChange(of: saveError) { _, newValue in
            if let msg = newValue {
                AccessibilityNotification.Announcement(Text(msg)).post()
            }
        }
    }

    private func setupViewModel() {
        guard viewModel == nil else { return }
        let deps = dependencies
        guard let accountRepo = deps.accountRepository else { return }

        let vm = AccountFormViewModel(
            createUseCase: CreateAccountUseCase(accountRepository: accountRepo),
            updateUseCase: UpdateAccountUseCase(accountRepository: accountRepo),
            repository: accountRepo
        )
        if let account = editingAccount {
            vm.loadAccount(account)
        }
        viewModel = vm
    }

    @ViewBuilder
    private func formContent(vm: AccountFormViewModel) -> some View {
        Form {
            Section("Account Info") {
                TextField("Account Name", text: Bindable(vm).name)

                Picker("Type", selection: Bindable(vm).selectedType) {
                    ForEach(AccountType.allCases, id: \.self) { type in
                        Text(typeName(type)).tag(type)
                    }
                }

                Picker("Currency", selection: Bindable(vm).selectedCurrency) {
                    ForEach(commonCurrencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
            }

            if !vm.isEditing {
                Section("Starting Balance") {
                    TextField("0.00", text: Bindable(vm).initialBalance)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
            }

            Section("Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: VSpacing.sm) {
                    ForEach(availableIcons, id: \.self) { iconName in
                        Button {
                            vm.selectedIcon = iconName
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(vm.selectedIcon == iconName ? VColors.primary : VColors.tertiaryBackground)
                                    .frame(width: 44, height: 44)
                                Image(systemName: iconName)
                                    .font(.system(size: 18))
                                    .foregroundColor(vm.selectedIcon == iconName ? .white : VColors.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, VSpacing.xs)
            }

            if let error = saveError {
                Section {
                    Text(error)
                        .foregroundColor(VColors.expense)
                        .font(VTypography.caption1)
                }
            }
        }
    }

    private func save() async {
        guard let vm = viewModel else { return }
        isSaving = true
        saveError = nil
        do {
            try await vm.save()
            onSave?()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }

    private func typeName(_ type: AccountType) -> String {
        switch type {
        case .cash: return "Cash"
        case .bank: return "Bank Account"
        case .creditCard: return "Credit Card"
        case .loan: return "Loan"
        case .digitalWallet: return "Digital Wallet"
        case .investment: return "Investment"
        case .receivable: return "Receivable"
        case .payable: return "Payable"
        }
    }
}

#Preview {
    NavigationStack {
        AccountFormView()
    }
}
