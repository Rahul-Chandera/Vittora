import SwiftUI

/// Compact tax overview card — shows gross income, deductions, taxable income, final tax and effective rate.
struct TaxSummaryCard: View {
    let estimate: TaxEstimate

    private var currencyCode: String { estimate.country.currencyCode }

    var body: some View {
        VCard {
            VStack(spacing: VSpacing.md) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Tax Estimate"))
                            .font(VTypography.subheadline)
                            .foregroundStyle(VColors.textSecondary)
                        Text(estimate.regimeLabel)
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.primary)
                    }
                    Spacer()
                    Image(systemName: "building.columns.fill")
                        .font(.title2)
                        .foregroundStyle(VColors.primary.opacity(0.7))
                        .accessibilityHidden(true)
                }

                Divider()

                // Final tax — hero number
                VStack(spacing: 4) {
                    Text(estimate.finalTax.formatted(.currency(code: currencyCode)))
                        .font(VTypography.amountLarge)
                        .foregroundStyle(VColors.expense)

                    HStack(spacing: VSpacing.xs) {
                        Text(String(localized: "Effective Rate"))
                            .font(VTypography.caption1)
                            .foregroundStyle(VColors.textSecondary)
                        Text((estimate.effectiveRate * 100).formatted(.number.precision(.fractionLength(1))) + "%")
                            .font(VTypography.caption1.bold())
                            .foregroundStyle(VColors.textPrimary)

                        if estimate.marginalRate > 0 {
                            Text("·")
                                .foregroundStyle(VColors.textSecondary)
                            Text(String(localized: "\(estimate.marginalRate.formatted(.number.precision(.fractionLength(0))))% Marginal"))
                                .font(VTypography.caption1)
                                .foregroundStyle(VColors.textSecondary)
                        }
                    }
                }

                Divider()

                // Key figures grid
                HStack(spacing: 0) {
                    TaxFigure(
                        label: String(localized: "Gross Income"),
                        value: estimate.grossIncome,
                        currencyCode: currencyCode,
                        color: VColors.income
                    )
                    Divider().frame(height: 36)
                    TaxFigure(
                        label: String(localized: "Deductions"),
                        value: estimate.totalDeductions,
                        currencyCode: currencyCode,
                        color: VColors.textSecondary
                    )
                    Divider().frame(height: 36)
                    TaxFigure(
                        label: String(localized: "Taxable"),
                        value: estimate.taxableIncome,
                        currencyCode: currencyCode,
                        color: VColors.textPrimary
                    )
                }
            }
        }
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
                .adaptiveLineLimit(1)
                .adaptiveMinimumScaleFactor(0.8)
            Text(label)
                .font(VTypography.caption2)
                .foregroundStyle(VColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func compact(_ amount: Decimal, code: String) -> String {
        let d = (amount as NSDecimalNumber).doubleValue
        let symbol = Locale.current.currencySymbol ?? "$"
        switch d {
        case 1_00_00_000...:  return "\(symbol)\(String(format: "%.1f", d / 1_00_00_000))Cr"
        case 1_00_000...:     return "\(symbol)\(String(format: "%.1f", d / 1_00_000))L"
        case 1_000...:        return "\(symbol)\(String(format: "%.1f", d / 1_000))K"
        default:              return amount.formatted(.currency(code: code))
        }
    }
}
