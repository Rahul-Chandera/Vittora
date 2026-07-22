import SwiftUI
import VittoraCore

struct RecurringFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) var dependencies
    @Environment(\.dismiss) var dismiss
    @Environment(\.currencySymbol) private var currencySymbol
    @Environment(\.currencyCode) private var currencyCode
    @State private var viewModel: RecurringFormViewModel?
    @State private var accounts: [AccountEntity] = []
    @State private var categories: [CategoryEntity] = []
    @State private var payees: [PayeeEntity] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    /// When set, the form opens pre-filled and saves as an edit of this rule.
    var editingRule: RecurringRuleEntity? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                VColors.background.ignoresSafeArea()

                if let viewModel = viewModel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: VSpacing.lg) {
                            // Amount Input
                            VStack(alignment: .leading, spacing: VSpacing.sm) {
                                Text(String(localized: "Amount"))
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                HStack(spacing: VSpacing.sm) {
                                    Text(currencySymbol)
                                        .font(VTypography.callout)
                                        .foregroundColor(.primary)
                                        .accessibilityHidden(true)

                                    TextField(
                                        "",
                                        text: Bindable(viewModel).amount
                                    )
                                        .font(VTypography.body)
                                        #if os(iOS)
                                        .keyboardType(.decimalPad)
                                        .textContentType(nil)
                                        #endif
                                        .accessibilityLabel(String(localized: "Amount"))
                                        .accessibilityHint(String(localized: "Amount in \(currencyCode)"))
                                }
                                .padding(VSpacing.md)
                                .background(VColors.secondaryBackground)
                                .cornerRadius(VSpacing.cornerRadiusMD)
                            }

                            // Frequency Picker
                            FrequencyPickerView(selectedFrequency: Bindable(viewModel).selectedFrequency)

                            // Start Date
                            VStack(alignment: .leading, spacing: VSpacing.sm) {
                                Text(String(localized: "Start Date"))
                                    .font(VTypography.calloutBold)
                                    .foregroundColor(VColors.textPrimary)

                                DatePicker(
                                    "Start Date",
                                    selection: Bindable(viewModel).startDate,
                                    displayedComponents: [.date]
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                                .padding(VSpacing.md)
                                .background(VColors.secondaryBackground)
                                .cornerRadius(VSpacing.cornerRadiusMD)
                            }

                            // Optional End Date
                            VStack(alignment: .leading, spacing: VSpacing.sm) {
                                HStack {
                                    Text(String(localized: "End Date (Optional)"))
                                        .font(VTypography.calloutBold)
                                        .foregroundColor(VColors.textPrimary)

                                    Spacer()

                                    Toggle("", isOn: Bindable(viewModel).hasEndDate)
                                        .tint(VColors.primary)
                                }

                                if viewModel.hasEndDate {
                                    DatePicker(
                                        "End Date",
                                        selection: Binding(
                                            get: { viewModel.endDate ?? .now },
                                            set: { viewModel.endDate = $0 }
                                        ),
                                        displayedComponents: [.date]
                                    )
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity)
                                    .padding(VSpacing.md)
                                    .background(VColors.secondaryBackground)
                                    .cornerRadius(VSpacing.cornerRadiusMD)
                                }
                            }

                            // Account Selection
                            VStack(alignment: .leading, spacing: VSpacing.sm) {
                                Text(String(localized: "Account *"))
                                    .font(VTypography.calloutBold)
                                    .foregroundColor(VColors.textPrimary)

                                NavigationLink(
                                    destination: AccountPickerView(
                                        selectedAccountID: Bindable(viewModel).selectedAccountID,
                                        accounts: accounts
                                    )
                                ) {
                                    HStack {
                                        if let account = selectedAccount(for: viewModel) {
                                            Text(account.name)
                                                .font(VTypography.callout)
                                                .foregroundColor(.primary)
                                        } else {
                                            Text(String(localized: "Choose Account"))
                                                .font(VTypography.callout)
                                                .foregroundColor(.primary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(VColors.textSecondary)
                                            .accessibilityHidden(true)
                                    }
                                    .padding(VSpacing.md)
                                    .background(VColors.secondaryBackground)
                                    .cornerRadius(VSpacing.cornerRadiusMD)
                                }
                                .accessibilityIdentifier("recurring-account-picker")
                                .accessibilityLabel(
                                    selectedAccount(for: viewModel)?.name ?? String(localized: "Choose Account")
                                )
                            }

                            // Category Selection
                            VStack(alignment: .leading, spacing: VSpacing.sm) {
                                Text(String(localized: "Category (Optional)"))
                                    .font(VTypography.calloutBold)
                                    .foregroundColor(VColors.textPrimary)

                                NavigationLink(
                                    destination: RecurringCategoryPickerView(
                                        selectedID: Bindable(viewModel).selectedCategoryID,
                                        categories: categories,
                                        categoryType: .expense
                                    )
                                ) {
                                    HStack {
                                        if let category = selectedCategory(for: viewModel) {
                                            Image(systemName: category.icon)
                                                .foregroundColor(Color(hex: category.colorHex) ?? .blue)
                                                .accessibilityHidden(true)
                                            Text(category.name)
                                                .font(VTypography.callout)
                                                .foregroundColor(VColors.textPrimary)
                                        } else {
                                            Text(String(localized: "Choose Category"))
                                                .font(VTypography.callout)
                                                .foregroundColor(VColors.textPrimary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(VColors.textSecondary)
                                            .accessibilityHidden(true)
                                    }
                                    .padding(VSpacing.md)
                                    .background(VColors.secondaryBackground)
                                    .cornerRadius(VSpacing.cornerRadiusMD)
                                }
                                .accessibilityIdentifier("recurring-category-picker")
                                .accessibilityLabel(
                                    selectedCategory(for: viewModel)?.name ?? String(localized: "Choose Category")
                                )
                            }

                            // Payee Selection
                            VStack(alignment: .leading, spacing: VSpacing.sm) {
                                Text(String(localized: "Payee (Optional)"))
                                    .font(VTypography.calloutBold)
                                    .foregroundColor(VColors.textPrimary)

                                NavigationLink(
                                    destination: PayeePickerView(
                                        selectedPayeeID: Bindable(viewModel).selectedPayeeID,
                                        payees: payees
                                    )
                                ) {
                                    HStack {
                                        if let payee = selectedPayee(for: viewModel) {
                                            Text(payee.name)
                                                .font(VTypography.callout)
                                                .foregroundColor(VColors.textPrimary)
                                        } else {
                                            Text(String(localized: "Choose Payee"))
                                                .font(VTypography.callout)
                                                .foregroundColor(VColors.textPrimary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(VColors.textSecondary)
                                            .accessibilityHidden(true)
                                    }
                                    .padding(VSpacing.md)
                                    .background(VColors.secondaryBackground)
                                    .cornerRadius(VSpacing.cornerRadiusMD)
                                }
                                .accessibilityIdentifier("recurring-payee-picker")
                                .accessibilityLabel(
                                    selectedPayee(for: viewModel)?.name ?? String(localized: "Choose Payee")
                                )
                            }

                            // Note Input
                            VStack(alignment: .leading, spacing: VSpacing.sm) {
                                Text(String(localized: "Note (Optional)"))
                                    .font(VTypography.calloutBold)
                                    .foregroundColor(VColors.textPrimary)

                                TextEditor(text: Bindable(viewModel).note)
                                    .font(VTypography.body)
                                    .frame(height: 100)
                                    .padding(VSpacing.sm)
                                    .background(VColors.secondaryBackground)
                                    .cornerRadius(VSpacing.cornerRadiusMD)
                            }

                            Spacer()
                        }
                        .padding(VSpacing.lg)
                    }

                    if let error = errorMessage {
                        VStack {
                            VInlineErrorText(error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(VSpacing.md)
                                .background(VColors.expense.opacity(0.1))
                                .cornerRadius(VSpacing.cornerRadiusMD)
                                .padding(VSpacing.lg)

                            Spacer()
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .tint(VColors.textPrimary)
            .navigationTitle(viewModel?.isEditing ?? false ? String(localized: "Edit Recurring") : String(localized: "New Recurring"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                    .font(.body)
                    .foregroundStyle(VColors.textPrimary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(String(localized: "Save"))
                                .font(.body)
                                .foregroundColor(VColors.textPrimary)
                        }
                    }
                    .disabled(!(viewModel?.canSave ?? false) || isLoading)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                setupViewModel()
                Task {
                    await loadAccounts()
                    await loadCategories()
                    await loadPayees()
                }
            }
        }
        .onChange(of: errorMessage) { _, newValue in
            if let msg = newValue {
                AccessibilityNotification.Announcement(AttributedString(msg)).post()
            }
        }
    }

    private func setupViewModel() {
        let recurringRepo = dependencies.recurringRuleRepository

        let createUseCase = CreateRecurringRuleUseCase(repository: recurringRepo)
        let updateUseCase = UpdateRecurringRuleUseCase(repository: recurringRepo)

        let vm = RecurringFormViewModel(
            createUseCase: createUseCase,
            updateUseCase: updateUseCase,
            repository: recurringRepo
        )
        if let editingRule {
            vm.loadRule(editingRule)
        }
        viewModel = vm
    }

    @MainActor
    private func loadAccounts() async {
        let fetchUseCase = FetchAccountsUseCase(accountRepository: dependencies.accountRepository)
        do {
            accounts = try await fetchUseCase.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadPayees() async {
        let fetchUseCase = FetchPayeesUseCase(repository: dependencies.payeeRepository)
        do {
            payees = try await fetchUseCase.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadCategories() async {
        do {
            categories = try await dependencies.categoryRepository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func selectedAccount(for viewModel: RecurringFormViewModel) -> AccountEntity? {
        accounts.first { $0.id == viewModel.selectedAccountID }
    }

    private func selectedCategory(for viewModel: RecurringFormViewModel) -> CategoryEntity? {
        categories.first { $0.id == viewModel.selectedCategoryID }
    }

    private func selectedPayee(for viewModel: RecurringFormViewModel) -> PayeeEntity? {
        payees.first { $0.id == viewModel.selectedPayeeID }
    }

    private func save() {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                try await viewModel?.save()
                await dependencies.refreshRecurringAndDebtReminders()
                appState.notifyChanged(.recurring)
                onDismiss?()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }
}

struct RecurringCategoryPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedID: UUID?
    let categories: [CategoryEntity]
    var categoryType: CategoryType = .expense

    var body: some View {
        List(categories.filter { $0.type == categoryType }, id: \.id) { category in
            Button(action: {
                selectedID = category.id
                dismiss()
            }) {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(Color(hex: category.colorHex) ?? .blue)

                    Text(category.displayName)
                        .font(VTypography.callout)
                        .foregroundColor(VColors.textPrimary)

                    Spacer()

                    if selectedID == category.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(VColors.primary)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Select Category"))
    }
}

#Preview {
    RecurringFormView()
}
