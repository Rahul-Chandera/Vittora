import SwiftUI
import VittoraCore

struct NetWorthCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let netWorth: Decimal
    let totalAssets: Decimal
    let totalLiabilities: Decimal
    var currencyCode: String = CurrencyDefaults.code

    var body: some View {
        VCard(padding: VSpacing.lg, shadow: .medium, backgroundColor: VColors.primary) {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                Text(String(localized: "Net Worth"))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.onPrimary)

                Text(netWorth.formatted(.currency(code: currencyCode)))
                    .font(VTypography.amountLarge)
                    .amountScaling()
                    .foregroundStyle(VColors.onPrimary)

                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.vertical, VSpacing.xs)

                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: VSpacing.md))
                    : AnyLayout(HStackLayout())
                layout {
                    VStack(alignment: .leading, spacing: VSpacing.xxs) {
                        Text(String(localized: "Assets"))
                            .font(VTypography.caption2)
                            .foregroundStyle(VColors.onPrimary)
                        Text(totalAssets.formatted(.currency(code: currencyCode)))
                            .font(VTypography.caption1Bold)
                            .foregroundStyle(VColors.onPrimary)
                    }

                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer()
                    }

                    VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: VSpacing.xxs) {
                        Text(String(localized: "Liabilities"))
                            .font(VTypography.caption2)
                            .foregroundStyle(VColors.onPrimary)
                        Text(totalLiabilities.formatted(.currency(code: currencyCode)))
                            .font(VTypography.caption1Bold)
                            .foregroundStyle(VColors.onPrimary)
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
