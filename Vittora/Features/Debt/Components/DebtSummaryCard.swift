import SwiftUI
import VittoraCore

struct DebtSummaryCard: View {
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let balance: DebtBalance

    var body: some View {
        VStack(spacing: VSpacing.md) {
            if dynamicTypeSize.isAccessibilitySize {
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
            } else {
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
            }

            Divider()

            HStack {
                Text(String(localized: "Net Position"))
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)
                Spacer()
                Text(CurrencyFormatter.format(balance.netBalance, currencyCode: currencyCode))
                    .font(VTypography.amountSmall)
                    .amountScaling()
                    .foregroundColor(balance.netBalance >= 0 ? VColors.income : VColors.expense)
            }
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Debt summary"))
        .accessibilityValue(
            String(
                localized: "\(CurrencyFormatter.format(balance.totalOwedToMe, currencyCode: currencyCode)) owed to you, \(CurrencyFormatter.format(balance.totalIOwe, currencyCode: currencyCode)) you owe, net position \(CurrencyFormatter.format(balance.netBalance, currencyCode: currencyCode))"
            )
        )
    }

    private func summaryColumn(title: String, amount: Decimal, color: Color, icon: String) -> some View {
        VStack(spacing: VSpacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .accessibilityHidden(true)
            Text(CurrencyFormatter.format(amount, currencyCode: currencyCode))
                .font(VTypography.amountMedium)
                .amountScaling()
                .foregroundColor(color)
            Text(title)
                .font(VTypography.caption2)
                .foregroundColor(VColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
