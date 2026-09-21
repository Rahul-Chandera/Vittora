import SwiftUI
import VittoraCore

/// Compare the Section 80C options named in the plan (M2.4.1) and model splitting the
/// remaining limit across them (M2.4.2).
///
/// Educational and scenario-based per Module 2.4's scope note. Vittora states what is
/// statutory — lock-in, section, backing, how maturity is taxed — and the user supplies
/// every rate. Nothing here recommends an instrument or an amount.
struct Tax80CComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let profile: TaxProfile

    @State private var amountText: [String: String] = [:]
    @State private var rateText: [String: String] = [:]
    @State private var yearsText: [String: String] = [:]

    private let savingUseCase = EstimateTaxSavingUseCase()

    private var currencyCode: String { profile.country.currencyCode }

    private var deductionResult: IndiaSectionDeductionEngine.Result {
        IndiaSectionDeductionEngine.resolve(
            deductions: profile.customDeductions,
            advancedInputs: profile.advancedInputs,
            dateOfBirth: profile.dateOfBirth,
            financialYearLabel: profile.financialYear
        )
    }

    private var remaining80C: Decimal {
        IndiaSectionDeductionEngine.remaining80C(in: deductionResult)
    }

    private var remaining80CCD1B: Decimal {
        IndiaSectionDeductionEngine.remaining80CCD1B(in: deductionResult)
    }

    private func amount(for instrument: India80CInstrument) -> Decimal {
        max(0, Decimal(localizedAmount: amountText[instrument.id] ?? "") ?? 0)
    }

    /// Allocations aggregated by the section they count against.
    ///
    /// Load-bearing: ELSS, PPF and NPS all draw on the same ₹1.5L 80C limit, so their
    /// savings are not additive. Summing a per-instrument figure would tell a user
    /// splitting ₹1.5L three ways that they save three times over.
    private var allocationBySection: [String: Decimal] {
        India80CInstrumentTable.all.reduce(into: [:]) { totals, instrument in
            let value = amount(for: instrument)
            guard value > 0, let section = instrument.sections.first else { return }
            totals[section, default: 0] += value
        }
    }

    private var totalAllocated: Decimal {
        allocationBySection.values.reduce(0, +)
    }

    /// One scenario per section, then summed — never one per instrument.
    private var combinedTaxSaved: Decimal {
        allocationBySection.reduce(Decimal(0)) { running, entry in
            running + savingUseCase.execute(
                profile: profile,
                section: entry.key,
                additionalAmount: entry.value
            ).taxSaved
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VSpacing.sectionSpacing) {
                    if profile.indiaRegime == .newRegime {
                        newRegimeBanner
                    }
                    headroomCard
                    allocationSummaryCard
                    ForEach(India80CInstrumentTable.all) { instrument in
                        instrumentCard(instrument)
                    }
                    TaxDisclaimerView()
                }
                .padding(VSpacing.screenPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(VColors.groupedBackground)
            .navigationTitle(String(localized: "Compare 80C Options"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                        .accessibilityIdentifier("compare-80c-done-button")
                }
            }
        }
    }

    /// Without this the whole screen reads "Tax saved this year: ₹0.00" three times with no
    /// reason given, which looks broken rather than informative. The limits below are real
    /// — they just buy nothing under this regime.
    private var newRegimeBanner: some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.xs) {
                Label(
                    String(localized: "You're on the new regime"),
                    systemImage: "info.circle"
                )
                .font(VTypography.bodyBold)
                .foregroundStyle(VColors.textPrimary)

                Text(String(localized: "80C and 80CCD(1B) deductions do not apply under the new regime, so these contributions would not reduce this year's tax. The old regime allows them — the regime comparison on the previous screen shows which leaves you better off."))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("compare-80c-new-regime-banner")
    }

    private var headroomCard: some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                Text(String(localized: "What's left this year"))
                    .font(VTypography.bodyBold)
                    .foregroundStyle(VColors.textPrimary)

                headroomRow(
                    title: String(localized: "80C limit remaining"),
                    value: remaining80C
                )
                headroomRow(
                    title: String(localized: "80CCD(1B) limit remaining"),
                    value: remaining80CCD1B
                )

                Text(String(localized: "Contributions you already record — EPF, insurance premiums, tuition fees — count towards 80C, so this may be smaller than the full limit."))
                    .font(VTypography.caption2)
                    .foregroundStyle(VColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("compare-80c-headroom")
    }

    private func headroomRow(title: String, value: Decimal) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
            Spacer()
            Text(value.formatted(.currency(code: currencyCode)))
                .font(VTypography.bodyBold)
                .amountScaling()
                .foregroundStyle(VColors.textPrimary)
        }
        .frame(minHeight: 44)
        .contentShape([.interaction, .accessibility], Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var allocationSummaryCard: some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.sm) {
                Text(String(localized: "Your split"))
                    .font(VTypography.bodyBold)
                    .foregroundStyle(VColors.textPrimary)

                headroomRow(
                    title: String(localized: "Allocated across the options below"),
                    value: totalAllocated
                )
                headroomRow(
                    title: String(localized: "Tax saved this year"),
                    value: combinedTaxSaved
                )

                if totalAllocated > remaining80C + remaining80CCD1B {
                    Text(String(localized: "You've allocated more than the limits allow. Anything above them does not reduce your tax."))
                        .font(VTypography.caption2)
                        .foregroundStyle(VColors.expense)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(String(localized: "These options share one 80C limit, so the saving is worked out on the total, not per option."))
                    .font(VTypography.caption2)
                    .foregroundStyle(VColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("compare-80c-allocation-summary")
    }

    @ViewBuilder
    private func instrumentCard(_ instrument: India80CInstrument) -> some View {
        let rate = Decimal(localizedAmount: rateText[instrument.id] ?? "")
        let years = Int(yearsText[instrument.id] ?? "") ?? instrument.lockInYears
        let allocated = amount(for: instrument)

        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text(instrument.name)
                    .font(VTypography.bodyBold)
                    .foregroundStyle(VColors.textPrimary)

                factRow(String(localized: "Lock-in"), instrument.lockInLabel)
                factRow(String(localized: "Backing"), instrument.backing.label)
                factRow(String(localized: "Counts against"), instrument.sections.joined(separator: ", "))

                Text(instrument.returnBasis)
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(instrument.maturityTaxation)
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                fieldRow(
                    label: String(localized: "Amount to put here"),
                    text: Binding(
                        get: { amountText[instrument.id] ?? "" },
                        set: { amountText[instrument.id] = $0 }
                    ),
                    prompt: "0",
                    hint: String(localized: "Amount in \(currencyCode)"),
                    identifier: "compare-80c-amount-\(instrument.id)"
                )

                fieldRow(
                    label: String(localized: "Your assumed return (% a year)"),
                    text: Binding(
                        get: { rateText[instrument.id] ?? "" },
                        set: { rateText[instrument.id] = $0 }
                    ),
                    prompt: "0",
                    hint: String(localized: "Annual percentage you want to model"),
                    identifier: "compare-80c-rate-\(instrument.id)"
                )

                fieldRow(
                    label: String(localized: "Years"),
                    text: Binding(
                        get: { yearsText[instrument.id] ?? instrument.lockInYears.map(String.init) ?? "" },
                        set: { yearsText[instrument.id] = $0 }
                    ),
                    prompt: instrument.lockInYears.map(String.init) ?? String(localized: "Until 60"),
                    hint: String(localized: "Number of years to project"),
                    identifier: "compare-80c-years-\(instrument.id)"
                )

                if allocated > 0, let rate, rate > 0, let years, years > 0 {
                    let projected = India80CProjection.futureValue(
                        amount: allocated,
                        annualRatePercent: rate,
                        years: years
                    )
                    Text(String(localized: "At \(rate.formatted(.number.precision(.fractionLength(0...2))))% for \(years) years, \(allocated.formatted(.currency(code: currencyCode))) would grow to \(projected.formatted(.currency(code: currencyCode))) — your assumption, not a forecast by Vittora."))
                        .font(VTypography.caption1)
                        .foregroundStyle(VColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("compare-80c-projection-\(instrument.id)")
                }
            }
        }
    }

    private func factRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
            Spacer()
            Text(value)
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func fieldRow(
        label: String,
        text: Binding<String>,
        prompt: String,
        hint: String,
        identifier: String
    ) -> some View {
        let field = TextField("", text: text, prompt: Text(prompt).foregroundStyle(VColors.placeholderText))
            #if os(iOS)
            .keyboardType(.decimalPad)
            .textContentType(nil)
            #endif
            .multilineTextAlignment(.trailing)
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityIdentifier(identifier)

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: VSpacing.xs) {
                    Text(label)
                        .font(.body)
                        .foregroundStyle(VColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    field
                }
            } else {
                HStack {
                    Text(label)
                        .font(.body)
                        .foregroundStyle(VColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    field.frame(width: 120)
                }
            }
        }
        .frame(minHeight: 44)
        .contentShape([.interaction, .accessibility], Rectangle())
    }
}
