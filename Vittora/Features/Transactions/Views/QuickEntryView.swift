import SwiftUI

struct QuickEntryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.currencyCode) private var currencyCode
    @State private var vm: TransactionFormViewModel?
    @State private var categories: [CategoryEntity] = []
    @State private var accounts: [AccountEntity] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            if let vm = vm {
                ZStack {
                    VStack(spacing: VSpacing.lg) {
                        // Large amount input
                        AmountInputView(
                            amountString: Bindable(vm).amountString,
                            currencyCode: currencyCode,
                            type: .expense
                        )
                        .padding(VSpacing.lg)

                        // Account picker
                        Picker(String(localized: "Account"), selection: Bindable(vm).selectedAccountID) {
                            Text(String(localized: "Select account")).tag(UUID?.none)
                            ForEach(accounts) { account in
                                Text(account.name).tag(UUID?(account.id))
                            }
                        }
                        .padding(.horizontal, VSpacing.lg)

                        // Quick category grid
                        VStack(alignment: .leading, spacing: VSpacing.sm) {
                            Text(String(localized: "Category"))
                                .font(VTypography.caption2)
                                .foregroundColor(VColors.textSecondary)
                                .padding(.horizontal, VSpacing.lg)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: VSpacing.md) {
                                    ForEach(categories.prefix(8)) { category in
                                        VStack(spacing: VSpacing.xs) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color(hex: category.colorHex) ?? .blue)
                                                    .frame(width: 44, height: 44)

                                                Image(systemName: category.icon)
                                                    .font(.title3)
                                                    .foregroundColor(.white)
                                            }

                                            Text(category.name)
                                                .font(VTypography.caption2)
                                                .foregroundColor(VColors.textPrimary)
                                                .adaptiveLineLimit(1)
                                        }
                                        .frame(width: 60)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            vm.selectedCategoryID = category.id
                                        }
                                        .opacity(vm.selectedCategoryID == category.id ? 1.0 : 0.6)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, VSpacing.lg)
                            }
                        }

                        Spacer()

                        // Save button
                        Button {
                            Task {
                                do {
                                    try await vm.save()
                                    appState.transactionRefreshVersion += 1
                                    #if os(iOS)
                                    let feedback = UIImpactFeedbackGenerator(style: .light)
                                    feedback.impactOccurred()
                                    #endif
                                    try await Task.sleep(for: .milliseconds(300))
                                    dismiss()
                                } catch {
                                    vm.error = error.userFacingMessage(
                                        fallback: String(localized: "We couldn't save this transaction.")
                                    )
                                }
                            }
                        } label: {
                            Text(String(localized: "Save Transaction"))
                                .font(VTypography.body)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(VSpacing.md)
                                .background(VColors.primary)
                                .cornerRadius(VSpacing.cornerRadiusSM)
                        }
                        .disabled(!vm.canSave)
                        .padding(VSpacing.lg)
                    }
                    .padding(.top, VSpacing.lg)

                    if isLoading {
                        ProgressView()
                            .tint(VColors.primary)
                    }

                    if vm.isLoading {
                        ProgressView()
                            .tint(VColors.primary)
                    }
                }
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Cancel")) {
                            dismiss()
                        }
                    }
                }
            }
        }
        .errorAlert(message: quickEntryErrorBinding)
        .task {
            if vm == nil {
                vm = await createViewModel()
                await loadCategories()
            }
        }
    }

    private func loadCategories() async {
        isLoading = true
        defer { isLoading = false }

        guard let categoryRepo = dependencies.categoryRepository,
              let accountRepo = dependencies.accountRepository else {
            return
        }

        let fetchCategoriesUseCase = FetchCategoriesUseCase(repository: categoryRepo)
        let fetchAccountsUseCase = FetchAccountsUseCase(accountRepository: accountRepo)
        var didFailToLoadOptions = false

        do {
            let groupedCategories = try await fetchCategoriesUseCase.executeGrouped()
            categories = groupedCategories.expense
        } catch {
            categories = []
            didFailToLoadOptions = true
        }

        do {
            accounts = try await fetchAccountsUseCase.execute()
        } catch {
            accounts = []
            didFailToLoadOptions = true
        }

        if didFailToLoadOptions {
            vm?.error = String(
                localized: "Some quick entry options couldn't be loaded. Please try again."
            )
        }

        if !accounts.isEmpty {
            vm?.selectedAccountID = accounts.first?.id
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

        let vm = TransactionFormViewModel(
            addUseCase: addUseCase,
            updateUseCase: updateUseCase,
            smartCategorizeUseCase: smartCategorizeUseCase,
            duplicateDetectionUseCase: duplicateDetectionUseCase,
            currencyCode: currencyCode
        )
        vm.isQuickEntry = true
        vm.type = .expense

        return vm
    }

    private var quickEntryErrorBinding: Binding<String?> {
        Binding(
            get: { vm?.error },
            set: { newValue in
                vm?.error = newValue
            }
        )
    }
}

#Preview {
    QuickEntryView()
}
