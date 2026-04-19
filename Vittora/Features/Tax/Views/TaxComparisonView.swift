import SwiftUI

struct TaxComparisonView: View {
    let comparison: TaxComparison

    var body: some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                header

                ViewThatFits {
                    HStack(alignment: .top, spacing: VSpacing.md) {
                        optionCard(
                            estimate: comparison.firstEstimate,
                            title: firstTitle,
                            isRecommended: comparison.winner == .first
                        )
                        optionCard(
                            estimate: comparison.secondEstimate,
                            title: secondTitle,
                            isRecommended: comparison.winner == .second
                        )
                    }

                    VStack(spacing: VSpacing.md) {
                        optionCard(
                            estimate: comparison.firstEstimate,
                            title: firstTitle,
                            isRecommended: comparison.winner == .first
                        )
                        optionCard(
                            estimate: comparison.secondEstimate,
                            title: secondTitle,
                            isRecommended: comparison.winner == .second
                        )
                    }
                }

                recommendationBanner
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(VTypography.subheadline)
                .foregroundStyle(VColors.textPrimary)
            Text(subtitle)
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var recommendationBanner: some View {
        HStack(spacing: VSpacing.sm) {
            Image(systemName: comparison.winner == .tie ? "equal.circle.fill" : "sparkles")
                .foregroundStyle(comparison.winner == .tie ? VColors.textSecondary : VColors.primary)

            Text(recommendationText)
                .font(VTypography.caption1Bold)
                .foregroundStyle(VColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(VSpacing.md)
        .background(VColors.tertiaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Recommendation: \(recommendationText)"))
    }

    private func optionCard(
        estimate: TaxEstimate,
        title: String,
        isRecommended: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            HStack(alignment: .top, spacing: VSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VTypography.bodyBold)
                        .foregroundStyle(VColors.textPrimary)
                    Text(estimate.regimeLabel)
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isRecommended {
                    Text(String(localized: "Recommended"))
                        .font(VTypography.caption2Bold)
                        .foregroundStyle(VColors.primary)
                        .padding(.horizontal, VSpacing.sm)
                        .padding(.vertical, 6)
                        .background(VColors.primary.opacity(0.12))
                        .cornerRadius(999)
                }
            }

            Text(estimate.finalTax.formatted(.currency(code: estimate.country.currencyCode)))
                .font(VTypography.amountMedium)
                .foregroundStyle(isRecommended ? VColors.primary : VColors.expense)
                .adaptiveLineLimit(1)
                .minimumScaleFactor(0.8)

            VStack(spacing: VSpacing.xs) {
                metricRow(
                    title: String(localized: "Taxable Income"),
                    value: estimate.taxableIncome.formatted(.currency(code: estimate.country.currencyCode))
                )
                metricRow(
                    title: String(localized: "Deductions"),
                    value: estimate.totalDeductions.formatted(.currency(code: estimate.country.currencyCode))
                )
                metricRow(
                    title: String(localized: "Effective Rate"),
                    value: (estimate.effectiveRate * 100).formatted(.number.precision(.fractionLength(1))) + "%"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(VSpacing.cardPadding)
        .background(isRecommended ? VColors.primary.opacity(0.08) : VColors.tertiaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
        .overlay(
            RoundedRectangle(cornerRadius: VSpacing.cornerRadiusCard)
                .strokeBorder(isRecommended ? VColors.primary.opacity(0.25) : .clear, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isRecommended
                ? String(localized: "\(title), recommended. Tax: \(estimate.finalTax.formatted(.currency(code: estimate.country.currencyCode))). Effective rate \((estimate.effectiveRate * 100).formatted(.number.precision(.fractionLength(1))))%")
                : String(localized: "\(title). Tax: \(estimate.finalTax.formatted(.currency(code: estimate.country.currencyCode))). Effective rate \((estimate.effectiveRate * 100).formatted(.number.precision(.fractionLength(1))))%")
        )
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(VTypography.caption2)
                .foregroundStyle(VColors.textSecondary)
            Spacer()
            Text(value)
                .font(VTypography.caption1Bold)
                .foregroundStyle(VColors.textPrimary)
                .adaptiveLineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var title: String {
        switch comparison.kind {
        case .indiaRegimes:
            String(localized: "Regime Comparison")
        case .usDeductionModes:
            String(localized: "Deduction Comparison")
        }
    }

    private var subtitle: String {
        switch comparison.kind {
        case .indiaRegimes:
            String(localized: "See which Indian tax regime produces the lower estimate using the same income details.")
        case .usDeductionModes:
            String(localized: "Compare the standard deduction with your current itemized deductions for the same filing status.")
        }
    }

    private var firstTitle: String {
        switch comparison.kind {
        case .indiaRegimes:
            String(localized: "Old Regime")
        case .usDeductionModes:
            String(localized: "Standard Deduction")
        }
    }

    private var secondTitle: String {
        switch comparison.kind {
        case .indiaRegimes:
            String(localized: "New Regime")
        case .usDeductionModes:
            String(localized: "Itemized Deductions")
        }
    }

    private var recommendationText: String {
        let code = comparison.firstEstimate.country.currencyCode
        let formattedSavings = comparison.savingsAmount.formatted(.currency(code: code))

        switch comparison.winner {
        case .first:
            return String(localized: "\(firstTitle) currently saves about \(formattedSavings).")
        case .second:
            return String(localized: "\(secondTitle) currently saves about \(formattedSavings).")
        case .tie:
            return String(localized: "Both options currently estimate the same tax liability.")
        }
    }
}
