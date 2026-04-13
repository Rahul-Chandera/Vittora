import Foundation

/// India income tax calculator for FY 2024-25.
/// Supports both the New Regime (default) and Old Regime.
struct IndiaTaxCalculator: TaxCalculatorProtocol {
    let country: TaxCountry = .india

    func calculate(profile: TaxProfile) -> TaxEstimate {
        let regime = profile.indiaRegime
        let gross = profile.annualIncome

        // Standard deduction
        let standardDeduction: Decimal = regime == .newRegime ? 75_000 : 50_000

        // Custom deductions apply only in old regime (80C, 80D, etc.)
        let customDeductionsTotal: Decimal = regime == .oldRegime
            ? profile.customDeductions.reduce(0) { $0 + $1.amount }
            : 0

        let taxableIncome = max(0, gross - standardDeduction - customDeductionsTotal)

        // Slab definitions (FY 2024-25)
        let slabs: [TaxSlab] = regime == .newRegime
            ? newRegimeSlabs()
            : oldRegimeSlabs()

        let bracketResults = slabs.apply(to: taxableIncome)
        let basicTax = bracketResults.reduce(Decimal(0)) { $0 + $1.taxAmount }

        // Section 87A rebate
        let rebate: Decimal
        if regime == .newRegime {
            rebate = taxableIncome <= 700_000 ? min(basicTax, 25_000) : 0
        } else {
            rebate = taxableIncome <= 500_000 ? min(basicTax, 12_500) : 0
        }

        let taxAfterRebate = max(0, basicTax - rebate)

        // Surcharge (based on gross income)
        let surcharge = calculateSurcharge(taxAfterRebate: taxAfterRebate, grossIncome: gross, regime: regime)

        // Health & Education Cess: 4%
        let cess = ((taxAfterRebate + surcharge) * 4 / 100).rounded(scale: 2)

        let finalTax = (taxAfterRebate + surcharge + cess).rounded(scale: 2)
        let effectiveRate = gross > 0 ? (finalTax / gross).rounded(scale: 4) : 0
        let marginalRate = bracketResults.last?.ratePercent ?? 0

        return TaxEstimate(
            grossIncome: gross,
            standardDeduction: standardDeduction,
            customDeductionsTotal: customDeductionsTotal,
            taxableIncome: taxableIncome,
            bracketResults: bracketResults,
            basicTax: basicTax,
            rebate: rebate,
            surcharge: surcharge,
            cess: cess,
            finalTax: finalTax,
            effectiveRate: effectiveRate,
            marginalRate: marginalRate,
            country: .india,
            regimeLabel: regime.displayName
        )
    }

    // MARK: - Slabs

    private func newRegimeSlabs() -> [TaxSlab] {
        [
            TaxSlab(lower: 0,          upper: 300_000,   ratePercent: 0,  label: "₹0 – ₹3L"),
            TaxSlab(lower: 300_000,    upper: 700_000,   ratePercent: 5,  label: "₹3L – ₹7L"),
            TaxSlab(lower: 700_000,    upper: 1_000_000, ratePercent: 10, label: "₹7L – ₹10L"),
            TaxSlab(lower: 1_000_000,  upper: 1_200_000, ratePercent: 15, label: "₹10L – ₹12L"),
            TaxSlab(lower: 1_200_000,  upper: 1_500_000, ratePercent: 20, label: "₹12L – ₹15L"),
            TaxSlab(lower: 1_500_000,  upper: nil,       ratePercent: 30, label: "Above ₹15L"),
        ]
    }

    private func oldRegimeSlabs() -> [TaxSlab] {
        [
            TaxSlab(lower: 0,         upper: 250_000,  ratePercent: 0,  label: "₹0 – ₹2.5L"),
            TaxSlab(lower: 250_000,   upper: 500_000,  ratePercent: 5,  label: "₹2.5L – ₹5L"),
            TaxSlab(lower: 500_000,   upper: 1_000_000, ratePercent: 20, label: "₹5L – ₹10L"),
            TaxSlab(lower: 1_000_000, upper: nil,       ratePercent: 30, label: "Above ₹10L"),
        ]
    }

    // MARK: - Surcharge

    private func calculateSurcharge(taxAfterRebate: Decimal, grossIncome: Decimal, regime: IndiaRegime) -> Decimal {
        let rate: Decimal
        if grossIncome > 5_00_00_000 {         // > ₹5 Crore
            rate = regime == .newRegime ? 25 : 37
        } else if grossIncome > 2_00_00_000 {  // > ₹2 Crore
            rate = 25
        } else if grossIncome > 1_00_00_000 {  // > ₹1 Crore
            rate = 15
        } else if grossIncome > 50_00_000 {    // > ₹50 Lakh
            rate = 10
        } else {
            rate = 0
        }
        return (taxAfterRebate * rate / 100).rounded(scale: 2)
    }
}
