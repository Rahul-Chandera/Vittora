import SwiftUI

/// Full bracket-by-bracket tax breakdown sheet.
struct TaxBreakdownView: View {
    let estimate: TaxEstimate
    @Environment(\.dismiss) private var dismiss

    private var currencyCode: String { estimate.country.currencyCode }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VSpacing.sectionSpacing) {
                    TaxBracketBarView(estimate: estimate)
                        .padding(VSpacing.cardPadding)
                        .background(VColors.secondaryBackground)
                        .cornerRadius(VSpacing.cornerRadiusCard)

                    bracketSection
                    adjustmentsSection
                    finalSection
                }
                .padding(VSpacing.screenPadding)
            }
            .background(VColors.background)
            .navigationTitle(String(localized: "Tax Breakdown"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var bracketSection: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text(String(localized: "Tax by Bracket"))
                .font(VTypography.subheadline)
                .foregroundStyle(VColors.textSecondary)

            VStack(spacing: 0) {
                BreakdownRow(
                    label: String(localized: "Gross Income"),
                    value: estimate.grossIncome,
                    currencyCode: currencyCode,
                    style: .neutral
                )
                Divider().padding(.leading, VSpacing.md)
                BreakdownRow(
                    label: String(localized: "Standard Deduction"),
                    value: -estimate.standardDeduction,
                    currencyCode: currencyCode,
                    style: .reduction
                )
                if estimate.customDeductionsTotal > 0 {
                    Divider().padding(.leading, VSpacing.md)
                    BreakdownRow(
                        label: String(localized: "Other Deductions"),
                        value: -estimate.customDeductionsTotal,
                        currencyCode: currencyCode,
                        style: .reduction
                    )
                }
                Divider().padding(.leading, VSpacing.md)
                BreakdownRow(
                    label: String(localized: "Taxable Income"),
                    value: estimate.taxableIncome,
                    currencyCode: currencyCode,
                    style: .neutral,
                    isBold: true
                )
            }
            .background(VColors.secondaryBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)

            // Per-bracket rows
            VStack(spacing: 0) {
                ForEach(estimate.bracketResults) { result in
                    BracketRow(result: result, currencyCode: currencyCode)
                    if result.id != estimate.bracketResults.last?.id {
                        Divider().padding(.leading, VSpacing.md)
                    }
                }
            }
            .background(VColors.secondaryBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
        }
    }

    @ViewBuilder
    private var adjustmentsSection: some View {
        let hasAdjustments = estimate.rebate > 0 || estimate.surcharge > 0 || estimate.cess > 0
        if hasAdjustments {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(String(localized: "Adjustments"))
                    .font(VTypography.subheadline)
                    .foregroundStyle(VColors.textSecondary)

                VStack(spacing: 0) {
                    BreakdownRow(
                        label: String(localized: "Basic Tax"),
                        value: estimate.basicTax,
                        currencyCode: currencyCode,
                        style: .tax
                    )
                    if estimate.rebate > 0 {
                        Divider().padding(.leading, VSpacing.md)
                        BreakdownRow(
                            label: String(localized: "Rebate (Sec 87A)"),
                            value: -estimate.rebate,
                            currencyCode: currencyCode,
                            style: .reduction
                        )
                    }
                    if estimate.surcharge > 0 {
                        Divider().padding(.leading, VSpacing.md)
                        BreakdownRow(
                            label: String(localized: "Surcharge"),
                            value: estimate.surcharge,
                            currencyCode: currencyCode,
                            style: .tax
                        )
                    }
                    if estimate.cess > 0 {
                        Divider().padding(.leading, VSpacing.md)
                        BreakdownRow(
                            label: String(localized: "Health & Education Cess (4%)"),
                            value: estimate.cess,
                            currencyCode: currencyCode,
                            style: .tax
                        )
                    }
                }
                .background(VColors.secondaryBackground)
                .cornerRadius(VSpacing.cornerRadiusCard)
            }
        }
    }

    private var finalSection: some View {
        VStack(spacing: 0) {
            BreakdownRow(
                label: String(localized: "Total Tax Payable"),
                value: estimate.finalTax,
                currencyCode: currencyCode,
                style: .tax,
                isBold: true
            )
        }
        .background(VColors.expense.opacity(0.08))
        .cornerRadius(VSpacing.cornerRadiusCard)
        .overlay(
            RoundedRectangle(cornerRadius: VSpacing.cornerRadiusCard)
                .strokeBorder(VColors.expense.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Row Sub-views

private enum RowStyle { case neutral, reduction, tax }

private struct BreakdownRow: View {
    let label: String
    let value: Decimal
    let currencyCode: String
    let style: RowStyle
    var isBold = false

    private var color: Color {
        switch style {
        case .neutral:   return VColors.textPrimary
        case .reduction: return VColors.income
        case .tax:       return VColors.expense
        }
    }

    var body: some View {
        HStack {
            Text(label)
                .font(isBold ? VTypography.bodyBold : VTypography.body)
                .foregroundStyle(VColors.textPrimary)
            Spacer()
            Text((style == .reduction ? "" : "") + value.formatted(.currency(code: currencyCode)))
                .font(isBold ? VTypography.bodyBold : VTypography.body)
                .foregroundStyle(color)
        }
        .padding(VSpacing.cardPadding)
    }
}

private struct BracketRow: View {
    let result: TaxBracketResult
    let currencyCode: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.label)
                    .font(VTypography.body)
                    .foregroundStyle(VColors.textPrimary)
                Text(String(localized: "@ \(result.ratePercent.formatted(.number.precision(.fractionLength(0))))%"))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(result.taxAmount.formatted(.currency(code: currencyCode)))
                    .font(VTypography.bodyBold)
                    .foregroundStyle(VColors.expense)
                Text(String(localized: "on \(result.taxableAmount.formatted(.currency(code: currencyCode)))"))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
            }
        }
        .padding(VSpacing.cardPadding)
    }
}
