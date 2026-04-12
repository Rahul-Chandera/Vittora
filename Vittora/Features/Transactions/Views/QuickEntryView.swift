import SwiftUI

struct QuickEntryView: View {
    @Environment(\.dependencies) private var dependencies: DependencyContainer
    @Environment(\.dismiss) private var dismiss
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
                            currencyCode: "USD",
                            type: .expense
                        )
                        .padding(VSpacing.lg)

                        // Account picker
                        Picker("Account", selection: Bindable(vm).selectedAccountID) {
                            Text("Select account").tag(UUID?.none)
                            ForEach(accounts) { account in
                                Text(account.name).tag(UUID?(account.id))
                            }
                        }
                        .padding(.horizontal, VSpacing.lg)

                        // Quick category grid
                        VStack(alignment: .leading, spacing: VSpacing.sm) {
                            Text("Category")
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
                                                .lineLimit(1)
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
                                    #if os(iOS)
                                    let feedback = UIImpactFeedbackGenerator(style: .light)
                                    feedback.impactOccurred()
                                    #endif
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        dismiss()
                                    }
                                } catch {
                                    vm.error = error.localizedDescription
                                }
                            }
                        } label: {
                            Text("Save Transaction")
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
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
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

        async let catsTask = {
            let useCase = FetchCategoriesUseCase(repository: categoryRepo)
            do {
                let grouped = try await useCase.executeGrouped()
                return grouped.expense
            } catch {
                return []
            }
        }()

        async let acctsTask = {
            let useCase = FetchAccountsUseCase(accountRepository: accountRepo)
            do {
                return try await useCase.execute()
            } catch {
                return []
            }
        }()

        let (cats, accts) = await (catsTask, acctsTask)
        categories = cats
        accounts = accts

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
            duplicateDetectionUseCase: duplicateDetectionUseCase
        )
        vm.isQuickEntry = true
        vm.type = .expense

        return vm
    }
}

#Preview {
    QuickEntryView()
}
