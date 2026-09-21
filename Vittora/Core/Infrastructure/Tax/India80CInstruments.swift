import Foundation
import VittoraCore

/// The three Section 80C instruments named in the plan (M2.4.1), described by what is
/// statutory about them rather than by what they might return.
///
/// **No return figures live here, deliberately.** Lock-in, the section a contribution
/// counts against, what backs the instrument and how maturity is taxed are all statutory
/// and change rarely. Returns are not: PPF's rate is notified quarterly and ELSS is
/// market-linked, so any number Vittora shipped would be a forecast presented as a fact,
/// and stale between releases besides. The user supplies the rate they want to model and
/// the screen labels it as theirs.
struct India80CInstrument: Sendable, Identifiable, Equatable {
    enum Backing: Sendable, Equatable {
        case governmentBacked
        case marketLinked

        var label: String {
            switch self {
            case .governmentBacked: return String(localized: "Government-backed")
            case .marketLinked: return String(localized: "Market-linked")
            }
        }
    }

    nonisolated let id: String
    nonisolated let name: String
    /// The section the contribution counts against — NPS Tier-I can also use the separate
    /// 80CCD(1B) limit, which is why it is the only one with two.
    nonisolated let sections: [String]
    /// Statutory lock-in in whole years. `nil` where the lock-in is age-linked rather than
    /// a fixed term.
    nonisolated let lockInYears: Int?
    nonisolated let lockInLabel: String
    nonisolated let backing: Backing
    nonisolated let returnBasis: String
    nonisolated let maturityTaxation: String
}

enum India80CInstrumentTable {
    /// FY 2025-26. Statutory characteristics only — see the note on `India80CInstrument`
    /// for why there are no rates in here.
    nonisolated static let ruleSetID = "IN_80C_INSTRUMENTS_FY2025_26"

    nonisolated static let all: [India80CInstrument] = [
        India80CInstrument(
            id: "elss",
            name: String(localized: "ELSS"),
            sections: ["80C"],
            lockInYears: 3,
            lockInLabel: String(localized: "3 years"),
            backing: .marketLinked,
            returnBasis: String(localized: "Depends on equity markets. Not guaranteed, and can fall."),
            maturityTaxation: String(localized: "Gains taxed as equity long-term capital gains above the annual exemption.")
        ),
        India80CInstrument(
            id: "ppf",
            name: String(localized: "PPF"),
            sections: ["80C"],
            lockInYears: 15,
            lockInLabel: String(localized: "15 years"),
            backing: .governmentBacked,
            returnBasis: String(localized: "Rate notified by the government each quarter, so it changes over the term."),
            maturityTaxation: String(localized: "Interest and maturity proceeds are exempt.")
        ),
        India80CInstrument(
            id: "nps-tier-1",
            name: String(localized: "NPS Tier-I"),
            sections: ["80C", "80CCD(1B)"],
            lockInYears: nil,
            lockInLabel: String(localized: "Until age 60"),
            backing: .marketLinked,
            returnBasis: String(localized: "Depends on the funds you choose. Not guaranteed."),
            maturityTaxation: String(localized: "Part of the corpus is exempt at exit; the annuity you buy is taxed as income.")
        ),
    ]
}

/// Compounding for the projection the user asks for by entering a rate.
enum India80CProjection {
    /// Compounds `amount` annually for `years` at `annualRatePercent`.
    ///
    /// Whole-year Decimal multiplication rather than `pow` on a `Double`: money never
    /// touches binary floating point in this codebase, and every lock-in the table models
    /// is a whole number of years anyway.
    nonisolated static func futureValue(
        amount: Decimal,
        annualRatePercent: Decimal,
        years: Int
    ) -> Decimal {
        guard amount > 0, years > 0 else { return max(0, amount) }
        guard annualRatePercent > 0 else { return amount }

        let growth = 1 + annualRatePercent / 100
        var value = amount
        for _ in 0..<years {
            value *= growth
        }
        return value.rounded(scale: 2)
    }
}
