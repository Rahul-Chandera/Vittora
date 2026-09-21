import Foundation
import VittoraCore

/// What one more rupee or dollar of a given deduction is actually worth (M2.4.4).
///
/// Educational and scenario-based per the plan's scope note for Module 2.4: it answers
/// "what would this do to my tax", never "you should do this".
struct TaxSavingScenario: Sendable, Equatable {
    /// The section or bucket the hypothetical amount was claimed under, e.g. "80C".
    nonisolated let sectionKey: String
    /// What the user asked to model.
    nonisolated let additionalAmount: Decimal
    /// How much of `additionalAmount` actually reduced taxable income. Below
    /// `additionalAmount` when a statutory cap is already met, when the regime does not
    /// allow the section at all, or when itemising still loses to the standard deduction.
    nonisolated let deductibleAmount: Decimal
    nonisolated let baselineTax: Decimal
    nonisolated let scenarioTax: Decimal
    nonisolated let notes: [String]

    nonisolated var taxSaved: Decimal { max(0, baselineTax - scenarioTax) }

    /// Tax saved per unit actually deducted — the number that makes a section comparable
    /// to another. Zero when nothing was deductible, rather than undefined.
    nonisolated var savingRate: Double {
        guard deductibleAmount > 0 else { return 0 }
        return (taxSaved as NSDecimalNumber).doubleValue
            / (deductibleAmount as NSDecimalNumber).doubleValue
    }

    /// True when the amount changed nothing, which is a result worth showing rather than
    /// a failure: it is how a user learns their 80C is already full.
    nonisolated var isIneffective: Bool { deductibleAmount <= 0 }
}

/// Runs the real calculator twice — once as-is, once with a hypothetical deduction added —
/// and reports the difference.
///
/// Deliberately no tax arithmetic of its own. Surcharge, marginal relief, cess, rebate,
/// regime rules and every statutory cap come from `EstimateTaxUseCase`, so a scenario can
/// never disagree with the estimate shown on the same screen. It also means a capped
/// section correctly reports zero saving instead of a plausible-looking wrong number.
struct EstimateTaxSavingUseCase: Sendable {
    private let estimateUseCase: EstimateTaxUseCase

    nonisolated init(estimateUseCase: EstimateTaxUseCase = EstimateTaxUseCase()) {
        self.estimateUseCase = estimateUseCase
    }

    func execute(
        profile: TaxProfile,
        section: String,
        additionalAmount: Decimal
    ) -> TaxSavingScenario {
        let baseline = estimateUseCase.execute(profile: profile)

        guard additionalAmount > 0 else {
            return TaxSavingScenario(
                sectionKey: section,
                additionalAmount: additionalAmount,
                deductibleAmount: 0,
                baselineTax: baseline.finalTax,
                scenarioTax: baseline.finalTax,
                notes: []
            )
        }

        var scenarioProfile = profile
        scenarioProfile.customDeductions.append(
            TaxDeduction(
                name: String(localized: "Scenario"),
                amount: additionalAmount,
                section: section
            )
        )
        let scenario = estimateUseCase.execute(profile: scenarioProfile)

        // Taxable income, not the claimed amount: this is what survived every cap, the
        // regime check and the standard-versus-itemised choice, and it works the same way
        // for both countries without branching on either.
        let deductible = max(0, baseline.taxableIncome - scenario.taxableIncome)

        return TaxSavingScenario(
            sectionKey: section,
            additionalAmount: additionalAmount,
            deductibleAmount: deductible,
            baselineTax: baseline.finalTax,
            scenarioTax: scenario.finalTax,
            notes: Self.notes(
                profile: profile,
                section: section,
                additionalAmount: additionalAmount,
                deductible: deductible
            )
        )
    }

    /// Says why an amount did nothing. Without this the card reads as broken when the
    /// answer is "your 80C is full" or "the new regime does not allow this".
    nonisolated private static func notes(
        profile: TaxProfile,
        section: String,
        additionalAmount: Decimal,
        deductible: Decimal
    ) -> [String] {
        guard deductible < additionalAmount else { return [] }

        if profile.country == .india, profile.indiaRegime == .newRegime {
            return [String(localized: "The new regime does not allow this deduction. The old regime does — compare both before deciding.")]
        }
        if deductible <= 0 {
            return profile.country == .india
                ? [String(localized: "This section is already at its statutory limit for the year, so more would not reduce your tax.")]
                : [String(localized: "Your standard deduction is still larger than your itemised total, so this would not reduce your tax.")]
        }
        // The US partial case is not a cap at all: the first slice of an itemised deduction
        // only buys back the standard deduction it replaces, so only the excess is worth
        // anything. Calling that "above the statutory limit" told the user the wrong story.
        return profile.country == .india
            ? [String(localized: "Only part of this amount reduced your taxable income — the rest is above the statutory limit.")]
            : [String(localized: "Only the amount above your standard deduction reduces your tax — itemising replaces the standard deduction rather than adding to it.")]
    }
}
