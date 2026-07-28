import SwiftUI
import VittoraCore

struct AccountFormView: View {
    var editingAccount: AccountEntity? = nil
    /// Show a Cancel button. Only pass `true` when presenting modally; a pushed
    /// form already has a back button, so Cancel would be a duplicate.
    var showsCancelButton: Bool = false
    var onSave: (() -> Void)? = nil

    @Environment(AppState.self) private var appState
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
        .navigationTitle(editingAccount == nil ? String(localized: "New Account") : String(localized: "Edit Account"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if showsCancelButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                        .font(.body)
                        .foregroundStyle(VColors.textPrimary)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save")) {
                    Task { await save() }
                }
                .disabled(viewModel?.canSave != true || isSaving)
                .font(.body)
                .foregroundStyle(VColors.textPrimary)
            }
        }
        .task {
            setupViewModel()
        }
        .onChange(of: saveError) { _, newValue in
            if let msg = newValue {
                AccessibilityNotification.Announcement(AttributedString(msg)).post()
            }
        }
    }

    private func setupViewModel() {
        guard viewModel == nil else { return }

        let vm = AccountFormViewModel(
            createUseCase: CreateAccountUseCase(accountRepository: dependencies.accountRepository),
            updateUseCase: UpdateAccountUseCase(accountRepository: dependencies.accountRepository),
            repository: dependencies.accountRepository
        )
        if let account = editingAccount {
            vm.loadAccount(account)
        }
        viewModel = vm
    }

    @ViewBuilder
    private func formContent(vm: AccountFormViewModel) -> some View {
        Form {
            Section(String(localized: "Account Info")) {
                TextField(String(localized: "Account Name"), text: Bindable(vm).name)

                Picker(String(localized: "Type"), selection: Bindable(vm).selectedType) {
                    ForEach(AccountType.allCases, id: \.self) { type in
                        Text(typeName(type)).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize(horizontal: false, vertical: true)

                Picker(String(localized: "Currency"), selection: Bindable(vm).selectedCurrency) {
                    ForEach(commonCurrencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize(horizontal: false, vertical: true)
            }

            if !vm.isEditing {
                Section(String(localized: "Starting Balance")) {
                    TextField(String(localized: "0.00"), text: Bindable(vm).initialBalance)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        .textContentType(nil)
                        #endif
                }
            }

            if vm.selectedType == .creditCard {
                Section(String(localized: "Billing Cycle")) {
                    billingDayPicker(
                        title: String(localized: "Statement Day"),
                        selection: Bindable(vm).statementDayOfMonth
                    )
                    billingDayPicker(
                        title: String(localized: "Payment Due Day"),
                        selection: Bindable(vm).dueDayOfMonth
                    )
                }
            }

            Section(String(localized: "Icon")) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: VSpacing.sm) {
                    ForEach(availableIcons, id: \.self) { iconName in
                        Button {
                            vm.selectedIcon = iconName
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(VColors.tertiaryBackground)
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        if vm.selectedIcon == iconName {
                                            Circle().stroke(VColors.textPrimary, lineWidth: 2)
                                        }
                                    }
                                Image(systemName: iconName)
                                    .font(.body)
                                    .foregroundColor(VColors.textPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "Account icon"))
                        .accessibilityValue(iconName)
                        .accessibilityAddTraits(vm.selectedIcon == iconName ? .isSelected : [])
                    }
                }
                .padding(.vertical, VSpacing.xs)
            }
            .headerProminence(.increased)

            if let error = saveError {
                Section {
                    VInlineErrorText(error)
                }
            }
        }
        .tint(VColors.textPrimary)
    }

    private func billingDayPicker(title: String, selection: Binding<Int?>) -> some View {
        Picker(title, selection: selection) {
            Text(String(localized: "Not set")).tag(Optional<Int>.none)
            ForEach(1...31, id: \.self) { day in
                Text("\(day)").tag(Optional(day))
            }
        }
    }

    private func save() async {
        guard let vm = viewModel else { return }
        isSaving = true
        saveError = nil
        do {
            try await vm.save()
            if !vm.isEditing {
                await dependencies.conversionEventRecorder.afterAccountCreated()
            }
            await dependencies.refreshCreditCardDueReminders()
            appState.notifyChanged(.accounts)
            onSave?()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }

    private func typeName(_ type: AccountType) -> String {
        switch type {
        case .cash: return String(localized: "Cash")
        case .bank: return String(localized: "Bank Account")
        case .creditCard: return String(localized: "Credit Card")
        case .loan: return String(localized: "Loan")
        case .digitalWallet: return String(localized: "Digital Wallet")
        case .investment: return String(localized: "Investment")
        case .receivable: return String(localized: "Receivable")
        case .payable: return String(localized: "Payable")
        }
    }
}

#Preview {
    NavigationStack {
        AccountFormView()
    }
}
