import SwiftUI
import VittoraCore

struct NetWorthCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Totals per currency. There is no cross-currency figure to show because
    /// the app holds no exchange rates — see NetWorthSummary.
    let summary: NetWorthSummary
    /// Used only when there are no accounts yet, so the zero has a currency.
    var currencyCode: String = CurrencyDefaults.code

    private var entries: [NetWorthSummary.CurrencyTotals] {
        summary.byCurrency.isEmpty
            ? [NetWorthSummary.CurrencyTotals(currencyCode: currencyCode, assets: 0, liabilities: 0)]
            : summary.byCurrency
    }

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

                ForEach(Array(entries.enumerated()), id: \.element.id) { index, totals in
                    if index > 0 {
                        Divider()
                            .background(VColors.onPrimary.opacity(0.35))
                            .padding(.vertical, VSpacing.xs)
                    }
                    currencyBlock(totals, showsCode: summary.isMultiCurrency)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("brand-green-filled-card")
        .accessibilityLabel(String(localized: "Net worth summary"))
        .accessibilityValue(accessibilitySummary)
    }

    @ViewBuilder
    private func currencyBlock(
        _ totals: NetWorthSummary.CurrencyTotals,
        showsCode: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            // The code is only worth the space when there is more than one
            // subtotal to tell apart; the symbol carries it otherwise.
            if showsCode {
                Text(totals.currencyCode)
                    .font(VTypography.caption2)
                    .foregroundStyle(VColors.onPrimary)
            }

            Text(totals.netWorth.formatted(.currency(code: totals.currencyCode)))
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
                    Text(totals.assets.formatted(.currency(code: totals.currencyCode)))
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
                    Text(totals.liabilities.formatted(.currency(code: totals.currencyCode)))
                        .font(VTypography.caption1Bold)
                        .foregroundStyle(VColors.onPrimary)
                }
            }
        }
    }

    private var accessibilitySummary: String {
        var parts: [String] = []
        for totals in entries {
            let net = totals.netWorth.formatted(.currency(code: totals.currencyCode))
            let assets = totals.assets.formatted(.currency(code: totals.currencyCode))
            let liabilities = totals.liabilities.formatted(.currency(code: totals.currencyCode))
            parts.append(
                String(localized: "Net worth \(net), assets \(assets), liabilities \(liabilities)")
            )
        }
        return parts.joined(separator: ". ")
    }
}

#Preview {
    VStack(spacing: VSpacing.lg) {
        NetWorthCard(
            summary: NetWorthSummary(byCurrency: [
                .init(currencyCode: "USD", assets: 28_000, liabilities: 3_650)
            ])
        )
        NetWorthCard(
            summary: NetWorthSummary(byCurrency: [
                .init(currencyCode: "INR", assets: 7_215_490, liabilities: 0),
                .init(currencyCode: "USD", assets: 28_000, liabilities: 3_650)
            ])
        )
    }
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}
