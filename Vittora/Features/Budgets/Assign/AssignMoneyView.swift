import SwiftUI
import VittoraCore

/// "Give every dollar a job": this month's income, spread across categories.
struct AssignMoneyView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var vm: AssignMoneyViewModel?
    @State private var drafts: [UUID: String] = [:]
    @FocusState private var focused: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if let plan = vm?.plan {
                    content(plan)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(String(localized: "Assign Money"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        commitFocused()
                        dismiss()
                    }
                }
            }
        }
        .task {
            if vm == nil {
                vm = AssignMoneyViewModel(
                    reportingTransactions: dependencies.reportingTransactionRepository,
                    budgetRepository: dependencies.budgetRepository,
                    categoryRepository: dependencies.categoryRepository
                )
            }
            await reload()
        }
        .onChange(of: focused) { previous, _ in
            if let previous { commit(previous) }
        }
        .errorAlert(message: Binding(get: { vm?.error }, set: { vm?.error = $0 }))
    }

    private func content(_ plan: AssignMoneyPlan) -> some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Ready to assign"))
                        .font(VTypography.subheadline)
                        .foregroundStyle(VColors.textSecondary)
                    Text(money(plan.readyToAssign))
                        .font(VTypography.amountLarge)
                        .foregroundStyle(plan.readyToAssign < 0 ? VColors.expense : VColors.income)
                        .accessibilityIdentifier("assign-money-ready")
                    Text(String(localized: "Income this month \(money(plan.income)) · Assigned \(money(plan.assigned))"))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                    if plan.readyToAssign < 0 {
                        Text(String(localized: "You've assigned \(money(-plan.readyToAssign)) more than you've received this month."))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.expense)
                    }
                }
                .accessibilityElement(children: .combine)
            } footer: {
                Text(String(localized: "Give every dollar of this month's income a job. Each amount is that category's monthly budget, and anything unspent carries into next month."))
            }

            Section(header: VFormSectionHeader(String(localized: "Categories"))) {
                ForEach(plan.rows) { row in
                    rowView(row)
                }
            }
        }
    }

    private func rowView(_ row: AssignMoneyPlan.Row) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: row.icon)
                    .foregroundStyle(VColors.primaryOnSurface)
                    .accessibilityHidden(true)
                Text(row.name)
                Spacer()
                if let other = row.otherPeriod {
                    Text(other.displayName)
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                } else {
                    TextField(money(0), text: Binding(
                        get: { drafts[row.categoryID] ?? "" },
                        set: { drafts[row.categoryID] = $0 }
                    ))
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                    .focused($focused, equals: row.categoryID)
                    .onSubmit { commit(row.categoryID) }
                    .accessibilityLabel(String(localized: "Amount for \(row.name)"))
                }
            }
            Text(String(localized: "Spent \(money(row.spent)) · Available \(money(row.available))"))
                .font(VTypography.caption1)
                .foregroundStyle(row.available < 0 ? VColors.expense : VColors.textSecondary)
        }
    }

    private func money(_ value: Decimal) -> String {
        CurrencyFormatter.format(value, currencyCode: currencyCode)
    }

    private func reload() async {
        await vm?.load()
        drafts = Dictionary(uniqueKeysWithValues: (vm?.plan?.rows ?? []).compactMap { row in
            row.assigned > 0 ? (row.categoryID, NSDecimalNumber(decimal: row.assigned).stringValue) : nil
        })
    }

    private func commitFocused() {
        if let focused { commit(focused) }
    }

    private func commit(_ categoryID: UUID) {
        guard let text = drafts[categoryID]?.replacingOccurrences(of: ",", with: ""),
              let amount = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), amount > 0
        else { return }
        Task {
            await vm?.assign(amount, to: categoryID)
            appState.notifyChanged(.budgets)
        }
    }
}
