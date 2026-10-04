import SwiftUI
import VittoraCore

/// Shopping mode (M3.3.1 / M3.3.2).
///
/// A deliberately small screen: name the shop, add amounts as you pick things up,
/// and the running total plus remaining budget appear on the Lock Screen and in
/// the Dynamic Island. The point of the feature is to be usable without opening
/// the app, so this screen exists mainly to start and stop the session.
///
/// Nothing here writes a transaction. A shopping session is a running tally, not
/// a ledger entry — turning each item into a transaction would fill the ledger
/// with fragments of one shop. The user records the actual purchase afterwards.
struct ShoppingModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies

    @State private var sessionName = ""
    @State private var amountText = ""
    @State private var runningTotal: Decimal = 0
    @State private var itemCount = 0
    @State private var isRunning = false
    @State private var error: String?
    @State private var budgetOptions: [ShoppingBudgetOption] = []
    @State private var selectedBudgetID: UUID?
    /// What was left in the chosen budget when the session started. The screen
    /// subtracts the running total from this, exactly as the Live Activity does.
    @State private var startingBudget: ShoppingBudgetOption?

    private let controller = LiveActivityController.shared

    // The app's display currency, like every other screen — NOT the device
    // locale. The init this replaces defaulted to
    // `Locale.current.currency?.identifier`, and AppTabView constructs this
    // view with no argument, so a US ledger on a device set to India showed a
    // running total of "₹0.00" while the rest of the app showed dollars. The
    // Live Activity inherited it, so the Lock Screen and Dynamic Island were
    // wrong too.
    @Environment(\.currencyCode) private var currencyCode

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    if !controller.areActivitiesEnabled {
                        Section {
                            Text(String(localized: "Live Activities are switched off for Vittora. Turn them on in Settings to see your running total on the Lock Screen."))
                                .font(VTypography.caption1)
                                .foregroundStyle(VColors.textSecondary)
                        }
                    }

                    if isRunning {
                        runningSection
                        addItemSection
                    } else {
                        startSection
                    }
                }
                .vListContentTint()
            }
            .vListSelectionTint()
            .navigationTitle(String(localized: "Shopping Mode"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) {
                        Task {
                            // Ending the session on dismiss, deliberately: an
                            // activity left running with a total the user has
                            // stopped adding to reads as current when it is not.
                            if isRunning { await controller.endShoppingSession() }
                            dismiss()
                        }
                    }
                    .vDialogConfirmButton()
                }
                .vDialogToolbarItem()
            }
            .errorAlert(message: $error)
            .task { await loadBudgets() }
        }
    }

    private var startSection: some View {
        Section {
            TextField(String(localized: "Shop name (optional)"), text: $sessionName, prompt: Text(String(localized: "Shop name (optional)")).foregroundStyle(VColors.placeholderText))
                .vFormField()
                .accessibilityIdentifier("shopping-mode-name-field")

            // Only offered when there is a budget to pick — an empty picker is
            // a control that does nothing.
            if !budgetOptions.isEmpty {
                Picker(String(localized: "Count against budget"), selection: $selectedBudgetID) {
                    Text(String(localized: "None")).tag(UUID?.none)
                    ForEach(budgetOptions) { option in
                        Text(option.name).tag(Optional(option.id))
                    }
                }
                .accessibilityIdentifier("shopping-mode-budget-picker")
            }

            Button {
                start()
            } label: {
                Label(String(localized: "Start Session"), systemImage: "cart.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(VColors.primary)
            .disabled(!controller.areActivitiesEnabled)
            .accessibilityIdentifier("shopping-mode-start-button")
        } footer: {
            Text(String(localized: "Your running total appears on the Lock Screen and in the Dynamic Island. Nothing is added to your transactions — record the purchase when you are done."))
        }
    }

    private var runningSection: some View {
        Section {
            HStack {
                Text(String(localized: "Running total"))
                Spacer()
                Text(runningTotal.formatted(.currency(code: currencyCode)))
                    .font(VTypography.bodyBold)
                    .monospacedDigit()
                    .accessibilityIdentifier("shopping-mode-total")
            }
            HStack {
                Text(String(localized: "Items"))
                Spacer()
                Text("\(itemCount)")
                    .foregroundStyle(VColors.textSecondary)
                    .monospacedDigit()
            }
            if let startingBudget {
                let left = startingBudget.remaining - runningTotal
                HStack {
                    Text(String(localized: "Budget left"))
                    Spacer()
                    Text(left.formatted(.currency(code: currencyCode)))
                        .font(VTypography.bodyBold)
                        .monospacedDigit()
                        .foregroundStyle(left < 0 ? VColors.expense : VColors.textPrimary)
                        .accessibilityIdentifier("shopping-mode-budget-left")
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(left < 0 ? String(localized: "Over budget") : "")
            }
            Button(role: .destructive) {
                Task {
                    await controller.endShoppingSession()
                    isRunning = false
                    runningTotal = 0
                    itemCount = 0
                    startingBudget = nil
                }
            } label: {
                Label(String(localized: "End Session"), systemImage: "stop.circle")
            }
            .accessibilityIdentifier("shopping-mode-end-button")
        }
    }

    private var addItemSection: some View {
        Section {
            HStack {
                TextField(String(localized: "Amount"), text: $amountText, prompt: Text(String(localized: "Amount")).foregroundStyle(VColors.placeholderText))
                    .vFormField()
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .accessibilityIdentifier("shopping-mode-amount-field")

                Button(String(localized: "Add")) {
                    addItem()
                }
                .buttonStyle(.bordered)
                .disabled(Decimal(localizedAmount: amountText) == nil)
            }
        } header: {
            VFormSectionHeader(String(localized: "Add Item"))
        }
    }

    private func start() {
        let budget = budgetOptions.first { $0.id == selectedBudgetID }
        let started = controller.startShoppingSession(
            name: sessionName,
            currencyCode: currencyCode,
            budgetName: budget?.name,
            budgetRemaining: budget?.remaining
        )
        guard started else {
            error = String(localized: "We couldn't start the Live Activity. Check that Live Activities are on for Vittora.")
            return
        }
        isRunning = true
        runningTotal = 0
        itemCount = 0
        startingBudget = budget
    }

    private func loadBudgets() async {
        do {
            let budgets = try await FetchBudgetsUseCase(
                budgetRepository: dependencies.budgetRepository,
                transactionRepository: dependencies.transactionRepository
            ).execute()
            let categories = try await dependencies.categoryRepository.fetchAll()
            budgetOptions = ShoppingBudgetOption.options(budgets: budgets, categories: categories)
        } catch {
            // Budgets are optional here; the session works without one.
            budgetOptions = []
        }
    }

    private func addItem() {
        guard let amount = Decimal(localizedAmount: amountText), amount > 0 else { return }
        // The screen mirrors what the activity will show rather than reading it
        // back, so the two cannot drift apart while the update is in flight.
        runningTotal += amount
        itemCount += 1
        amountText = ""
        Task { await controller.updateShoppingSession(addingAmount: amount) }
    }
}

/// A budget the shopping session can count against, with what is left in it now.
struct ShoppingBudgetOption: Identifiable, Equatable {
    let id: UUID
    let name: String
    let remaining: Decimal

    /// Named the way the Budgets screen names them: the category, or "Overall"
    /// for the budget with none. A budget whose category was deleted is left
    /// out — there is no name to show that the user would recognise.
    static func options(budgets: [BudgetEntity], categories: [CategoryEntity]) -> [ShoppingBudgetOption] {
        let names = Dictionary(categories.map { ($0.id, $0.displayName) }, uniquingKeysWith: { first, _ in first })
        return budgets.compactMap { budget -> ShoppingBudgetOption? in
            let name: String
            if let categoryID = budget.categoryID {
                guard let categoryName = names[categoryID] else { return nil }
                name = categoryName
            } else {
                name = String(localized: "Overall")
            }
            return ShoppingBudgetOption(id: budget.id, name: name, remaining: budget.remaining)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

#Preview {
    ShoppingModeView()
}
