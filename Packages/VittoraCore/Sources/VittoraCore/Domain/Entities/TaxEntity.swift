import Foundation

// MARK: - Country & Regime

public enum TaxCountry: String, Sendable, Hashable, CaseIterable, Codable {
    case india = "IN"
    case unitedStates = "US"

    public nonisolated var displayName: String {
        switch self {
        case .india:         return String(localized: "India")
        case .unitedStates:  return String(localized: "United States")
        }
    }

    public var currencyCode: String {
        switch self {
        case .india:        return "INR"
        case .unitedStates: return "USD"
        }
    }

    public var currencySymbol: String {
        switch self {
        case .india:        return "₹"
        case .unitedStates: return "$"
        }
    }

    public nonisolated var defaultFinancialYear: String {
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

public enum IndiaRegime: String, Sendable, Hashable, CaseIterable, Codable {
    case newRegime
    case oldRegime

    public nonisolated var displayName: String {
        switch self {
        case .newRegime: return String(localized: "New Regime")
        case .oldRegime: return String(localized: "Old Regime")
        }
    }
}

public enum IncomeSourceType: String, Sendable, Hashable, CaseIterable, Codable {
    case salaried
    case selfEmployed

    public nonisolated var displayName: String {
        switch self {
        case .salaried:     return String(localized: "Salaried / Pensioner")
        case .selfEmployed: return String(localized: "Self Employed / Business")
        }
    }
}

public enum USFilingStatus: String, Sendable, Hashable, CaseIterable, Codable {
    case single
    case marriedFilingJointly
    case marriedFilingSeparately
    case headOfHousehold
    case qualifyingSurvivingSpouse

    public nonisolated var displayName: String {
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

public struct TaxDeduction: Identifiable, Hashable, Sendable, Codable {
    public nonisolated let id: UUID
    public nonisolated var name: String
    public nonisolated var amount: Decimal
    /// Section identifier e.g. "80C", "80D", "HRA"
    public nonisolated var section: String?

    public nonisolated init(id: UUID = UUID(), name: String, amount: Decimal, section: String? = nil) {
        self.id = id
        self.name = name
        self.amount = amount
        self.section = section
    }
}

// MARK: - Tax Profile

public struct TaxProfile: Identifiable, Hashable, Sendable {
    public nonisolated let id: UUID
    public nonisolated var country: TaxCountry
    public nonisolated var annualIncome: Decimal
    public nonisolated var indiaRegime: IndiaRegime
    public nonisolated var filingStatus: USFilingStatus
    public nonisolated var customDeductions: [TaxDeduction]
    /// e.g. "2025-26" (India) or "2026" (US)
    public nonisolated var financialYear: String
    /// Salary/pension vs self-employed; gates India standard deduction
    public nonisolated var incomeSourceType: IncomeSourceType
    /// Used for India old-regime senior/super-senior basic exemption tiers
    public nonisolated var dateOfBirth: Date?
    public nonisolated var createdAt: Date
    public nonisolated var updatedAt: Date

    /// Optional special-rate and payroll inputs (TAX-11 / TAX-12). Persisted as JSON on `SDTaxProfile`.
    public nonisolated var advancedInputs: TaxAdvancedInputs

    public nonisolated init(
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

public struct TaxAdvancedInputs: Sendable, Hashable, Equatable {
    /// US: qualified dividends (taxed at LTCG rates).
    public nonisolated var usQualifiedDividends: Decimal = 0
    /// US: long-term capital gains (preferential rates).
    public nonisolated var usLongTermCapitalGains: Decimal = 0
    /// US: short-term capital gains (generally ordinary rates — included in ordinary base here).
    public nonisolated var usShortTermCapitalGains: Decimal = 0
    /// US: other investment income counted toward NIIT net investment income.
    public nonisolated var usOtherInvestmentIncome: Decimal = 0
    /// India: equity LTCG taxed under Section 112A-style simplified model.
    public nonisolated var indiaEquityLTCG: Decimal = 0
    /// India: equity STCG (simplified flat rate bucket).
    public nonisolated var indiaEquitySTCG: Decimal = 0

    public nonisolated init(
        usQualifiedDividends: Decimal = 0,
        usLongTermCapitalGains: Decimal = 0,
        usShortTermCapitalGains: Decimal = 0,
        usOtherInvestmentIncome: Decimal = 0,
        indiaEquityLTCG: Decimal = 0,
        indiaEquitySTCG: Decimal = 0
    ) {
        self.usQualifiedDividends = usQualifiedDividends
        self.usLongTermCapitalGains = usLongTermCapitalGains
        self.usShortTermCapitalGains = usShortTermCapitalGains
        self.usOtherInvestmentIncome = usOtherInvestmentIncome
        self.indiaEquityLTCG = indiaEquityLTCG
        self.indiaEquitySTCG = indiaEquitySTCG
    }
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

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usQualifiedDividends = try container.decodeIfPresent(Decimal.self, forKey: .usQualifiedDividends) ?? 0
        usLongTermCapitalGains = try container.decodeIfPresent(Decimal.self, forKey: .usLongTermCapitalGains) ?? 0
        usShortTermCapitalGains = try container.decodeIfPresent(Decimal.self, forKey: .usShortTermCapitalGains) ?? 0
        usOtherInvestmentIncome = try container.decodeIfPresent(Decimal.self, forKey: .usOtherInvestmentIncome) ?? 0
        indiaEquityLTCG = try container.decodeIfPresent(Decimal.self, forKey: .indiaEquityLTCG) ?? 0
        indiaEquitySTCG = try container.decodeIfPresent(Decimal.self, forKey: .indiaEquitySTCG) ?? 0
    }

    public nonisolated func encode(to encoder: Encoder) throws {
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
public struct TaxBracketResult: Sendable, Identifiable {
    public nonisolated let id: UUID
    /// e.g. "₹3L – ₹7L" or "$11,601 – $47,150"
    public nonisolated let label: String
    /// Rate as a whole number percent e.g. 5, 10, 20, 30
    public nonisolated let ratePercent: Decimal
    public nonisolated let taxableAmount: Decimal
    public nonisolated let taxAmount: Decimal

    public nonisolated init(
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
public struct TaxSupplementaryLine: Sendable, Identifiable, Hashable {
    public nonisolated let id: UUID
    public nonisolated let title: String
    public nonisolated let amount: Decimal

    public nonisolated init(id: UUID = UUID(), title: String, amount: Decimal) {
        self.id = id
        self.title = title
        self.amount = amount
    }
}

/// Computed tax breakdown for a TaxProfile
public struct TaxEstimate: Sendable {
    public nonisolated let grossIncome: Decimal
    public nonisolated let standardDeduction: Decimal
    public nonisolated let customDeductionsTotal: Decimal
    public nonisolated let taxableIncome: Decimal
    /// One entry per non-zero bracket
    public nonisolated let bracketResults: [TaxBracketResult]
    public nonisolated let basicTax: Decimal
    /// Section 87A rebate (India) or equivalent
    public nonisolated let rebate: Decimal
    public nonisolated let surcharge: Decimal
    /// India: 4% health & education cess; US: 0
    public nonisolated let cess: Decimal
    public nonisolated let finalTax: Decimal
    public nonisolated let effectiveRate: Decimal
    public nonisolated let marginalRate: Decimal
    public nonisolated let country: TaxCountry
    /// e.g. "New Regime", "Old Regime", "Single"
    public nonisolated let regimeLabel: String
    /// FICA, NIIT, capital gains, contribution advisory lines, etc.
    public nonisolated let supplementaryLines: [TaxSupplementaryLine]
    public nonisolated let assumptions: [String]
    public nonisolated let warnings: [String]
    public nonisolated let exclusions: [String]
    public nonisolated let disclaimerKey: String
    /// e.g. `US_FEDERAL_TY2026` / `IN_FY2025_26` (TAX-07 / TAX-14)
    public nonisolated let ruleSetID: String
    public nonisolated let rulesLastUpdated: Date

    public nonisolated var totalDeductions: Decimal { standardDeduction + customDeductionsTotal }

    public nonisolated init(
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

public enum TaxComparisonKind: Sendable, Hashable {
    case indiaRegimes
    case usDeductionModes
}

public enum TaxComparisonWinner: Sendable, Hashable {
    case first
    case second
    case tie
}

public struct TaxComparison: Sendable {
    public let kind: TaxComparisonKind
    public let firstEstimate: TaxEstimate
    public let secondEstimate: TaxEstimate
    public let winner: TaxComparisonWinner
    public let savingsAmount: Decimal

    public var recommendedEstimate: TaxEstimate? {
        switch winner {
        case .first:
            firstEstimate
        case .second:
            secondEstimate
        case .tie:
            nil
        }
    }

    public init(
        kind: TaxComparisonKind,
        firstEstimate: TaxEstimate,
        secondEstimate: TaxEstimate,
        winner: TaxComparisonWinner,
        savingsAmount: Decimal
    ) {
        self.kind = kind
        self.firstEstimate = firstEstimate
        self.secondEstimate = secondEstimate
        self.winner = winner
        self.savingsAmount = savingsAmount
    }
}

// MARK: - Tax Activity Summary

public struct TaxSummaryCategory: Sendable, Identifiable {
    public var id: UUID { category.id }
    public let category: CategoryEntity
    public let totalAmount: Decimal
    public let transactionCount: Int

    public init(category: CategoryEntity, totalAmount: Decimal, transactionCount: Int) {
        self.category = category
        self.totalAmount = totalAmount
        self.transactionCount = transactionCount
    }
}

public struct TaxSummary: Sendable {
    public let financialYear: String
    public let dateRange: ClosedRange<Date>
    public let totalRelevantAmount: Decimal
    public let transactionCount: Int
    public let taxRelevantCategories: [CategoryEntity]
    public let categoryBreakdown: [TaxSummaryCategory]

    public var matchedCategoryCount: Int { categoryBreakdown.count }

    public init(
        financialYear: String,
        dateRange: ClosedRange<Date>,
        totalRelevantAmount: Decimal,
        transactionCount: Int,
        taxRelevantCategories: [CategoryEntity],
        categoryBreakdown: [TaxSummaryCategory]
    ) {
        self.financialYear = financialYear
        self.dateRange = dateRange
        self.totalRelevantAmount = totalRelevantAmount
        self.transactionCount = transactionCount
        self.taxRelevantCategories = taxRelevantCategories
        self.categoryBreakdown = categoryBreakdown
    }
}
