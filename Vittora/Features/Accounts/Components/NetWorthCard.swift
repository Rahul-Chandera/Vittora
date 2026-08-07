import SwiftUI
import VittoraCore

struct NetWorthCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let netWorth: Decimal
    let totalAssets: Decimal
    let totalLiabilities: Decimal
    var currencyCode: String = CurrencyDefaults.code

    var body: some View {
        // Dark content on the brand-green fill, not white.
        //
        // Owner decision (2026-08-03) after comparing rendered options. White on
        // #3FCFA4 is 1.97:1 — below the 4.5:1 body minimum AND below the 3:1
        // large-text bar — and this card carries the net-worth figure, which is
        // the number the app exists to show. DEC-012 accepts that pairing for
        // CTA labels and the FAB; a data surface is a different case.
        //
        // textPrimary on the same fill measures ~9:1 and keeps the brand colour
        // exactly, which the alternative (darkening the fill to primaryOnSurface)
        // would not.
        VCard(padding: VSpacing.lg, shadow: .medium, backgroundColor: VColors.primary) {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                Text(String(localized: "Net Worth"))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textPrimary)

                Text(netWorth.formatted(.currency(code: currencyCode)))
                    .font(VTypography.amountLarge)
                    .amountScaling()
                    .foregroundStyle(VColors.textPrimary)

                Divider()
                    .background(VColors.textPrimary.opacity(0.22))
                    .padding(.vertical, VSpacing.xs)

                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: VSpacing.md))
                    : AnyLayout(HStackLayout())
                layout {
                    VStack(alignment: .leading, spacing: VSpacing.xxs) {
                        Text(String(localized: "Assets"))
                            .font(VTypography.caption2)
                            .foregroundStyle(VColors.textPrimary)
                        Text(totalAssets.formatted(.currency(code: currencyCode)))
                            .font(VTypography.caption1Bold)
                            .foregroundStyle(VColors.textPrimary)
                    }

                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer()
                    }

                    VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: VSpacing.xxs) {
                        Text(String(localized: "Liabilities"))
                            .font(VTypography.caption2)
                            .foregroundStyle(VColors.textPrimary)
                        Text(totalLiabilities.formatted(.currency(code: currencyCode)))
                            .font(VTypography.caption1Bold)
                            .foregroundStyle(VColors.textPrimary)
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
