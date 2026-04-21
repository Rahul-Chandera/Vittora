import SwiftUI

struct BudgetFormView: View {
    @Environment(\.dependencies) var dependencies
    @Environment(\.currencySymbol) private var currencySymbol
    @Binding var isPresented: Bool
    @State private var viewModel: BudgetFormViewModel?
    @State private var showCategoryPicker = false
    @State private var categories: [CategoryEntity] = []
    @State private var selectedCategory: CategoryEntity?

    var editingBudget: BudgetEntity?

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Amount")) {
                    HStack {
                        Text(currencySymbol)
                            .foregroundColor(VColors.textSecondary)
                        TextField("0.00", text: Binding(
                            get: { viewModel?.amount ?? "" },
                            set: { viewModel?.amount = $0 }
                        ))
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .accessibilityIdentifier("budget-amount-field")
                    }
                }

                Section(String(localized: "Period")) {
                    if let viewModel = viewModel {
                        PeriodSelectorView(selectedPeriod: Bindable(viewModel).selectedPeriod)
                    }
                }

                Section(String(localized: "Category")) {
                    NavigationLink(
                        destination: {
                            if let viewModel = viewModel {
                                CategoryPicker(
                                    selectedCategoryID: Bindable(viewModel).selectedCategoryID,
                                    categories: categories,
                                    filterType: .expense,
                                    title: String(localized: "Select Expense Category")
                                )
                                .onChange(of: viewModel.selectedCategoryID) { _, newID in
                                    selectedCategory = categories.first(where: { $0.id == newID })
                                }
                            }
                        },
                        label: {
                            HStack {
                                Text(String(localized: "Optional"))
                                    .foregroundColor(VColors.textSecondary)
                                Spacer()
                                if let category = selectedCategory {
                                    HStack(spacing: VSpacing.xs) {
                                        Image(systemName: category.icon)
                                            .foregroundColor(Color(hex: category.colorHex) ?? .blue)
                                        Text(category.name)
                                            .foregroundColor(VColors.textPrimary)
                                    }
                                } else {
                                    Text(String(localized: "None"))
                                        .foregroundColor(VColors.textSecondary)
                                }
                            }
                        }
                    )
                }

                Section(String(localized: "Options")) {
                    if let viewModel = viewModel {
                        Toggle("Rollover Unused Amount", isOn: Bindable(viewModel).rollover)
                    }
                }

                Section(String(localized: "Start Date")) {
                    if let viewModel = viewModel {
                        DatePicker(
                            "Date",
                            selection: Bindable(viewModel).startDate,
                            displayedComponents: .date
                        )
                    }
                }
            }
            .navigationTitle(editingBudget != nil ? String(localized: "Edit Budget") : String(localized: "New Budget"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        isPresented = false
                    }
                    .accessibilityIdentifier("budget-cancel-button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        Task {
                            do {
                                try await viewModel?.save()
                                isPresented = false
                            } catch {
                                viewModel?.error = error.localizedDescription
                            }
                        }
                    }
                    .disabled(viewModel?.canSave != true)
                    .accessibilityIdentifier("budget-save-button")
                }
            }
            .accessibilityIdentifier("budget-form-root")
        }
        .task {
            if viewModel == nil {
                let createUseCase = CreateBudgetUseCase(
                    budgetRepository: dependencies.budgetRepository ?? MockBudgetRepository()
                )
                let updateUseCase = UpdateBudgetUseCase(
                    budgetRepository: dependencies.budgetRepository ?? MockBudgetRepository()
                )
                viewModel = BudgetFormViewModel(
                    createUseCase: createUseCase,
                    updateUseCase: updateUseCase
                )
            }

            // Load categories
            do {
                categories = try await (dependencies.categoryRepository ?? MockCategoryRepository()).fetchAll()
            } catch {
                // Silent failure
            }

            // Load budget if editing
            if let budget = editingBudget, let viewModel = viewModel {
                viewModel.loadBudget(budget)
                selectedCategory = categories.first(where: { $0.id == budget.categoryID })
            }
        }
    }
}

#Preview {
    BudgetFormView(isPresented: .constant(true))
        .environment(\.dependencies, DependencyContainer())
}
