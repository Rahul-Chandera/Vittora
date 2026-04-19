import SwiftUI

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

    let transactionID: UUID?

    init(transactionID: UUID? = nil) {
        self.transactionID = transactionID
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
                                Label("Duplicate detected", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(VColors.warning)
                                    .font(VTypography.caption1)

                                Text("Similar transaction(s) found. Review before saving.")
                                    .font(VTypography.caption2)
                                    .foregroundColor(VColors.textSecondary)
                            }
                            .padding(VSpacing.sm)
                        }
                    }
                }
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .accessibilityIdentifier("transaction-form-cancel-button")
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task {
                                do {
                                    try await vm.save()
                                    appState.transactionRefreshVersion += 1
                                    HapticService.success()
                                    dismiss()
                                } catch {
                                    vm.error = error.userFacingMessage(
                                        fallback: String(localized: "We couldn't save this transaction.")
                                    )
                                    HapticService.error()
                                }
                            }
                        } label: {
                            Text("Save")
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
            }
        }
        .accessibilityIdentifier("transaction-form-root")
        .errorAlert(message: transactionErrorBinding)
        .task {
            if vm == nil {
                vm = await createViewModel()
                if let transactionID = transactionID {
                    await loadTransactionData(vm, transactionID: transactionID)
                }
                await loadPickerData()
            }
        }
    }

    @ViewBuilder
    private func quickEntryContent(_ vm: TransactionFormViewModel) -> some View {
        Section {
            Picker("Category", selection: Bindable(vm).selectedCategoryID) {
                Text("Select category").tag(UUID?.none)
                ForEach(categories.expense) { category in
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(Color(hex: category.colorHex) ?? .blue)
                        Text(category.name)
                    }
                    .tag(UUID?(category.id))
                }
            }
            .accessibilityIdentifier("transaction-category-picker")

            Picker("Account", selection: Bindable(vm).selectedAccountID) {
                Text("Select account").tag(UUID?.none)
                ForEach(accounts) { account in
                    Text(account.name).tag(UUID?(account.id))
                }
            }
            .accessibilityIdentifier("transaction-account-picker")
        }
    }

    @ViewBuilder
    private func fullFormContent(_ vm: TransactionFormViewModel) -> some View {
        Section("Details") {
            Picker("Category", selection: Bindable(vm).selectedCategoryID) {
                Text("None").tag(UUID?.none)
                let relevantCategories = vm.type == .income ? categories.income : categories.expense
                ForEach(relevantCategories) { category in
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(Color(hex: category.colorHex) ?? .blue)
                        Text(category.name)
                    }
                    .tag(UUID?(category.id))
                }
            }
            .accessibilityIdentifier("transaction-category-picker")

            Picker("Account", selection: Bindable(vm).selectedAccountID) {
                Text("Select account").tag(UUID?.none)
                ForEach(accounts) { account in
                    Text(account.name).tag(UUID?(account.id))
                }
            }
            .accessibilityIdentifier("transaction-account-picker")

            Picker("Payee", selection: Bindable(vm).selectedPayeeID) {
                Text("None").tag(UUID?.none)
                ForEach(payees) { payee in
                    Text(payee.name).tag(UUID?(payee.id))
                }
            }
            .accessibilityIdentifier("transaction-payee-picker")
            .onChange(of: vm.selectedPayeeID) { _, _ in
                Task {
                    await vm.suggestCategory()
                    await vm.checkDuplicates()
                }
            }

            if let suggestedID = vm.suggestedCategoryID,
               let suggested = (categories.expense + categories.income).first(where: { $0.id == suggestedID }) {
                Button {
                    vm.selectedCategoryID = suggestedID
                } label: {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("Suggested: \(suggested.name)")
                            .foregroundColor(VColors.textPrimary)
                        Spacer()
                    }
                }
            }
        }

        Section("Date & Payment") {
            DatePicker(
                "Date",
                selection: Bindable(vm).date,
                displayedComponents: [.date]
            )

            Picker("Payment Method", selection: Bindable(vm).paymentMethod) {
                ForEach(PaymentMethod.allCases, id: \.self) { method in
                    Text(method.rawValue.capitalized).tag(method)
                }
            }
        }

        Section("Notes") {
            TextField("Notes", text: Bindable(vm).note, axis: .vertical)
                .lineLimit(3...5)
                .accessibilityIdentifier("transaction-note-field")
        }

        Section("Tags") {
            TagInputView(
                tags: Bindable(vm).tags,
                tagInput: Bindable(vm).tagInput,
                onAddTag: { vm.addTag() }
            )
        }
    }

    private func loadTransactionData(_ vm: TransactionFormViewModel?, transactionID: UUID) async {
        guard let vm = vm,
              let transactionRepo = dependencies.transactionRepository else {
            return
        }

        isLoadingData = true
        defer { isLoadingData = false }

        let fetchUseCase = FetchTransactionsUseCase(transactionRepository: transactionRepo)
        do {
            let transactions = try await fetchUseCase.execute(filter: nil)
            if let transaction = transactions.first(where: { $0.id == transactionID }) {
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

        guard let accountRepo = dependencies.accountRepository,
              let categoryRepo = dependencies.categoryRepository,
              let payeeRepo = dependencies.payeeRepository else {
            return
        }

        let fetchAccountsUseCase = FetchAccountsUseCase(accountRepository: accountRepo)
        let fetchCategoriesUseCase = FetchCategoriesUseCase(repository: categoryRepo)
        let fetchPayeesUseCase = FetchPayeesUseCase(repository: payeeRepo)
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

        if vm.selectedAccountID == nil, accounts.count == 1, let first = accounts.first {
            vm.selectedAccountID = first.id
        }

        let relevantCategories = vm.type == .income ? categories.income : categories.expense
        if vm.selectedCategoryID == nil, relevantCategories.count == 1, let first = relevantCategories.first {
            vm.selectedCategoryID = first.id
        }
    }

    private func createViewModel() async -> TransactionFormViewModel? {
        guard let transactionRepo = dependencies.transactionRepository,
              let accountRepo = dependencies.accountRepository,
              let categoryRepo = dependencies.categoryRepository else {
            return nil
        }

        let addUseCase = AddTransactionUseCase(
            transactionRepository: transactionRepo,
            accountRepository: accountRepo,
            categoryRepository: categoryRepo
        )
        let updateUseCase = UpdateTransactionUseCase(
            transactionRepository: transactionRepo,
            accountRepository: accountRepo
        )
        let smartCategorizeUseCase = SmartCategorizeUseCase(transactionRepository: transactionRepo)
        let duplicateDetectionUseCase = DuplicateDetectionUseCase(transactionRepository: transactionRepo)

        return TransactionFormViewModel(
            addUseCase: addUseCase,
            updateUseCase: updateUseCase,
            smartCategorizeUseCase: smartCategorizeUseCase,
            duplicateDetectionUseCase: duplicateDetectionUseCase
        )
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
