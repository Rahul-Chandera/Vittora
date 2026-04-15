import Foundation

/// Pluggable tax estimation engine. Each country/regime gets its own conforming type.
protocol TaxCalculatorProtocol: Sendable {
    var country: TaxCountry { get }
    func calculate(profile: TaxProfile) -> TaxEstimate
}

// MARK: - Slab Helper

/// Internal slab definition used by calculators
struct TaxSlab: Sendable {
    /// Lower bound (inclusive)
    let lower: Decimal
    /// Upper bound (inclusive); nil = unbounded
    let upper: Decimal?
    /// Rate as whole-number percent e.g. 5, 10, 30
    let ratePercent: Decimal
    let label: String
}

extension [TaxSlab] {
    /// Applies progressive slab calculation to `taxableIncome`.
    /// Returns per-bracket results (zero-rate brackets omitted).
    nonisolated func apply(to taxableIncome: Decimal) -> [TaxBracketResult] {
        var results: [TaxBracketResult] = []
        var remaining = taxableIncome
        var prev = Decimal(0)

        for slab in self {
            guard remaining > 0 else { break }
            let upper = slab.upper ?? (prev + remaining)
            let slabWidth = upper - prev
            let taxable = Swift.min(remaining, slabWidth)

            if taxable > 0 && slab.ratePercent > 0 {
                let tax = (taxable * slab.ratePercent / 100).rounded(scale: 2)
                results.append(TaxBracketResult(
                    label: slab.label,
                    ratePercent: slab.ratePercent,
                    taxableAmount: taxable,
                    taxAmount: tax
                ))
            }
            remaining -= taxable
            prev = upper
        }
        return results
    }
}

extension Decimal {
    nonisolated func rounded(scale: Int) -> Decimal {
        var result = Decimal()
        var copy = self
        NSDecimalRound(&result, &copy, scale, .bankers)
        return result
    }
}
