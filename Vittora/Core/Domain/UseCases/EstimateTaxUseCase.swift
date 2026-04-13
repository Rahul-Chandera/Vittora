import Foundation

/// Routes a TaxProfile to the correct calculator and returns a TaxEstimate.
struct EstimateTaxUseCase: Sendable {
    private let calculators: [TaxCountry: any TaxCalculatorProtocol]

    init(calculators: [any TaxCalculatorProtocol] = [IndiaTaxCalculator(), USTaxCalculator()]) {
        self.calculators = Dictionary(uniqueKeysWithValues: calculators.map { ($0.country, $0) })
    }

    func execute(profile: TaxProfile) -> TaxEstimate {
        guard let calculator = calculators[profile.country] else {
            // Fallback — return a zero estimate
            return TaxEstimate(
                grossIncome: profile.annualIncome,
                standardDeduction: 0,
                customDeductionsTotal: 0,
                taxableIncome: profile.annualIncome,
                bracketResults: [],
                basicTax: 0,
                rebate: 0,
                surcharge: 0,
                cess: 0,
                finalTax: 0,
                effectiveRate: 0,
                marginalRate: 0,
                country: profile.country,
                regimeLabel: ""
            )
        }
        return calculator.calculate(profile: profile)
    }
}
