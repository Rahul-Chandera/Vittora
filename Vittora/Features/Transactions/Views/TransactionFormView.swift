import SwiftUI

struct TransactionFormView: View {
    @Environment(\.dependencies) private var dependencies: DependencyContainer
    @Environment(\.dismiss) private var dismiss
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
        NavigationStack {
            if let vm = vm {
                Form {
                    Section {
                        AmountInputView(
                            amountString: Bindable(vm).amountString,
                            currencyCode: "USD",
                            type: vm.type
                        )

                        TransactionTypePicker(type: Bindable(vm).type)

                        Toggle("Quick Entry", isOn: Bindable(vm).isQuickEntry)
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
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task {
                                do {
                                    try await vm.save()
                                    dismiss()
                                } catch {
                                    vm.error = error.localizedDescription
                                }
                            }
                        } label: {
                            Text("Save")
                                .foregroundColor(vm.canSave ? VColors.primary : VColors.textTertiary)
                        }
                        .disabled(!vm.canSave)
                    }
                }
                .if(vm.isLoading) { view in
                    view.overlay {
                        ProgressView()
                            .tint(VColors.primary)
                    }
                }
                .if(vm.error != nil) { view in
                    view.overlay(alignment: .top) {
                        VStack {
                            Text(vm.error ?? "Unknown error")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(VSpacing.md)
                                .background(VColors.expense)
                                .cornerRadius(VSpacing.cornerRadiusSM)
                                .padding(VSpacing.md)
                            Spacer()
                        }
                    }
                }
            }
        }
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

            Picker("Account", selection: Bindable(vm).selectedAccountID) {
                Text("Select account").tag(UUID?.none)
                ForEach(accounts) { account in
                    Text(account.name).tag(UUID?(account.id))
                }
            }
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

            Picker("Account", selection: Bindable(vm).selectedAccountID) {
                Text("Select account").tag(UUID?.none)
                ForEach(accounts) { account in
                    Text(account.name).tag(UUID?(account.id))
                }
            }

            Picker("Payee", selection: Bindable(vm).selectedPayeeID) {
                Text("None").tag(UUID?.none)
                ForEach(payees) { payee in
                    Text(payee.name).tag(UUID?(payee.id))
                }
            }
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
            }
        } catch {
            vm.error = error.localizedDescription
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

        async let accountsTask = {
            let useCase = FetchAccountsUseCase(accountRepository: accountRepo)
            do {
                return try await useCase.execute()
            } catch {
                return []
            }
        }()

        async let categoriesTask = {
            let useCase = FetchCategoriesUseCase(repository: categoryRepo)
            do {
                return try await useCase.executeGrouped()
            } catch {
                return ([], [])
            }
        }()

        async let payeesTask = {
            let useCase = FetchPayeesUseCase(repository: payeeRepo)
            do {
                return try await useCase.execute()
            } catch {
                return []
            }
        }()

        let (accts, cats, pyees) = await (accountsTask, categoriesTask, payeesTask)
        accounts = accts
        categories = cats
        payees = pyees
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
}

#Preview {
    TransactionFormView()
}
