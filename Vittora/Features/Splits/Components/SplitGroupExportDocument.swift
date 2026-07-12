import SwiftUI
import VittoraCore

/// Printable split-group summary for PDF export (K3).
struct SplitGroupExportDocument: View {
    let groupName: String
    let memberNames: [UUID: String]
    let memberIDs: [UUID]
    let balances: [MemberBalance]
    let outstandingExpenses: [GroupExpense]
    let settledExpenses: [GroupExpense]
    let currencyCode: String

    private var totalTracked: Decimal {
        (outstandingExpenses + settledExpenses).reduce(Decimal(0)) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            membersSection
            balancesSection
            if !outstandingExpenses.isEmpty {
                expensesSection(
                    title: String(localized: "Outstanding Expenses"),
                    expenses: outstandingExpenses
                )
            }
            if !settledExpenses.isEmpty {
                expensesSection(
                    title: String(localized: "Settled Expenses"),
                    expenses: settledExpenses
                )
            }
            footer
        }
        .foregroundStyle(Color.black)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vittora")
                .font(.caption)
                .foregroundStyle(Color.gray)
            Text(String(localized: "Split Group Report"))
                .font(.title2.bold())
            Text(groupName)
                .font(.subheadline)
                .foregroundStyle(Color.gray)
            Text(
                String(
                    localized: "Total tracked: \(CurrencyFormatter.format(totalTracked, currencyCode: currencyCode))"
                )
            )
            .font(.caption)
            .foregroundStyle(Color.gray)
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Members"))
                .font(.headline)
            Text(
                memberIDs
                    .map { memberNames[$0] ?? String(localized: "Unknown") }
                    .joined(separator: ", ")
            )
            .font(.caption)
        }
    }

    private var balancesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Settle Up"))
                .font(.headline)

            if balances.isEmpty {
                Text(String(localized: "All settled up!"))
                    .font(.caption)
                    .foregroundStyle(Color.gray)
            } else {
                ForEach(Array(balances.enumerated()), id: \.offset) { _, balance in
                    HStack {
                        Text(
                            String(
                                localized:
                                "\(name(for: balance.fromMemberID)) → \(name(for: balance.toMemberID))"
                            )
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(CurrencyFormatter.format(balance.amount, currencyCode: currencyCode))
                            .frame(width: 96, alignment: .trailing)
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func expensesSection(title: String, expenses: [GroupExpense]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ForEach(expenses) { expense in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(expense.title)
                        Text(
                            String(
                                localized: "Paid by \(name(for: expense.paidByMemberID)) · \(expense.date.formatted(date: .abbreviated, time: .omitted))"
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(Color.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(CurrencyFormatter.format(expense.amount, currencyCode: currencyCode))
                        .font(.caption)
                }
            }
        }
    }

    private var footer: some View {
        Text(
            String(
                localized: "Generated \(Date.now.formatted(date: .abbreviated, time: .shortened))"
            )
        )
        .font(.caption2)
        .foregroundStyle(Color.gray)
        .padding(.top, 8)
    }

    private func name(for memberID: UUID) -> String {
        memberNames[memberID] ?? String(localized: "Unknown")
    }
}
