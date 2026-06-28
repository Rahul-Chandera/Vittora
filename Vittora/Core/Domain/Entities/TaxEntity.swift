import Foundation

// MARK: - Country & Regime

enum TaxCountry: String, Sendable, Hashable, CaseIterable, Codable {
    case india = "IN"
    case unitedStates = "US"

    nonisolated var displayName: String {
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

    nonisolated var displayName: String {
        switch self {
        case .newRegime: return String(localized: "New Regime")
        case .oldRegime: return String(localized: "Old Regime")
        }
    }
}

enum IncomeSourceType: String, Sendable, Hashable, CaseIterable, Codable {
    case salaried
    case selfEmployed

    nonisolated var displayName: String {
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

    nonisolated var displayName: String {
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
    nonisolated let id: UUID
    nonisolated var name: String
    nonisolated var amount: Decimal
    /// Section identifier e.g. "80C", "80D", "HRA"
    nonisolated var section: String?

    nonisolated init(id: UUID = UUID(), name: String, amount: Decimal, section: String? = nil) {
        self.id = id
        self.name = name
        self.amount = amount
        self.section = section
    }
}

// MARK: - Tax Profile

struct TaxProfile: Identifiable, Hashable, Sendable {
    nonisolated let id: UUID
    nonisolated var country: TaxCountry
    nonisolated var annualIncome: Decimal
    nonisolated var indiaRegime: IndiaRegime
    nonisolated var filingStatus: USFilingStatus
    nonisolated var customDeductions: [TaxDeduction]
    /// e.g. "2025-26" (India) or "2026" (US)
    nonisolated var financialYear: String
    /// Salary/pension vs self-employed; gates India standard deduction
    nonisolated var incomeSourceType: IncomeSourceType
    /// Used for India old-regime senior/super-senior basic exemption tiers
    nonisolated var dateOfBirth: Date?
    nonisolated var createdAt: Date
    nonisolated var updatedAt: Date

    /// Optional special-rate and payroll inputs (TAX-11 / TAX-12). Persisted as JSON on `SDTaxProfile`.
    nonisolated var advancedInputs: TaxAdvancedInputs

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
        advancedInputs: TaxAdvancedInputs = TaxAdvancedInputs(),
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
        self.advancedInputs = advancedInputs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Advanced tax inputs (special rates, payroll bases)

struct TaxAdvancedInputs: Sendable, Hashable, Equatable {
    /// US: qualified dividends (taxed at LTCG rates).
    nonisolated var usQualifiedDividends: Decimal = 0
    /// US: long-term capital gains (preferential rates).
    nonisolated var usLongTermCapitalGains: Decimal = 0
    /// US: short-term capital gains (generally ordinary rates — included in ordinary base here).
    nonisolated var usShortTermCapitalGains: Decimal = 0
    /// US: other investment income counted toward NIIT net investment income.
    nonisolated var usOtherInvestmentIncome: Decimal = 0
    /// India: equity LTCG taxed under Section 112A-style simplified model.
    nonisolated var indiaEquityLTCG: Decimal = 0
    /// India: equity STCG (simplified flat rate bucket).
    nonisolated var indiaEquitySTCG: Decimal = 0
}

extension TaxAdvancedInputs: Codable {
    enum CodingKeys: String, CodingKey {
        case usQualifiedDividends
        case usLongTermCapitalGains
        case usShortTermCapitalGains
        case usOtherInvestmentIncome
        case indiaEquityLTCG
        case indiaEquitySTCG
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usQualifiedDividends = try container.decodeIfPresent(Decimal.self, forKey: .usQualifiedDividends) ?? 0
        usLongTermCapitalGains = try container.decodeIfPresent(Decimal.self, forKey: .usLongTermCapitalGains) ?? 0
        usShortTermCapitalGains = try container.decodeIfPresent(Decimal.self, forKey: .usShortTermCapitalGains) ?? 0
        usOtherInvestmentIncome = try container.decodeIfPresent(Decimal.self, forKey: .usOtherInvestmentIncome) ?? 0
        indiaEquityLTCG = try container.decodeIfPresent(Decimal.self, forKey: .indiaEquityLTCG) ?? 0
        indiaEquitySTCG = try container.decodeIfPresent(Decimal.self, forKey: .indiaEquitySTCG) ?? 0
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(usQualifiedDividends, forKey: .usQualifiedDividends)
        try container.encode(usLongTermCapitalGains, forKey: .usLongTermCapitalGains)
        try container.encode(usShortTermCapitalGains, forKey: .usShortTermCapitalGains)
        try container.encode(usOtherInvestmentIncome, forKey: .usOtherInvestmentIncome)
        try container.encode(indiaEquityLTCG, forKey: .indiaEquityLTCG)
        try container.encode(indiaEquitySTCG, forKey: .indiaEquitySTCG)
    }
}

// MARK: - Tax Estimate Results

/// One tax slab's contribution to the overall tax
struct TaxBracketResult: Sendable, Identifiable {
    nonisolated let id: UUID
    /// e.g. "₹3L – ₹7L" or "$11,601 – $47,150"
    nonisolated let label: String
    /// Rate as a whole number percent e.g. 5, 10, 20, 30
    nonisolated let ratePercent: Decimal
    nonisolated let taxableAmount: Decimal
    nonisolated let taxAmount: Decimal

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

/// Additional line items (FICA, NIIT, special rates, contribution headroom — TAX-12 / TAX-13).
struct TaxSupplementaryLine: Sendable, Identifiable, Hashable {
    nonisolated let id: UUID
    nonisolated let title: String
    nonisolated let amount: Decimal

    nonisolated init(id: UUID = UUID(), title: String, amount: Decimal) {
        self.id = id
        self.title = title
        self.amount = amount
    }
}

/// Computed tax breakdown for a TaxProfile
struct TaxEstimate: Sendable {
    nonisolated let grossIncome: Decimal
    nonisolated let standardDeduction: Decimal
    nonisolated let customDeductionsTotal: Decimal
    nonisolated let taxableIncome: Decimal
    /// One entry per non-zero bracket
    nonisolated let bracketResults: [TaxBracketResult]
    nonisolated let basicTax: Decimal
    /// Section 87A rebate (India) or equivalent
    nonisolated let rebate: Decimal
    nonisolated let surcharge: Decimal
    /// India: 4% health & education cess; US: 0
    nonisolated let cess: Decimal
    nonisolated let finalTax: Decimal
    nonisolated let effectiveRate: Decimal
    nonisolated let marginalRate: Decimal
    nonisolated let country: TaxCountry
    /// e.g. "New Regime", "Old Regime", "Single"
    nonisolated let regimeLabel: String
    /// FICA, NIIT, capital gains, contribution advisory lines, etc.
    nonisolated let supplementaryLines: [TaxSupplementaryLine]
    nonisolated let assumptions: [String]
    nonisolated let warnings: [String]
    nonisolated let exclusions: [String]
    nonisolated let disclaimerKey: String
    /// e.g. `US_FEDERAL_TY2026` / `IN_FY2025_26` (TAX-07 / TAX-14)
    nonisolated let ruleSetID: String
    nonisolated let rulesLastUpdated: Date

    nonisolated var totalDeductions: Decimal { standardDeduction + customDeductionsTotal }

    nonisolated init(
        grossIncome: Decimal,
        standardDeduction: Decimal,
        customDeductionsTotal: Decimal,
        taxableIncome: Decimal,
        bracketResults: [TaxBracketResult],
        basicTax: Decimal,
        rebate: Decimal,
        surcharge: Decimal,
        cess: Decimal,
        finalTax: Decimal,
        effectiveRate: Decimal,
        marginalRate: Decimal,
        country: TaxCountry,
        regimeLabel: String,
        supplementaryLines: [TaxSupplementaryLine] = [],
        assumptions: [String] = [],
        warnings: [String] = [],
        exclusions: [String] = [],
        disclaimerKey: String = "tax.disclaimer.generic.v1",
        ruleSetID: String = "",
        rulesLastUpdated: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.grossIncome = grossIncome
        self.standardDeduction = standardDeduction
        self.customDeductionsTotal = customDeductionsTotal
        self.taxableIncome = taxableIncome
        self.bracketResults = bracketResults
        self.basicTax = basicTax
        self.rebate = rebate
        self.surcharge = surcharge
        self.cess = cess
        self.finalTax = finalTax
        self.effectiveRate = effectiveRate
        self.marginalRate = marginalRate
        self.country = country
        self.regimeLabel = regimeLabel
        self.supplementaryLines = supplementaryLines
        self.assumptions = assumptions
        self.warnings = warnings
        self.exclusions = exclusions
        self.disclaimerKey = disclaimerKey
        self.ruleSetID = ruleSetID
        self.rulesLastUpdated = rulesLastUpdated
    }
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
