import SwiftUI

struct RecurringFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) var dependencies
    @Environment(\.dismiss) var dismiss
    @Environment(\.currencySymbol) private var currencySymbol
    @State private var viewModel: RecurringFormViewModel?
    @State private var accounts: [AccountEntity] = []
    @State private var payees: [PayeeEntity] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
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
                                    .font(VTypography.calloutBold)
                                    .foregroundColor(VColors.textPrimary)

                                HStack(spacing: VSpacing.sm) {
                                    Text(currencySymbol)
                                        .font(VTypography.callout)
                                        .foregroundColor(VColors.textSecondary)

                                    TextField("0.00", text: Bindable(viewModel).amount)
                                        .font(VTypography.body)
                                        #if os(iOS)
                                        .keyboardType(.decimalPad)
                                        .textContentType(nil)
                                        #endif
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
                                        if viewModel.selectedAccountID != nil {
                                            Text(String(localized: "Selected"))
                                                .font(VTypography.callout)
                                                .foregroundColor(VColors.textPrimary)
                                        } else {
                                            Text(String(localized: "Choose Account"))
                                                .font(VTypography.callout)
                                                .foregroundColor(VColors.textSecondary)
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
                            }

                            // Category Selection
                            VStack(alignment: .leading, spacing: VSpacing.sm) {
                                Text(String(localized: "Category (Optional)"))
                                    .font(VTypography.calloutBold)
                                    .foregroundColor(VColors.textPrimary)

                                NavigationLink(
                                    destination: RecurringCategoryPickerView(
                                        selectedID: Bindable(viewModel).selectedCategoryID,
                                        categoryType: .expense
                                    )
                                ) {
                                    HStack {
                                        if viewModel.selectedCategoryID != nil {
                                            Text(String(localized: "Selected"))
                                                .font(VTypography.callout)
                                                .foregroundColor(VColors.textPrimary)
                                        } else {
                                            Text(String(localized: "Choose Category"))
                                                .font(VTypography.callout)
                                                .foregroundColor(VColors.textSecondary)
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
                                        if viewModel.selectedPayeeID != nil {
                                            Text(String(localized: "Selected"))
                                                .font(VTypography.callout)
                                                .foregroundColor(VColors.textPrimary)
                                        } else {
                                            Text(String(localized: "Choose Payee"))
                                                .font(VTypography.callout)
                                                .foregroundColor(VColors.textSecondary)
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
            .navigationTitle(viewModel?.isEditing ?? false ? String(localized: "Edit Recurring") : String(localized: "New Recurring"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(String(localized: "Save"))
                                .font(VTypography.calloutBold)
                                .foregroundColor(viewModel?.canSave ?? false ? VColors.primary : VColors.textSecondary)
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
        guard let recurringRepo = dependencies.recurringRuleRepository else { return }

        let createUseCase = CreateRecurringRuleUseCase(repository: recurringRepo)
        let updateUseCase = UpdateRecurringRuleUseCase(repository: recurringRepo)

        viewModel = RecurringFormViewModel(
            createUseCase: createUseCase,
            updateUseCase: updateUseCase,
            repository: recurringRepo
        )
    }

    @MainActor
    private func loadAccounts() async {
        guard let accountRepository = dependencies.accountRepository else { return }
        let fetchUseCase = FetchAccountsUseCase(accountRepository: accountRepository)
        do {
            accounts = try await fetchUseCase.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadPayees() async {
        guard let payeeRepository = dependencies.payeeRepository else { return }
        let fetchUseCase = FetchPayeesUseCase(repository: payeeRepository)
        do {
            payees = try await fetchUseCase.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                try await viewModel?.save()
                appState.notifyDataChanged()
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
    @Environment(\.dependencies) var dependencies
    @Environment(\.dismiss) var dismiss
    @Binding var selectedID: UUID?
    var categoryType: CategoryType = .expense
    @State private var categories: [CategoryEntity] = []
    @State private var loadError: String?

    var body: some View {
        List(categories, id: \.id) { category in
            Button(action: {
                selectedID = category.id
                dismiss()
            }) {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(Color(hex: category.colorHex) ?? .blue)

                    Text(category.name)
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
        .overlay {
            if let loadError {
                Text(loadError)
                    .foregroundStyle(VColors.expense)
                    .padding()
            }
        }
        .onAppear {
            Task {
                guard let repo = dependencies.categoryRepository else { return }
                do {
                    let allCategories = try await repo.fetchAll()
                    categories = allCategories.filter { $0.type == categoryType }
                } catch {
                    loadError = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    RecurringFormView()
}
