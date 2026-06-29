import SwiftUI
import VittoraCore

// MARK: - Monthly / annual

struct MonthlyReportExportDocument: View {
    let reportTitle: String
    let subtitle: String
    let monthlyData: [MonthlyData]
    let currencyCode: String
    let totalIncome: Decimal
    let totalExpense: Decimal
    let netSavings: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            summaryGrid
            Divider()
            breakdownSection
            footer
        }
        .foregroundStyle(Color.black)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vittora")
                .font(.caption)
                .foregroundStyle(Color.gray)
            Text(reportTitle)
                .font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.gray)
        }
    }

    private var summaryGrid: some View {
        HStack(spacing: 16) {
            summaryCell(
                title: String(localized: "Income"),
                amount: totalIncome,
                tint: Color(red: 0.1, green: 0.55, blue: 0.25)
            )
            summaryCell(
                title: String(localized: "Expenses"),
                amount: totalExpense,
                tint: Color(red: 0.85, green: 0.2, blue: 0.2)
            )
            summaryCell(
                title: String(localized: "Net"),
                amount: netSavings,
                tint: netSavings >= 0
                    ? Color(red: 0.1, green: 0.55, blue: 0.25)
                    : Color(red: 0.85, green: 0.2, blue: 0.2)
            )
        }
    }

    private func summaryCell(title: String, amount: Decimal, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.gray)
            Text(CurrencyFormatter.format(amount, currencyCode: currencyCode))
                .font(.headline)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(white: 0.96))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Monthly Breakdown"))
                .font(.headline)

            HStack {
                Text(String(localized: "Month"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(String(localized: "Income"))
                    .frame(width: 88, alignment: .trailing)
                Text(String(localized: "Expense"))
                    .frame(width: 88, alignment: .trailing)
                Text(String(localized: "Net"))
                    .frame(width: 88, alignment: .trailing)
            }
            .font(.caption.bold())
            .foregroundStyle(Color.gray)

            ForEach(monthlyData.reversed()) { item in
                HStack {
                    Text(item.month.formatted(.dateTime.year().month(.wide)))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(CurrencyFormatter.format(item.income, currencyCode: currencyCode))
                        .frame(width: 88, alignment: .trailing)
                    Text(CurrencyFormatter.format(item.expense, currencyCode: currencyCode))
                        .frame(width: 88, alignment: .trailing)
                    Text(CurrencyFormatter.format(item.net, currencyCode: currencyCode))
                        .frame(width: 88, alignment: .trailing)
                }
                .font(.caption)
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
}

// MARK: - Custom

struct CustomReportExportDocument: View {
    let result: CustomReportResult
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Vittora")
                    .font(.caption)
                    .foregroundStyle(Color.gray)
                Text(String(localized: "Custom Report"))
                    .font(.title2.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.gray)
            }

            HStack {
                Text(String(localized: "Total"))
                    .font(.headline)
                Spacer()
                Text(CurrencyFormatter.format(result.total, currencyCode: currencyCode))
                    .font(.headline)
            }
            .padding(12)
            .background(Color(white: 0.96))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Breakdown"))
                    .font(.headline)

                ForEach(result.rows) { row in
                    HStack(alignment: .top) {
                        Text(row.label)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(CurrencyFormatter.format(row.amount, currencyCode: currencyCode))
                            Text(
                                String(
                                    localized: "\(row.percentage, format: .number.precision(.fractionLength(1)))% · \(row.count) transactions"
                                )
                            )
                                .font(.caption2)
                                .foregroundStyle(Color.gray)
                        }
                    }
                    .font(.caption)
                }
            }

            Text(
                String(
                    localized: "Generated \(Date.now.formatted(date: .abbreviated, time: .shortened))"
                )
            )
            .font(.caption2)
            .foregroundStyle(Color.gray)
        }
        .foregroundStyle(Color.black)
    }

    private var subtitle: String {
        var parts: [String] = [result.grouping.displayName]
        if let type = result.transactionType {
            parts.append(type == .income ? String(localized: "Income") : String(localized: "Expenses"))
        }
        if let range = result.dateRange {
            let start = range.lowerBound.formatted(date: .abbreviated, time: .omitted)
            let end = range.upperBound.formatted(date: .abbreviated, time: .omitted)
            parts.append("\(start) – \(end)")
        }
        return parts.joined(separator: " · ")
    }
}
