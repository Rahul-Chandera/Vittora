import Foundation
import VittoraCore

/// Statutory India compliance thresholds for on-device tips (C1 / M3.6.3).
/// Thresholds live here — never inline in views — and carry the assessment year
/// they were modeled against so a future-year change is a data edit.
enum IndiaComplianceRuleID: String, Sendable, CaseIterable, Codable {
    case section269ST
    case section40A3
    case sftCashDeposit
    case gstRegistration
    case section194IB
}

enum IndiaComplianceComparison: String, Sendable {
    /// Statutory phrase "or more" / "aggregating to X or more" → triggers at exact threshold.
    case greaterThanOrEqual
    /// Statutory phrase "exceeding" / "above" → exact threshold does **not** trigger.
    case greaterThan
}

struct IndiaComplianceRuleDefinition: Sendable {
    nonisolated let id: IndiaComplianceRuleID
    /// e.g. "Income-tax Act 1961, Section 269ST"
    nonisolated let statutorySource: String
    /// Assessment year these figures were modeled for (e.g. "AY 2026-27").
    nonisolated let assessmentYear: String
    /// Financial year label paired with `assessmentYear` (e.g. "FY 2025-26").
    nonisolated let financialYear: String
    nonisolated let threshold: Decimal
    nonisolated let comparison: IndiaComplianceComparison

    nonisolated func isTriggered(by amount: Decimal) -> Bool {
        switch comparison {
        case .greaterThanOrEqual:
            return amount >= threshold
        case .greaterThan:
            return amount > threshold
        }
    }
}

enum IndiaComplianceRules {
    /// Modeled year for all five tip rules in this release.
    nonisolated static let assessmentYear = "AY 2026-27"
    nonisolated static let financialYear = "FY 2025-26"

    /// §269ST: receiving ₹2,00,000 **or more** in cash from one person in a day.
    nonisolated static let section269ST = IndiaComplianceRuleDefinition(
        id: .section269ST,
        statutorySource: "Income-tax Act 1961, Section 269ST",
        assessmentYear: assessmentYear,
        financialYear: financialYear,
        threshold: 2_00_000,
        comparison: .greaterThanOrEqual
    )

    /// §40A(3): cash business expenditure **exceeding** ₹10,000 in a day.
    nonisolated static let section40A3 = IndiaComplianceRuleDefinition(
        id: .section40A3,
        statutorySource: "Income-tax Act 1961, Section 40A(3)",
        assessmentYear: assessmentYear,
        financialYear: financialYear,
        threshold: 10_000,
        comparison: .greaterThan
    )

    /// SFT (Rule 114E): cash deposits aggregating to ₹10,00,000 **or more** in savings accounts in a FY.
    nonisolated static let sftSavingsDeposit = IndiaComplianceRuleDefinition(
        id: .sftCashDeposit,
        statutorySource: "Income-tax Rules 1962, Rule 114E (SFT) — savings account",
        assessmentYear: assessmentYear,
        financialYear: financialYear,
        threshold: 10_00_000,
        comparison: .greaterThanOrEqual
    )

    /// SFT (Rule 114E): cash deposits aggregating to ₹50,00_000 **or more** in current accounts in a FY.
    nonisolated static let sftCurrentDeposit = IndiaComplianceRuleDefinition(
        id: .sftCashDeposit,
        statutorySource: "Income-tax Rules 1962, Rule 114E (SFT) — current account",
        assessmentYear: assessmentYear,
        financialYear: financialYear,
        threshold: 50_00_000,
        comparison: .greaterThanOrEqual
    )

    /// GST registration — services (general states): aggregate turnover **exceeding** ₹20,00,000.
    /// Goods general threshold is ₹40,00,000; special-category states use ₹10,00,000 / ₹20,00,000.
    nonisolated static let gstServicesGeneral = IndiaComplianceRuleDefinition(
        id: .gstRegistration,
        statutorySource: "CGST Act 2017, Section 22 (services, general states)",
        assessmentYear: assessmentYear,
        financialYear: financialYear,
        threshold: 20_00_000,
        comparison: .greaterThan
    )

    nonisolated static let gstGoodsGeneralThreshold: Decimal = 40_00_000
    nonisolated static let gstServicesSpecialCategoryThreshold: Decimal = 10_00_000
    nonisolated static let gstGoodsSpecialCategoryThreshold: Decimal = 20_00_000

    /// §194-IB: rent **exceeding** ₹50,000 for a month.
    nonisolated static let section194IB = IndiaComplianceRuleDefinition(
        id: .section194IB,
        statutorySource: "Income-tax Act 1961, Section 194-IB",
        assessmentYear: assessmentYear,
        financialYear: financialYear,
        threshold: 50_000,
        comparison: .greaterThan
    )

    nonisolated static func definition(for id: IndiaComplianceRuleID) -> IndiaComplianceRuleDefinition {
        switch id {
        case .section269ST: section269ST
        case .section40A3: section40A3
        case .sftCashDeposit: sftSavingsDeposit
        case .gstRegistration: gstServicesGeneral
        case .section194IB: section194IB
        }
    }
}
