import SwiftUI
import VittoraCore

struct NetWorthCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let netWorth: Decimal
    let totalAssets: Decimal
    let totalLiabilities: Decimal
    var currencyCode: String = CurrencyDefaults.code

    var body: some View {
        // White content on the brand-green fill.
        //
        // Owner decision (2026-08-08), superseding the dark-text choice of
        // 2026-08-03 after seeing both on device. This is a KNOWN contrast
        // miss, accepted deliberately: white on #3FCFA4 is 1.97:1, below the
        // 4.5:1 body minimum and below the 3:1 large-text bar.
        //
        // The owner was offered a darker fill that would let white pass AA and
        // declined it, to keep the accent swatch exact. Recorded here rather
        // than buried in the audit filter, because the audit exemption this
        // needs is anchored to `brand-green-filled-card` below — the numbers
        // stay reachable via VoiceOver through the card's accessibilityValue.
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
                    .background(VColors.onPrimary.opacity(0.35))
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
        .accessibilityIdentifier("brand-green-filled-card")
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
