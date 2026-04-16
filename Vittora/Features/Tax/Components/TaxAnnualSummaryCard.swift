import SwiftUI

struct TaxAnnualSummaryCard: View {
    let summary: TaxSummary
    let country: TaxCountry

    private var currencyCode: String { country.currencyCode }

    var body: some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                header
                metricRow
                Divider()
                breakdownSection
                if !summary.taxRelevantCategories.isEmpty {
                    Divider()
                    matchedCategoriesSection
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: VSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Tax-Related Activity"))
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)
                Text(summary.financialYear)
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.primary)
                Text(dateRangeLabel)
                    .font(VTypography.caption2)
                    .foregroundStyle(VColors.textTertiary)
            }
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title3)
                .foregroundStyle(VColors.primary)
        }
    }

    private var metricRow: some View {
        HStack(spacing: VSpacing.md) {
            SummaryMetric(
                label: String(localized: "Potentially Relevant"),
                value: summary.totalRelevantAmount.formatted(.currency(code: currencyCode)),
                color: VColors.primary
            )
            SummaryMetric(
                label: String(localized: "Transactions"),
                value: summary.transactionCount.formatted(),
                color: VColors.textPrimary
            )
            SummaryMetric(
                label: String(localized: "Matched Categories"),
                value: summary.matchedCategoryCount.formatted(),
                color: VColors.income
            )
        }
    }

    @ViewBuilder
    private var breakdownSection: some View {
        if summary.categoryBreakdown.isEmpty {
            Text(String(localized: "No tax-relevant transactions were found for this year."))
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
        } else {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                Text(String(localized: "Top Categories"))
                    .font(VTypography.caption1.bold())
                    .foregroundStyle(VColors.textPrimary)

                ForEach(summary.categoryBreakdown.prefix(4)) { item in
                    HStack(spacing: VSpacing.md) {
                        Circle()
                            .fill(Color(hex: item.category.colorHex) ?? VColors.primary)
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.category.name)
                                .font(VTypography.body)
                                .foregroundStyle(VColors.textPrimary)
                            Text(
                                String(
                                    localized: "\(item.transactionCount.formatted()) transaction(s)"
                                )
                            )
                            .font(VTypography.caption2)
                            .foregroundStyle(VColors.textSecondary)
                        }

                        Spacer()

                        Text(item.totalAmount.formatted(.currency(code: currencyCode)))
                            .font(VTypography.bodyBold)
                            .foregroundStyle(VColors.textPrimary)
                    }
                }
            }
        }
    }

    private var matchedCategoriesSection: some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            Text(String(localized: "Watching Categories"))
                .font(VTypography.caption1.bold())
                .foregroundStyle(VColors.textPrimary)

            Text(
                summary.taxRelevantCategories
                    .prefix(6)
                    .map(\.name)
                    .joined(separator: ", ")
            )
            .font(VTypography.caption1)
            .foregroundStyle(VColors.textSecondary)
        }
    }

    private var dateRangeLabel: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: summary.dateRange.lowerBound, to: summary.dateRange.upperBound)
    }
}

private struct SummaryMetric: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(VTypography.bodyBold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(label)
                .font(VTypography.caption2)
                .foregroundStyle(VColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
