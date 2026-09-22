import SwiftUI
import VittoraCore

/// "What would one more contribution be worth?" (M2.4.4).
///
/// Educational and scenario-based per the plan's scope note for Module 2.4: it answers what
/// an amount would do to this year's tax, and never suggests an instrument or an amount.
/// Every figure comes from `EstimateTaxSavingUseCase`, which runs the same calculator as the
/// estimate above it, so the two can never disagree.
struct TaxSavingScenarioCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let profile: TaxProfile
    let currencyCode: String

    @State private var selectedSection: String = ""
    @State private var amountText: String = ""

    private let useCase = EstimateTaxSavingUseCase()

    /// The buckets a user can actually claim against. India's list is shown in the new
    /// regime too: discovering that a section does nothing there is the point, and the
    /// scenario says so in its own words rather than hiding the option.
    private var sections: [(key: String, title: String)] {
        switch profile.country {
        case .india:
            return [
                ("80C", String(localized: "80C")),
                ("80CCD(1B)", String(localized: "80CCD(1B)")),
                ("80D", String(localized: "80D")),
            ]
        case .unitedStates:
            // IRA is absent deliberately: the calculator does not grant its deduction, so
            // offering it here would promise a saving the estimate never delivers.
            return [
                ("401k", EstimateTaxSavingUseCase.USContribution.traditional401k.title),
                ("hsa", EstimateTaxSavingUseCase.USContribution.hsa.title),
                ("itemized", String(localized: "Itemised")),
            ]
        case .unitedKingdom:
            // Both route through customDeductions, which is what relief at source and
            // Gift Aid do to taxable income. Nothing here claims the pension annual
            // allowance taper, which the calculator does not model — see its exclusions.
            return [
                ("pension", String(localized: "Pension contribution")),
                ("giftaid", String(localized: "Gift Aid")),
            ]
        case .australia:
            // Work deductions route through customDeductions. Salary-sacrificed
            // super is the distinctly Australian lever and does the same thing to
            // assessable income, capped by the calculator at the concessional limit.
            return [
                ("super", String(localized: "Salary sacrifice to super")),
                ("deduction", String(localized: "Work-related deduction")),
            ]
        }
    }

    private var activeSection: String {
        selectedSection.isEmpty ? (sections.first?.key ?? "") : selectedSection
    }

    private var amount: Decimal? {
        Decimal(localizedAmount: amountText)
    }

    private var scenario: TaxSavingScenario? {
        guard let amount, amount > 0, !activeSection.isEmpty else { return nil }
        // Contributions move advancedInputs; sections go through customDeductions. Two
        // different mechanisms in the calculator, so two different entry points here.
        switch activeSection {
        case "401k":
            return useCase.execute(profile: profile, contribution: .traditional401k, additionalAmount: amount)
        case "hsa":
            return useCase.execute(profile: profile, contribution: .hsa, additionalAmount: amount)
        default:
            return useCase.execute(profile: profile, section: activeSection, additionalAmount: amount)
        }
    }

    var body: some View {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                header

                if sections.count > 1 {
                    sectionPicker
                }

                amountRow

                if let scenario {
                    Divider()
                    result(scenario)
                }

                Text(String(localized: "A scenario for this year only, using your current income and deductions. Not a recommendation to invest."))
                    .font(VTypography.caption2)
                    .foregroundStyle(VColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("tax-saving-scenario-card")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: VSpacing.xs) {
            Text(String(localized: "What would it save?"))
                .font(VTypography.bodyBold)
                .foregroundStyle(VColors.textPrimary)
            Text(String(localized: "Try an amount to see what it would take off this year's tax."))
                .font(VTypography.caption1)
                .foregroundStyle(VColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sectionPicker: some View {
        Picker(String(localized: "Section"), selection: Binding(
            get: { activeSection },
            set: { selectedSection = $0 }
        )) {
            ForEach(sections, id: \.key) { section in
                Text(section.title).tag(section.key)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(String(localized: "Deduction section"))
        .accessibilityIdentifier("tax-saving-section-picker")
    }

    private var amountRow: some View {
        let field = TextField(
            "",
            text: $amountText,
            prompt: Text("0").foregroundStyle(VColors.placeholderText)
        )
        #if os(iOS)
        .keyboardType(.decimalPad)
        .textContentType(nil)
        #endif
        .multilineTextAlignment(.trailing)
        .accessibilityLabel(String(localized: "Amount to model"))
        .accessibilityHint(String(localized: "Amount in \(currencyCode)"))
        .accessibilityIdentifier("tax-saving-amount-field")

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: VSpacing.xs) {
                    Text(String(localized: "Amount"))
                        .font(.body)
                        .foregroundStyle(VColors.textPrimary)
                    field
                }
            } else {
                HStack {
                    Text(String(localized: "Amount"))
                        .font(.body)
                        .foregroundStyle(VColors.textPrimary)
                    Spacer()
                    field.frame(width: 140)
                }
            }
        }
        .frame(minHeight: 44)
        .contentShape([.interaction, .accessibility], Rectangle())
    }

    @ViewBuilder
    private func result(_ scenario: TaxSavingScenario) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            Text(scenario.taxSaved.formatted(.currency(code: currencyCode)))
                .font(VTypography.amountMedium)
                .amountScaling()
                .foregroundStyle(scenario.isIneffective ? VColors.textSecondary : VColors.income)

            Text(
                scenario.isIneffective
                    ? String(localized: "No change to your tax")
                    : String(localized: "Off this year's tax")
            )
            .font(VTypography.caption1)
            .foregroundStyle(VColors.textSecondary)

            if !scenario.isIneffective {
                // The rate is what makes two sections comparable, which is the whole
                // reason this is more useful than the raw figure above.
                Text(String(localized: "\(scenario.deductibleAmount.formatted(.currency(code: currencyCode))) of what you entered was deductible, worth \((scenario.savingRate * 100).formatted(.number.precision(.fractionLength(1))))% of it back."))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(scenario.notes, id: \.self) { note in
                Text(note)
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tax-saving-result")
    }
}
