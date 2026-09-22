import Foundation
import VittoraCore

/// Produces a side-by-side tax comparison for the current country.
struct CompareTaxRegimesUseCase: Sendable {
    private let estimateUseCase: EstimateTaxUseCase
    private let usTaxCalculator: USTaxCalculator
    private let ukTaxCalculator: UKTaxCalculator
    private let auTaxCalculator: AUTaxCalculator
    private let caTaxCalculator: CATaxCalculator

    nonisolated init(
        estimateUseCase: EstimateTaxUseCase = EstimateTaxUseCase(),
        usTaxCalculator: USTaxCalculator = USTaxCalculator(),
        ukTaxCalculator: UKTaxCalculator = UKTaxCalculator(),
        auTaxCalculator: AUTaxCalculator = AUTaxCalculator(),
        caTaxCalculator: CATaxCalculator = CATaxCalculator()
    ) {
        self.estimateUseCase = estimateUseCase
        self.usTaxCalculator = usTaxCalculator
        self.ukTaxCalculator = ukTaxCalculator
        self.auTaxCalculator = auTaxCalculator
        self.caTaxCalculator = caTaxCalculator
    }

    func execute(profile: TaxProfile) -> TaxComparison {
        switch profile.country {
        case .india:
            var oldRegimeProfile = profile
            oldRegimeProfile.indiaRegime = .oldRegime

            var newRegimeProfile = profile
            newRegimeProfile.indiaRegime = .newRegime

            return buildComparison(
                kind: .indiaRegimes,
                firstEstimate: estimateUseCase.execute(profile: oldRegimeProfile),
                secondEstimate: estimateUseCase.execute(profile: newRegimeProfile)
            )

        case .unitedStates:
            return buildComparison(
                kind: .usDeductionModes,
                firstEstimate: usTaxCalculator.calculate(profile: profile, deductionMode: .standardOnly),
                secondEstimate: usTaxCalculator.calculate(profile: profile, deductionMode: .itemizedOnly)
            )

        case .unitedKingdom:
            // Scotland versus the rest of the UK. This is the single largest variable
            // in a UK bill, but it is decided by residence rather than chosen, so the
            // view presents it as a difference and not as advice.
            var restOfUK = profile
            restOfUK.advancedInputs.ukIsScottishTaxpayer = false

            var scotland = profile
            scotland.advancedInputs.ukIsScottishTaxpayer = true

            return buildComparison(
                kind: .ukRegions,
                firstEstimate: ukTaxCalculator.calculate(profile: restOfUK),
                secondEstimate: ukTaxCalculator.calculate(profile: scotland)
            )

        case .australia:
            // The surcharge is avoidable by holding cover, so this is a real
            // decision — but the premium is outside what Vittora knows, and the
            // view says so rather than implying cover is free.
            var withCover = profile
            withCover.advancedInputs.auHasPrivateHospitalCover = true

            var withoutCover = profile
            withoutCover.advancedInputs.auHasPrivateHospitalCover = false

            return buildComparison(
                kind: .auPrivateCover,
                firstEstimate: auTaxCalculator.calculate(profile: withCover),
                secondEstimate: auTaxCalculator.calculate(profile: withoutCover)
            )

        case .canada:
            // What the RRSP contribution actually did. Degenerate when none was
            // entered — both sides match and the view reports a tie, which is
            // honest rather than inventing a hypothetical contribution.
            var withoutRRSP = profile
            withoutRRSP.advancedInputs.caRRSPContributions = 0

            return buildComparison(
                kind: .caRRSPImpact,
                firstEstimate: caTaxCalculator.calculate(profile: withoutRRSP),
                secondEstimate: caTaxCalculator.calculate(profile: profile)
            )
        }
    }

    private func buildComparison(
        kind: TaxComparisonKind,
        firstEstimate: TaxEstimate,
        secondEstimate: TaxEstimate
    ) -> TaxComparison {
        let winner: TaxComparisonWinner
        if firstEstimate.finalTax < secondEstimate.finalTax {
            winner = .first
        } else if secondEstimate.finalTax < firstEstimate.finalTax {
            winner = .second
        } else {
            winner = .tie
        }

        return TaxComparison(
            kind: kind,
            firstEstimate: firstEstimate,
            secondEstimate: secondEstimate,
            winner: winner,
            savingsAmount: (firstEstimate.finalTax - secondEstimate.finalTax).absoluteValue
        )
    }
}
