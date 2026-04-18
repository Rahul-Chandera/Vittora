import SwiftUI

struct RecurringFormView: View {
    @Environment(\.dependencies) var dependencies
    @Environment(\.dismiss) var dismiss
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
                                Text("Amount")
                                    .font(VTypography.calloutBold)
                                    .foregroundColor(VColors.textPrimary)

                                HStack(spacing: VSpacing.sm) {
                                    Text("$")
                                        .font(VTypography.callout)
                                        .foregroundColor(VColors.textSecondary)

                                    TextField("0.00", text: Bindable(viewModel).amount)
                                        .font(VTypography.body)
                                        #if os(iOS)
                                        .keyboardType(.decimalPad)
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
                                Text("Start Date")
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
                                    Text("End Date (Optional)")
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
                                Text("Account *")
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
                                            Text("Selected")
                                                .font(VTypography.callout)
                                                .foregroundColor(VColors.textPrimary)
                                        } else {
                                            Text("Choose Account")
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
                                Text("Category (Optional)")
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
                                            Text("Selected")
                                                .font(VTypography.callout)
                                                .foregroundColor(VColors.textPrimary)
                                        } else {
                                            Text("Choose Category")
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
                                Text("Payee (Optional)")
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
                                            Text("Selected")
                                                .font(VTypography.callout)
                                                .foregroundColor(VColors.textPrimary)
                                        } else {
                                            Text("Choose Payee")
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
                                Text("Note (Optional)")
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
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)

                                Text(error)
                                    .font(VTypography.callout)
                                    .foregroundColor(.red)

                                Spacer()
                            }
                            .padding(VSpacing.md)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(VSpacing.cornerRadiusMD)
                            .padding(VSpacing.lg)

                            Spacer()
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(viewModel?.isEditing ?? false ? "Edit Recurring" : "New Recurring")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Save")
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
        accounts = (try? await fetchUseCase.execute()) ?? []
    }

    @MainActor
    private func loadPayees() async {
        guard let payeeRepository = dependencies.payeeRepository else { return }
        let fetchUseCase = FetchPayeesUseCase(repository: payeeRepository)
        payees = (try? await fetchUseCase.execute()) ?? []
    }

    private func save() {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                try await viewModel?.save()
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
        .navigationTitle("Select Category")
        .onAppear {
            Task {
                if let repo = dependencies.categoryRepository {
                    let allCategories = (try? await repo.fetchAll()) ?? []
                    categories = allCategories.filter { $0.type == categoryType }
                }
            }
        }
    }
}

#Preview {
    RecurringFormView()
}
