import SwiftUI

struct DebtSummaryCard: View {
    let balance: DebtBalance

    var body: some View {
        VStack(spacing: VSpacing.md) {
            HStack(spacing: VSpacing.xl) {
                summaryColumn(
                    title: String(localized: "Owed to You"),
                    amount: balance.totalOwedToMe,
                    color: VColors.income,
                    icon: "arrow.down.circle.fill"
                )

                Divider()

                summaryColumn(
                    title: String(localized: "You Owe"),
                    amount: balance.totalIOwe,
                    color: VColors.expense,
                    icon: "arrow.up.circle.fill"
                )
            }

            Divider()

            HStack {
                Text(String(localized: "Net Position"))
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)
                Spacer()
                Text(formattedAmount(balance.netBalance))
                    .font(VTypography.amountSmall)
                    .foregroundColor(balance.netBalance >= 0 ? VColors.income : VColors.expense)
            }
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
    }

    private func summaryColumn(title: String, amount: Decimal, color: Color, icon: String) -> some View {
        VStack(spacing: VSpacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(formattedAmount(amount))
                .font(VTypography.amountMedium)
                .foregroundColor(color)
            Text(title)
                .font(VTypography.caption2)
                .foregroundColor(VColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formattedAmount(_ amount: Decimal) -> String {
        amount.formatted(currencyCode: "USD")
    }
}
