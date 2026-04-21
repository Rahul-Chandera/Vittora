import SwiftUI

struct NetWorthCard: View {
    let netWorth: Decimal
    let totalAssets: Decimal
    let totalLiabilities: Decimal
    var currencyCode: String = CurrencyDefaults.code

    var body: some View {
        VCard(padding: VSpacing.lg, shadow: .medium, backgroundColor: VColors.primary) {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                Text(String(localized: "Net Worth"))
                    .font(VTypography.caption1)
                    .foregroundColor(.white.opacity(0.8))

                Text(netWorth.formatted(.currency(code: currencyCode)))
                    .font(VTypography.amountLarge)
                    .foregroundColor(.white)

                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.vertical, VSpacing.xs)

                HStack {
                    VStack(alignment: .leading, spacing: VSpacing.xxs) {
                        Text(String(localized: "Assets"))
                            .font(VTypography.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        Text(totalAssets.formatted(.currency(code: currencyCode)))
                            .font(VTypography.caption1Bold)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: VSpacing.xxs) {
                        Text(String(localized: "Liabilities"))
                            .font(VTypography.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        Text(totalLiabilities.formatted(.currency(code: currencyCode)))
                            .font(VTypography.caption1Bold)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Net worth summary"))
        .accessibilityValue(
            String(
                localized: "Net worth \(netWorth.formatted(.currency(code: currencyCode))), assets \(totalAssets.formatted(.currency(code: currencyCode))), liabilities \(totalLiabilities.formatted(.currency(code: currencyCode)))"
            )
        )
    }
}

#Preview {
    NetWorthCard(
        netWorth: 24_350.00,
        totalAssets: 28_000.00,
        totalLiabilities: 3_650.00
    )
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}
