import SwiftUI

struct PayeeAnalyticsCard: View {
    let analytics: PayeeAnalytics
    var currencyCode: String = "USD"

    var body: some View {
        VCard(padding: VSpacing.lg) {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text("Spending Summary")
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)
                    .textCase(.uppercase)

                HStack(spacing: VSpacing.xl) {
                    statItem(
                        value: analytics.totalSpent.formatted(.currency(code: currencyCode)),
                        label: "Total Spent"
                    )
                    Divider()
                        .frame(height: 40)
                    statItem(
                        value: "\(analytics.transactionCount)",
                        label: "Transactions"
                    )
                    Divider()
                        .frame(height: 40)
                    statItem(
                        value: analytics.averageAmount.formatted(.currency(code: currencyCode)),
                        label: "Average"
                    )
                }

                if let lastDate = analytics.lastTransactionDate {
                    Divider()
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(VColors.textTertiary)
                        Text("Last transaction: \(lastDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(VTypography.caption1)
                            .foregroundColor(VColors.textSecondary)
                    }
                }
            }
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.xxs) {
            Text(value)
                .font(VTypography.bodyBold)
                .foregroundColor(VColors.textPrimary)
            Text(label)
                .font(VTypography.caption2)
                .foregroundColor(VColors.textSecondary)
        }
    }
}

#Preview {
    PayeeAnalyticsCard(analytics: PayeeAnalytics(
        payeeID: UUID(),
        totalSpent: 1_240.50,
        transactionCount: 8,
        averageAmount: 155.06,
        lastTransactionDate: .now
    ))
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}
