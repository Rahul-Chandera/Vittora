import Foundation

// MARK: - Country & Regime

enum TaxCountry: String, Sendable, Hashable, CaseIterable, Codable {
    case india = "IN"
    case unitedStates = "US"

    var displayName: String {
        switch self {
        case .india:         return String(localized: "India")
        case .unitedStates:  return String(localized: "United States")
        }
    }

    var currencyCode: String {
        switch self {
        case .india:        return "INR"
        case .unitedStates: return "USD"
        }
    }

    var currencySymbol: String {
        switch self {
        case .india:        return "₹"
        case .unitedStates: return "$"
        }
    }

    nonisolated var defaultFinancialYear: String {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: .now)

        switch self {
        case .india:
            let month = calendar.component(.month, from: .now)
            let startYear = month >= 4 ? currentYear : currentYear - 1
            let endYearSuffix = (startYear + 1) % 100
            return "\(startYear)-\(String(format: "%02d", endYearSuffix))"

        case .unitedStates:
            return "\(currentYear)"
        }
    }
}

enum IndiaRegime: String, Sendable, Hashable, CaseIterable, Codable {
    case newRegime
    case oldRegime

    var displayName: String {
        switch self {
        case .newRegime: return String(localized: "New Regime")
        case .oldRegime: return String(localized: "Old Regime")
        }
    }
}

enum IncomeSourceType: String, Sendable, Hashable, CaseIterable, Codable {
    case salaried
    case selfEmployed

    var displayName: String {
        switch self {
        case .salaried:     return String(localized: "Salaried / Pensioner")
        case .selfEmployed: return String(localized: "Self Employed / Business")
        }
    }
}

enum USFilingStatus: String, Sendable, Hashable, CaseIterable, Codable {
    case single
    case marriedFilingJointly
    case marriedFilingSeparately
    case headOfHousehold
    case qualifyingSurvivingSpouse

    var displayName: String {
        switch self {
        case .single:                   return String(localized: "Single")
        case .marriedFilingJointly:     return String(localized: "Married Filing Jointly")
        case .marriedFilingSeparately:  return String(localized: "Married Filing Separately")
        case .headOfHousehold:          return String(localized: "Head of Household")
        case .qualifyingSurvivingSpouse:
            return String(localized: "Qualifying Surviving Spouse")
        }
    }
}

// MARK: - Tax Deduction

struct TaxDeduction: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var name: String
    var amount: Decimal
    /// Section identifier e.g. "80C", "80D", "HRA"
    var section: String?

    init(id: UUID = UUID(), name: String, amount: Decimal, section: String? = nil) {
        self.id = id
        self.name = name
        self.amount = amount
        self.section = section
    }
}

// MARK: - Tax Profile

struct TaxProfile: Identifiable, Hashable, Sendable {
    let id: UUID
    var country: TaxCountry
    var annualIncome: Decimal
    var indiaRegime: IndiaRegime
    var filingStatus: USFilingStatus
    var customDeductions: [TaxDeduction]
    /// e.g. "2025-26" (India) or "2026" (US)
    var financialYear: String
    /// Salary/pension vs self-employed; gates India standard deduction
    var incomeSourceType: IncomeSourceType
    /// Used for India old-regime senior/super-senior basic exemption tiers
    var dateOfBirth: Date?
    var createdAt: Date
    var updatedAt: Date

    nonisolated init(
        id: UUID = UUID(),
        country: TaxCountry = .india,
        annualIncome: Decimal = 0,
        indiaRegime: IndiaRegime = .newRegime,
        filingStatus: USFilingStatus = .single,
        customDeductions: [TaxDeduction] = [],
        financialYear: String = TaxCountry.india.defaultFinancialYear,
        incomeSourceType: IncomeSourceType = .salaried,
        dateOfBirth: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.country = country
        self.annualIncome = annualIncome
        self.indiaRegime = indiaRegime
        self.filingStatus = filingStatus
        self.customDeductions = customDeductions
        self.financialYear = financialYear
        self.incomeSourceType = incomeSourceType
        self.dateOfBirth = dateOfBirth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Tax Estimate Results

/// One tax slab's contribution to the overall tax
struct TaxBracketResult: Sendable, Identifiable {
    let id: UUID
    /// e.g. "₹3L – ₹7L" or "$11,601 – $47,150"
    let label: String
    /// Rate as a whole number percent e.g. 5, 10, 20, 30
    let ratePercent: Decimal
    let taxableAmount: Decimal
    let taxAmount: Decimal

    nonisolated init(
        id: UUID = UUID(),
        label: String,
        ratePercent: Decimal,
        taxableAmount: Decimal,
        taxAmount: Decimal
    ) {
        self.id = id
        self.label = label
        self.ratePercent = ratePercent
        self.taxableAmount = taxableAmount
        self.taxAmount = taxAmount
    }
}

/// Computed tax breakdown for a TaxProfile
struct TaxEstimate: Sendable {
    let grossIncome: Decimal
    let standardDeduction: Decimal
    let customDeductionsTotal: Decimal
    let taxableIncome: Decimal
    /// One entry per non-zero bracket
    let bracketResults: [TaxBracketResult]
    let basicTax: Decimal
    /// Section 87A rebate (India) or equivalent
    let rebate: Decimal
    let surcharge: Decimal
    /// India: 4% health & education cess; US: 0
    let cess: Decimal
    let finalTax: Decimal
    let effectiveRate: Decimal
    let marginalRate: Decimal
    let country: TaxCountry
    /// e.g. "New Regime", "Old Regime", "Single"
    let regimeLabel: String

    var totalDeductions: Decimal { standardDeduction + customDeductionsTotal }
}

// MARK: - Tax Comparison

enum TaxComparisonKind: Sendable, Hashable {
    case indiaRegimes
    case usDeductionModes
}

enum TaxComparisonWinner: Sendable, Hashable {
    case first
    case second
    case tie
}

struct TaxComparison: Sendable {
    let kind: TaxComparisonKind
    let firstEstimate: TaxEstimate
    let secondEstimate: TaxEstimate
    let winner: TaxComparisonWinner
    let savingsAmount: Decimal

    var recommendedEstimate: TaxEstimate? {
        switch winner {
        case .first:
            firstEstimate
        case .second:
            secondEstimate
        case .tie:
            nil
        }
    }
}

// MARK: - Tax Activity Summary

struct TaxSummaryCategory: Sendable, Identifiable {
    var id: UUID { category.id }
    let category: CategoryEntity
    let totalAmount: Decimal
    let transactionCount: Int
}

struct TaxSummary: Sendable {
    let financialYear: String
    let dateRange: ClosedRange<Date>
    let totalRelevantAmount: Decimal
    let transactionCount: Int
    let taxRelevantCategories: [CategoryEntity]
    let categoryBreakdown: [TaxSummaryCategory]

    var matchedCategoryCount: Int { categoryBreakdown.count }
}
