import Foundation
import VittoraCore

/// Names for `TaxEstimate`'s generic `rebate` / `surcharge` / `cess` slots.
///
/// Each country fills those three with something different, and before this the
/// display sites hardcoded India's vocabulary for all of them. A Canadian
/// estimate showed its basic personal amount credits as "87A Rebate" — a
/// section of the *Indian* Income Tax Act — its provincial tax as "Surcharge",
/// and its CPP + EI as "Cess (4%)". An Australian saw the 2% Medicare levy
/// labelled "Cess (4%)" as well.
///
/// Deliberately in the app target, not beside `TaxEstimate` in VittoraCore.
/// The package has no string catalogue of its own, and the localization gate
/// reads the app build's `.stringsdata` — strings declared in the package are
/// not extracted into `Localizable.xcstrings`, so they would ship English-only
/// under hi and es while the coverage check still reported zero missing. That
/// is the quiet failure mode, so the labels live where extraction works.
///
/// Exhaustive with no `default`, so a new country has to make a decision rather
/// than silently inheriting India's wording again.
extension TaxEstimate {
    /// Empty when the country leaves `rebate` unused, in which case the figure
    /// is zero and the display sites already hide it.
    var rebateLabel: String {
        switch country {
        case .india: String(localized: "Rebate (Sec 87A)")
        case .australia: String(localized: "Low Income Tax Offset")
        case .canada: String(localized: "Personal amount credits")
        case .unitedKingdom, .unitedStates: ""
        }
    }

    /// Canada's is not a surcharge at all — the slot carries provincial tax,
    /// which is a headline figure there rather than an add-on.
    var surchargeLabel: String {
        switch country {
        case .india: String(localized: "Surcharge")
        case .australia: String(localized: "Medicare levy surcharge")
        case .canada: String(localized: "Provincial tax")
        case .unitedKingdom, .unitedStates: ""
        }
    }

    var cessLabel: String {
        switch country {
        case .india: String(localized: "Health & Education Cess (4%)")
        case .australia: String(localized: "Medicare levy (2%)")
        case .canada: String(localized: "CPP & EI contributions")
        case .unitedKingdom, .unitedStates: ""
        }
    }
}
