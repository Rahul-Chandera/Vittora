import SwiftUI
import VittoraCore

/// Compact tax overview card — shows gross income, deductions, taxable income, final tax and effective rate.
struct TaxSummaryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let estimate: TaxEstimate

    private var currencyCode: String { estimate.country.currencyCode }
    private var accessibilitySummary: String {
        String(
            localized: "Estimated tax \(estimate.finalTax.formatted(.currency(code: currencyCode))). Effective rate \((estimate.effectiveRate * 100).formatted(.number.precision(.fractionLength(1)))) percent. Gross income \(estimate.grossIncome.formatted(.currency(code: currencyCode))). Deductions \(estimate.totalDeductions.formatted(.currency(code: currencyCode))). Taxable income \(estimate.taxableIncome.formatted(.currency(code: currencyCode)))."
        )
    }

    var body: some View {
        VCard {
            VStack(spacing: VSpacing.md) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Tax Estimate"))
                            .font(VTypography.subheadline)
                            .foregroundStyle(VColors.textPrimary)
                        Text(estimate.regimeLabel)
                            .font(VTypography.body)
                            .foregroundStyle(VColors.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "building.columns.fill")
                        .font(.title2)
                        .foregroundStyle(VColors.primary)
                        .accessibilityHidden(true)
                }

                Divider()

                if estimate.country == .unitedStates {
                    USTaxFederalEstimateLabel()
                }

                // Final tax — hero number
                VStack(spacing: 4) {
                    Text(estimate.finalTax.formatted(.currency(code: currencyCode)))
                        .font(VTypography.amountLarge)
                        .amountScaling()
                        .foregroundStyle(VColors.textPrimary)

                    let rateLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: VSpacing.xxs))
                        : AnyLayout(HStackLayout(spacing: VSpacing.xs))
                    rateLayout {
                        Text(String(localized: "Effective Rate"))
                            .font(VTypography.bodyBold)
                            .foregroundStyle(VColors.textPrimary)
                        Text((estimate.effectiveRate * 100).formatted(.number.precision(.fractionLength(1))) + "%")
                            .font(VTypography.bodyBold)
                            .foregroundStyle(VColors.textPrimary)

                        if estimate.marginalRate > 0 {
                            if !dynamicTypeSize.isAccessibilitySize {
                                Text("·")
                                    .foregroundStyle(VColors.textPrimary)
                            }
                            Text(String(localized: "\(estimate.marginalRate.formatted(.number.precision(.fractionLength(0))))% Marginal"))
                                .font(VTypography.body)
                                .foregroundStyle(VColors.textPrimary)
                        }
                    }
                }

                Divider()

                // Key figures grid
                let figureLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: VSpacing.md))
                    : AnyLayout(HStackLayout(spacing: 0))
                figureLayout {
                    TaxFigure(
                        label: String(localized: "Gross Income"),
                        value: estimate.grossIncome,
                        currencyCode: currencyCode,
                        color: VColors.textPrimary
                    )
                    Divider()
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : 36)
                    TaxFigure(
                        label: String(localized: "Deductions"),
                        value: estimate.totalDeductions,
                        currencyCode: currencyCode,
                        color: VColors.textPrimary
                    )
                    Divider()
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : 36)
                    TaxFigure(
                        label: String(localized: "Taxable"),
                        value: estimate.taxableIncome,
                        currencyCode: currencyCode,
                        color: VColors.textPrimary
                    )
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Tax estimate"))
        .accessibilityValue(accessibilitySummary)
    }
}

// MARK: - Sub-views

private struct TaxFigure: View {
    let label: String
    let value: Decimal
    let currencyCode: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(compact(value, code: currencyCode))
                .font(VTypography.bodyBold)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
            Text(label)
                .font(VTypography.body)
                .foregroundStyle(VColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value.formatted(.currency(code: currencyCode)))
    }

    private func compact(_ amount: Decimal, code: String) -> String {
        let d = (amount as NSDecimalNumber).doubleValue
        let symbol = String.currencySymbol(for: code)
        switch d {
        case 1_00_00_000...:  return "\(symbol)\(String(format: "%.1f", d / 1_00_00_000))Cr"
        case 1_00_000...:     return "\(symbol)\(String(format: "%.1f", d / 1_00_000))L"
        case 1_000...:        return "\(symbol)\(String(format: "%.1f", d / 1_000))K"
        default:              return amount.formatted(.currency(code: code))
        }
    }
}
