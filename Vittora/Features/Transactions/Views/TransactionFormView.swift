import SwiftUI
import VittoraCore

struct TransactionFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyCode) private var currencyCode
    @State private var vm: TransactionFormViewModel?
    @State private var accounts: [AccountEntity] = []
    @State private var categories: (expense: [CategoryEntity], income: [CategoryEntity]) = ([], [])
    @State private var payees: [PayeeEntity] = []
    @State private var isLoadingData = false
    @State private var showAccountPicker = false
    @State private var showCategoryPicker = false
    @State private var showPayeePicker = false
    @State private var showAddPayee = false
    @State private var showAddAccount = false

    let transactionID: UUID?
    let initialType: TransactionType?
    /// Show a Cancel button. Only pass `true` when presenting modally; a pushed
    /// form already has a back button, so Cancel would be a duplicate.
    let showsCancelButton: Bool

    init(
        transactionID: UUID? = nil,
        initialType: TransactionType? = nil,
        showsCancelButton: Bool = false
    ) {
        self.transactionID = transactionID
        self.initialType = initialType
        self.showsCancelButton = showsCancelButton
    }

    var body: some View {
        Group {
            if let vm = vm {
                Form {
                    Section {
                        AmountInputView(
                            amountString: Bindable(vm).amountString,
                            currencyCode: currencyCode,
                            type: vm.type,
                            textFieldAccessibilityIdentifier: "transaction-amount-field"
                        )

                        TransactionTypePicker(type: Bindable(vm).type)
                            .accessibilityIdentifier("transaction-type-picker")

                        Toggle("Quick Entry", isOn: Bindable(vm).isQuickEntry)
                            .accessibilityIdentifier("transaction-quick-entry-toggle")
                    }

                    if vm.isQuickEntry {
                        quickEntryContent(vm)
                    } else {
                        fullFormContent(vm)
                    }

                    if !vm.duplicateWarning.isEmpty {
                        Section {
                            VStack(alignment: .leading, spacing: VSpacing.sm) {
                                Label(String(localized: "Duplicate detected"), systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(VColors.warning)
                                    .font(VTypography.caption1)

                                Text(String(localized: "Similar transaction(s) found. Review before saving."))
                                    .font(VTypography.caption2)
                                    .foregroundColor(VColors.textSecondary)
                            }
                            .padding(VSpacing.sm)
                        }
                    }
                }
                // Without an explicit title the pushed form inherits the
                // window's ("Vittora") on macOS.
                .navigationTitle(transactionID != nil
                    ? String(localized: "Edit Transaction")
                    : String(localized: "New Transaction"))
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    // Only when presented modally — a pushed form already has a
                    // back button, so Cancel would be a duplicate top-left button.
                    if showsCancelButton {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "Cancel")) {
                                dismiss()
                            }
                            .accessibilityIdentifier("transaction-form-cancel-button")
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task {
                                do {
                                    try await vm.save()
                                    if !vm.isEditing {
                                        await dependencies.conversionEventRecorder.afterTransactionCreated()
                                    }
                                    await dependencies.refreshBudgetThresholdAlerts()
                                    appState.notifyChanged([.transactions, .accounts, .budgets])
                                    dependencies.hapticService.success()
                                    dismiss()
                                } catch {
                                    vm.error = error.userFacingMessage(
                                        fallback: String(localized: "We couldn't save this transaction.")
                                    )
                                    dependencies.hapticService.error()
                                }
                            }
                        } label: {
                            Text(String(localized: "Save"))
                                .foregroundColor(vm.canSave ? VColors.primary : VColors.textTertiary)
                        }
                        .disabled(!vm.canSave)
                        .accessibilityIdentifier("transaction-form-save-button")
                    }
                }
                .if(vm.isLoading) { view in
                    view.overlay {
                        ProgressView()
                            .tint(VColors.primary)
                    }
                }
            } else {
                ProgressView()
                    .tint(VColors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityIdentifier("transaction-form-root")
        .errorAlert(message: transactionErrorBinding)
        .sheet(isPresented: $showAddPayee) {
            NavigationStack {
                PayeeFormView {
                    Task { await reloadPayeesSelectingNewest() }
                }
            }
        }
        .sheet(isPresented: $showAddAccount) {
            NavigationStack {
                AccountFormView(showsCancelButton: true) {
                    Task { await reloadAccountsSelectingNewest() }
                }
            }
        }
        .task {
            if vm == nil {
                vm = createViewModel()
                if let vm {
                    if transactionID == nil, let initialType {
                        vm.type = initialType
                    }
                    if let transactionID = transactionID {
                        await loadTransactionData(vm, transactionID: transactionID)
                    }
                    await loadPickerData()
                }
            }
        }
    }

    @ViewBuilder
    private func quickEntryContent(_ vm: TransactionFormViewModel) -> some View {
        Section {
            Picker(String(localized: "Category"), selection: Bindable(vm).selectedCategoryID) {
                Text(String(localized: "Select category")).tag(UUID?.none)
                ForEach(categories.expense) { category in
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(Color(hex: category.colorHex) ?? .blue)
                        Text(category.displayName)
                    }
                    .tag(UUID?(category.id))
                }
            }
            .accessibilityIdentifier("transaction-category-picker")

            Picker(String(localized: "Account"), selection: Bindable(vm).selectedAccountID) {
                Text(String(localized: "Select account")).tag(UUID?.none)
                ForEach(accounts) { account in
                    Text(account.name).tag(UUID?(account.id))
                }
            }
            .accessibilityIdentifier("transaction-account-picker")
        }
    }

    @ViewBuilder
    private func fullFormContent(_ vm: TransactionFormViewModel) -> some View {
        Section {
            Picker(String(localized: "Category"), selection: Bindable(vm).selectedCategoryID) {
                Text(String(localized: "None")).tag(UUID?.none)
                let relevantCategories = vm.type == .income ? categories.income : categories.expense
                ForEach(relevantCategories) { category in
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(Color(hex: category.colorHex) ?? .blue)
                            .accessibilityHidden(true)
                        Text(category.displayName)
                    }
                    .tag(UUID?(category.id))
                }
            }
            .accessibilityIdentifier("transaction-category-picker")

            Picker(String(localized: "Account"), selection: Bindable(vm).selectedAccountID) {
                Text(String(localized: "Select account")).tag(UUID?.none)
                ForEach(accounts) { account in
                    Text(account.name).tag(UUID?(account.id))
                }
            }
            .accessibilityIdentifier("transaction-account-picker")

            Button {
                showAddAccount = true
            } label: {
                Text(String(localized: "Add Account"))
            }
            .accessibilityIdentifier("transaction-add-account-button")
            .accessibilityLabel(String(localized: "Add Account"))

            Picker(String(localized: "Payee"), selection: Bindable(vm).selectedPayeeID) {
                Text(String(localized: "None")).tag(UUID?.none)
                ForEach(payees) { payee in
                    Text(payee.name).tag(UUID?(payee.id))
                }
            }
            .accessibilityIdentifier("transaction-payee-picker")
            .onChange(of: vm.selectedPayeeID) { _, _ in
                Task {
                    await vm.suggestCategory(payeeName: payeeName(for: vm.selectedPayeeID))
                    await vm.checkDuplicates()
                }
            }

            Button {
                showAddPayee = true
            } label: {
                Text(String(localized: "Add Payee"))
            }
            .accessibilityIdentifier("transaction-add-payee-button")
            .accessibilityLabel(String(localized: "Add Payee"))

            if let suggestedID = vm.suggestedCategoryID,
               let suggested = (categories.expense + categories.income).first(where: { $0.id == suggestedID }) {
                Button {
                    vm.selectedCategoryID = suggestedID
                } label: {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                            .accessibilityHidden(true)
                        Text(String(localized: "Suggested: \(suggested.displayName)"))
                            .foregroundColor(VColors.textPrimary)
                        Spacer()
                    }
                }
                .accessibilityLabel(String(localized: "Suggested category: \(suggested.displayName)"))
            }
        } header: {
            formSectionHeader(String(localized: "Details"))
        }

        Section {
            DatePicker(
                String(localized: "Date"),
                selection: Bindable(vm).date,
                displayedComponents: [.date]
            )

            Picker(String(localized: "Payment Method"), selection: Bindable(vm).paymentMethod) {
                ForEach(PaymentMethod.allCases, id: \.self) { method in
                    Text(method.displayName).tag(method)
                }
            }
        } header: {
            formSectionHeader(String(localized: "Date & Payment"))
        }

        Section {
            TextField(String(localized: "Notes"), text: Bindable(vm).note, axis: .vertical)
                .lineLimit(3...5)
                .accessibilityIdentifier("transaction-note-field")
                .onChange(of: vm.note) { _, _ in
                    Task {
                        await vm.suggestCategory(payeeName: payeeName(for: vm.selectedPayeeID))
                    }
                }
        } header: {
            formSectionHeader(String(localized: "Notes"))
        }

        Section {
            TagInputView(
                tags: Bindable(vm).tags,
                tagInput: Bindable(vm).tagInput,
                onAddTag: { vm.addTag() }
            )
        } header: {
            formSectionHeader(String(localized: "Tags"))
        }
    }

    private func formSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(VTypography.caption1)
            .foregroundColor(VColors.textSecondary)
            .textCase(nil)
    }

    private func loadTransactionData(_ vm: TransactionFormViewModel?, transactionID: UUID) async {
        guard let vm = vm else {
            return
        }

        isLoadingData = true
        defer { isLoadingData = false }

        let fetchUseCase = FetchTransactionsUseCase(transactionRepository: dependencies.transactionRepository)
        do {
            if let transaction = try await fetchUseCase.execute(id: transactionID) {
                vm.loadTransaction(transaction)
            } else {
                vm.error = String(localized: "We couldn't find this transaction.")
            }
        } catch {
            vm.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't load this transaction right now.")
            )
        }
    }

    private func loadPickerData() async {
        isLoadingData = true
        defer { isLoadingData = false }

        let fetchAccountsUseCase = FetchAccountsUseCase(accountRepository: dependencies.accountRepository)
        let fetchCategoriesUseCase = FetchCategoriesUseCase(repository: dependencies.categoryRepository)
        let fetchPayeesUseCase = FetchPayeesUseCase(repository: dependencies.payeeRepository)
        var didFailToLoadPickerData = false

        do {
            accounts = try await fetchAccountsUseCase.execute()
        } catch {
            accounts = []
            didFailToLoadPickerData = true
        }

        do {
            categories = try await fetchCategoriesUseCase.executeGrouped()
        } catch {
            categories = ([], [])
            didFailToLoadPickerData = true
        }

        do {
            payees = try await fetchPayeesUseCase.execute()
        } catch {
            payees = []
            didFailToLoadPickerData = true
        }

        if didFailToLoadPickerData {
            vm?.error = String(
                localized: "Some transaction form options couldn't be loaded. Please try again."
            )
        }

        applyDefaultSelectionsIfNeeded()
    }

    private func applyDefaultSelectionsIfNeeded() {
        guard let vm else { return }

        vm.selectDefaultAccountIfNeeded(from: accounts)

        let relevantCategories = vm.type == .income ? categories.income : categories.expense
        if vm.selectedCategoryID == nil, relevantCategories.count == 1, let first = relevantCategories.first {
            vm.selectedCategoryID = first.id
        }
    }

    private func payeeName(for payeeID: UUID?) -> String? {
        guard let payeeID else { return nil }
        return payees.first(where: { $0.id == payeeID })?.name
    }

    /// Refreshes the payee list after inline creation and auto-selects the newly
    /// added payee (the one absent from the list before the add sheet ran), so the
    /// user doesn't have to re-open the picker to pick what they just created.
    private func reloadPayeesSelectingNewest() async {
        let previousIDs = Set(payees.map(\.id))
        let fetchPayeesUseCase = FetchPayeesUseCase(repository: dependencies.payeeRepository)
        guard let refreshed = try? await fetchPayeesUseCase.execute() else { return }
        payees = refreshed
        if let newPayee = refreshed.first(where: { !previousIDs.contains($0.id) }) {
            vm?.selectedPayeeID = newPayee.id
        }
    }

    /// Mirror of `reloadPayeesSelectingNewest` for inline account creation: refresh
    /// the account list and select the just-added account (absent before the sheet),
    /// which also satisfies the required-account rule so Save enables immediately.
    private func reloadAccountsSelectingNewest() async {
        let previousIDs = Set(accounts.map(\.id))
        let fetchAccountsUseCase = FetchAccountsUseCase(accountRepository: dependencies.accountRepository)
        guard let refreshed = try? await fetchAccountsUseCase.execute() else { return }
        accounts = refreshed
        if let newAccount = refreshed.first(where: { !previousIDs.contains($0.id) }) {
            vm?.selectedAccountID = newAccount.id
        }
    }

    private func createViewModel() -> TransactionFormViewModel {
        dependencies.makeTransactionFormViewModel(currencyCode: currencyCode)
    }

    private var transactionErrorBinding: Binding<String?> {
        Binding(
            get: { vm?.error },
            set: { newValue in
                vm?.error = newValue
            }
        )
    }
}

#Preview {
    TransactionFormView()
}
