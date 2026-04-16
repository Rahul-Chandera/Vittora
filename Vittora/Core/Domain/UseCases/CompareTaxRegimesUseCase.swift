import Foundation

/// Produces a side-by-side tax comparison for the current country.
struct CompareTaxRegimesUseCase: Sendable {
    private let estimateUseCase: EstimateTaxUseCase
    private let usTaxCalculator: USTaxCalculator

    init(
        estimateUseCase: EstimateTaxUseCase = EstimateTaxUseCase(),
        usTaxCalculator: USTaxCalculator = USTaxCalculator()
    ) {
        self.estimateUseCase = estimateUseCase
        self.usTaxCalculator = usTaxCalculator
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
