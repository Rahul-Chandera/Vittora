import Foundation

// MARK: - Country & Regime

public enum TaxCountry: String, Sendable, Hashable, CaseIterable, Codable {
    case india = "IN"
    case unitedStates = "US"
    case unitedKingdom = "GB"
    case australia = "AU"
    case canada = "CA"

    public nonisolated var displayName: String {
        switch self {
        case .india:         return String(localized: "India")
        case .unitedStates:  return String(localized: "United States")
        case .unitedKingdom: return String(localized: "United Kingdom")
        case .australia:     return String(localized: "Australia")
        case .canada:        return String(localized: "Canada")
        }
    }

    public var currencyCode: String {
        switch self {
        case .india:        return "INR"
        case .unitedStates: return "USD"
        case .unitedKingdom: return "GBP"
        case .australia:     return "AUD"
        case .canada:        return "CAD"
        }
    }

    public var currencySymbol: String {
        switch self {
        case .india:        return "₹"
        case .unitedStates: return "$"
        case .unitedKingdom: return "£"
        case .australia:     return "$"
        case .canada:        return "$"
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

        case .unitedKingdom:
            // The UK tax year runs 6 April to 5 April, so the boundary is a day
            // inside April rather than the start of a month. Comparing only the
            // month would put 1-5 April in the wrong year.
            let month = calendar.component(.month, from: .now)
            let day = calendar.component(.day, from: .now)
            let startYear = (month > 4 || (month == 4 && day >= 6)) ? currentYear : currentYear - 1
            let endYearSuffix = (startYear + 1) % 100
            return "\(startYear)-\(String(format: "%02d", endYearSuffix))"

        case .australia:
            // The Australian tax year runs 1 July to 30 June.
            let month = calendar.component(.month, from: .now)
            let startYear = month >= 7 ? currentYear : currentYear - 1
            let endYearSuffix = (startYear + 1) % 100
            return "\(startYear)-\(String(format: "%02d", endYearSuffix))"

        case .canada:
            // Calendar year, like the US.
            return "\(currentYear)"
        }
    }
}

/// Canadian provinces and territories. Provincial tax is a second full bracket
/// table, not a surcharge on the federal one, so the province a user lives in
/// changes their bill by thousands rather than by a rounding amount.
public enum CAProvince: String, Sendable, Hashable, CaseIterable, Codable {
    case alberta = "AB"
    case britishColumbia = "BC"
    case manitoba = "MB"
    case newBrunswick = "NB"
    case newfoundlandAndLabrador = "NL"
    case northwestTerritories = "NT"
    case novaScotia = "NS"
    case nunavut = "NU"
    case ontario = "ON"
    case princeEdwardIsland = "PE"
    case quebec = "QC"
    case saskatchewan = "SK"
    case yukon = "YT"

    public nonisolated var displayName: String {
        switch self {
        case .alberta:                 String(localized: "Alberta")
        case .britishColumbia:         String(localized: "British Columbia")
        case .manitoba:                String(localized: "Manitoba")
        case .newBrunswick:            String(localized: "New Brunswick")
        case .newfoundlandAndLabrador: String(localized: "Newfoundland and Labrador")
        case .northwestTerritories:    String(localized: "Northwest Territories")
        case .novaScotia:              String(localized: "Nova Scotia")
        case .nunavut:                 String(localized: "Nunavut")
        case .ontario:                 String(localized: "Ontario")
        case .princeEdwardIsland:      String(localized: "Prince Edward Island")
        case .quebec:                  String(localized: "Quebec")
        case .saskatchewan:            String(localized: "Saskatchewan")
        case .yukon:                   String(localized: "Yukon")
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
    /// India old regime: annual basic salary (+ DA) for HRA exemption.
    public nonisolated var indiaBasicSalary: Decimal = 0
    /// India old regime: annual HRA received.
    public nonisolated var indiaHRAPaid: Decimal = 0
    /// India old regime: annual rent paid.
    public nonisolated var indiaRentPaid: Decimal = 0
    /// India old regime: metro city (50% salary) vs non-metro (40%).
    public nonisolated var indiaMetroCity: Bool = false
    /// India old regime: parents are senior citizens for 80D tier.
    public nonisolated var indiaParentsSeniorCitizen: Bool = false
    /// US: year-to-date 401(k) elective deferrals.
    public nonisolated var us401kYTDContributed: Decimal = 0
    /// US: year-to-date traditional/Roth IRA contributions.
    public nonisolated var usIRAYTDContributed: Decimal = 0
    /// US: year-to-date HSA contributions.
    public nonisolated var usHSAYTDContributed: Decimal = 0
    /// US: when true, HSA statutory limit uses the family tier.
    public nonisolated var usHSAFamilyCoverage: Bool = false
    /// US: Roth 401(k) deferrals are made after tax, so they must NOT reduce taxable
    /// income. Defaults to false because traditional is still the more common default on
    /// US plans — but a Roth saver who left this alone would have their tax understated,
    /// which is why it is asked rather than assumed.
    public nonisolated var us401kIsRoth: Bool = false
    /// UK: Scottish taxpayers pay Scottish rates on non-savings, non-dividend income —
    /// six bands rather than three, topping out at 48% instead of 45%. Savings and
    /// dividend income keep UK-wide rates wherever you live, which is why this flag
    /// only steers one of the three income streams in the calculator.
    public nonisolated var ukIsScottishTaxpayer: Bool = false
    /// UK: dividend income. Has its own allowance and its own three rates.
    public nonisolated var ukDividendIncome: Decimal = 0
    /// UK: savings interest. Gets the starting rate for savings and the Personal
    /// Savings Allowance, both of which depend on the other income.
    public nonisolated var ukSavingsIncome: Decimal = 0
    /// UK: chargeable capital gains after any reliefs, before the annual exempt amount.
    public nonisolated var ukCapitalGains: Decimal = 0
    /// AU: private hospital cover exempts the taxpayer from the Medicare levy
    /// surcharge. Defaults to false so the surcharge IS charged above the
    /// threshold — the direction that does not flatter the estimate. It is asked
    /// rather than assumed, for the same reason as the US Roth flag.
    public nonisolated var auHasPrivateHospitalCover: Bool = false
    /// AU: concessional (pre-tax) superannuation contributions for the year.
    public nonisolated var auConcessionalSuper: Decimal = 0
    /// AU: gross capital gain before any discount.
    public nonisolated var auCapitalGains: Decimal = 0
    /// AU: whether the asset was held more than 12 months, which halves the gain.
    public nonisolated var auCapitalGainsEligibleForDiscount: Bool = true
    /// CA: province or territory of residence on 31 December, which is what
    /// determines provincial tax. Defaults to Ontario as the most populous;
    /// the form asks rather than leaving it implicit.
    public nonisolated var caProvince: CAProvince = .ontario
    /// CA: gross capital gains; half is included in income.
    public nonisolated var caCapitalGains: Decimal = 0
    /// CA: RRSP contributions for the year, which are deductible.
    public nonisolated var caRRSPContributions: Decimal = 0

    public nonisolated init(
        usQualifiedDividends: Decimal = 0,
        usLongTermCapitalGains: Decimal = 0,
        usShortTermCapitalGains: Decimal = 0,
        usOtherInvestmentIncome: Decimal = 0,
        indiaEquityLTCG: Decimal = 0,
        indiaEquitySTCG: Decimal = 0,
        indiaBasicSalary: Decimal = 0,
        indiaHRAPaid: Decimal = 0,
        indiaRentPaid: Decimal = 0,
        indiaMetroCity: Bool = false,
        indiaParentsSeniorCitizen: Bool = false,
        us401kYTDContributed: Decimal = 0,
        usIRAYTDContributed: Decimal = 0,
        usHSAYTDContributed: Decimal = 0,
        usHSAFamilyCoverage: Bool = false,
        us401kIsRoth: Bool = false,
        ukIsScottishTaxpayer: Bool = false,
        ukDividendIncome: Decimal = 0,
        ukSavingsIncome: Decimal = 0,
        ukCapitalGains: Decimal = 0,
        auHasPrivateHospitalCover: Bool = false,
        auConcessionalSuper: Decimal = 0,
        auCapitalGains: Decimal = 0,
        auCapitalGainsEligibleForDiscount: Bool = true,
        caProvince: CAProvince = .ontario,
        caCapitalGains: Decimal = 0,
        caRRSPContributions: Decimal = 0
    ) {
        self.usQualifiedDividends = usQualifiedDividends
        self.usLongTermCapitalGains = usLongTermCapitalGains
        self.usShortTermCapitalGains = usShortTermCapitalGains
        self.usOtherInvestmentIncome = usOtherInvestmentIncome
        self.indiaEquityLTCG = indiaEquityLTCG
        self.indiaEquitySTCG = indiaEquitySTCG
        self.indiaBasicSalary = indiaBasicSalary
        self.indiaHRAPaid = indiaHRAPaid
        self.indiaRentPaid = indiaRentPaid
        self.indiaMetroCity = indiaMetroCity
        self.indiaParentsSeniorCitizen = indiaParentsSeniorCitizen
        self.us401kYTDContributed = us401kYTDContributed
        self.usIRAYTDContributed = usIRAYTDContributed
        self.usHSAYTDContributed = usHSAYTDContributed
        self.usHSAFamilyCoverage = usHSAFamilyCoverage
        self.us401kIsRoth = us401kIsRoth
        self.ukIsScottishTaxpayer = ukIsScottishTaxpayer
        self.ukDividendIncome = ukDividendIncome
        self.ukSavingsIncome = ukSavingsIncome
        self.ukCapitalGains = ukCapitalGains
        self.auHasPrivateHospitalCover = auHasPrivateHospitalCover
        self.auConcessionalSuper = auConcessionalSuper
        self.auCapitalGains = auCapitalGains
        self.auCapitalGainsEligibleForDiscount = auCapitalGainsEligibleForDiscount
        self.caProvince = caProvince
        self.caCapitalGains = caCapitalGains
        self.caRRSPContributions = caRRSPContributions
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
        case indiaBasicSalary
        case indiaHRAPaid
        case indiaRentPaid
        case indiaMetroCity
        case indiaParentsSeniorCitizen
        case us401kYTDContributed
        case usIRAYTDContributed
        case usHSAYTDContributed
        case usHSAFamilyCoverage
        case us401kIsRoth
        case ukIsScottishTaxpayer
        case ukDividendIncome
        case ukSavingsIncome
        case ukCapitalGains
        case auHasPrivateHospitalCover
        case auConcessionalSuper
        case auCapitalGains
        case auCapitalGainsEligibleForDiscount
        case caProvince
        case caCapitalGains
        case caRRSPContributions
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usQualifiedDividends = try container.decodeIfPresent(Decimal.self, forKey: .usQualifiedDividends) ?? 0
        usLongTermCapitalGains = try container.decodeIfPresent(Decimal.self, forKey: .usLongTermCapitalGains) ?? 0
        usShortTermCapitalGains = try container.decodeIfPresent(Decimal.self, forKey: .usShortTermCapitalGains) ?? 0
        usOtherInvestmentIncome = try container.decodeIfPresent(Decimal.self, forKey: .usOtherInvestmentIncome) ?? 0
        indiaEquityLTCG = try container.decodeIfPresent(Decimal.self, forKey: .indiaEquityLTCG) ?? 0
        indiaEquitySTCG = try container.decodeIfPresent(Decimal.self, forKey: .indiaEquitySTCG) ?? 0
        indiaBasicSalary = try container.decodeIfPresent(Decimal.self, forKey: .indiaBasicSalary) ?? 0
        indiaHRAPaid = try container.decodeIfPresent(Decimal.self, forKey: .indiaHRAPaid) ?? 0
        indiaRentPaid = try container.decodeIfPresent(Decimal.self, forKey: .indiaRentPaid) ?? 0
        indiaMetroCity = try container.decodeIfPresent(Bool.self, forKey: .indiaMetroCity) ?? false
        indiaParentsSeniorCitizen = try container.decodeIfPresent(Bool.self, forKey: .indiaParentsSeniorCitizen) ?? false
        us401kYTDContributed = try container.decodeIfPresent(Decimal.self, forKey: .us401kYTDContributed) ?? 0
        usIRAYTDContributed = try container.decodeIfPresent(Decimal.self, forKey: .usIRAYTDContributed) ?? 0
        usHSAYTDContributed = try container.decodeIfPresent(Decimal.self, forKey: .usHSAYTDContributed) ?? 0
        usHSAFamilyCoverage = try container.decodeIfPresent(Bool.self, forKey: .usHSAFamilyCoverage) ?? false
        // decodeIfPresent, like every key here: a profile saved before this field existed
        // must keep decoding, and a synthesised Codable would throw on the missing key even
        // with a default on the property.
        us401kIsRoth = try container.decodeIfPresent(Bool.self, forKey: .us401kIsRoth) ?? false
        ukIsScottishTaxpayer = try container.decodeIfPresent(Bool.self, forKey: .ukIsScottishTaxpayer) ?? false
        ukDividendIncome = try container.decodeIfPresent(Decimal.self, forKey: .ukDividendIncome) ?? 0
        ukSavingsIncome = try container.decodeIfPresent(Decimal.self, forKey: .ukSavingsIncome) ?? 0
        ukCapitalGains = try container.decodeIfPresent(Decimal.self, forKey: .ukCapitalGains) ?? 0
        auHasPrivateHospitalCover = try container.decodeIfPresent(Bool.self, forKey: .auHasPrivateHospitalCover) ?? false
        auConcessionalSuper = try container.decodeIfPresent(Decimal.self, forKey: .auConcessionalSuper) ?? 0
        auCapitalGains = try container.decodeIfPresent(Decimal.self, forKey: .auCapitalGains) ?? 0
        // Defaults true: the discount applies to most gains, and a profile saved
        // before this field existed should keep the common case.
        auCapitalGainsEligibleForDiscount = try container.decodeIfPresent(Bool.self, forKey: .auCapitalGainsEligibleForDiscount) ?? true
        caProvince = try container.decodeIfPresent(CAProvince.self, forKey: .caProvince) ?? .ontario
        caCapitalGains = try container.decodeIfPresent(Decimal.self, forKey: .caCapitalGains) ?? 0
        caRRSPContributions = try container.decodeIfPresent(Decimal.self, forKey: .caRRSPContributions) ?? 0
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(usQualifiedDividends, forKey: .usQualifiedDividends)
        try container.encode(usLongTermCapitalGains, forKey: .usLongTermCapitalGains)
        try container.encode(usShortTermCapitalGains, forKey: .usShortTermCapitalGains)
        try container.encode(usOtherInvestmentIncome, forKey: .usOtherInvestmentIncome)
        try container.encode(indiaEquityLTCG, forKey: .indiaEquityLTCG)
        try container.encode(indiaEquitySTCG, forKey: .indiaEquitySTCG)
        try container.encode(indiaBasicSalary, forKey: .indiaBasicSalary)
        try container.encode(indiaHRAPaid, forKey: .indiaHRAPaid)
        try container.encode(indiaRentPaid, forKey: .indiaRentPaid)
        try container.encode(indiaMetroCity, forKey: .indiaMetroCity)
        try container.encode(indiaParentsSeniorCitizen, forKey: .indiaParentsSeniorCitizen)
        try container.encode(us401kYTDContributed, forKey: .us401kYTDContributed)
        try container.encode(usIRAYTDContributed, forKey: .usIRAYTDContributed)
        try container.encode(usHSAYTDContributed, forKey: .usHSAYTDContributed)
        try container.encode(usHSAFamilyCoverage, forKey: .usHSAFamilyCoverage)
        try container.encode(us401kIsRoth, forKey: .us401kIsRoth)
        try container.encode(ukIsScottishTaxpayer, forKey: .ukIsScottishTaxpayer)
        try container.encode(ukDividendIncome, forKey: .ukDividendIncome)
        try container.encode(ukSavingsIncome, forKey: .ukSavingsIncome)
        try container.encode(ukCapitalGains, forKey: .ukCapitalGains)
        try container.encode(auHasPrivateHospitalCover, forKey: .auHasPrivateHospitalCover)
        try container.encode(auConcessionalSuper, forKey: .auConcessionalSuper)
        try container.encode(auCapitalGains, forKey: .auCapitalGains)
        try container.encode(auCapitalGainsEligibleForDiscount, forKey: .auCapitalGainsEligibleForDiscount)
        try container.encode(caProvince, forKey: .caProvince)
        try container.encode(caCapitalGains, forKey: .caCapitalGains)
        try container.encode(caRRSPContributions, forKey: .caRRSPContributions)
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
    /// A FRACTION of income, not a percentage: 0.2958 means 29.58%.
    ///
    /// Every display site multiplies by 100. UK, Australia and Canada each
    /// shipped this as a percentage instead, so their effective rate read 100x
    /// high on every surface — 2,958.0% for a UK salary of 85,000. Nothing
    /// caught it because the only assertions were the zero-income cases, which
    /// hold under either convention.
    public nonisolated let effectiveRate: Decimal
    /// A percentage, unlike `effectiveRate`: 40 means 40%.
    public nonisolated let marginalRate: Decimal

    /// `rebate`, `surcharge` and `cess` are generic slots, and each country
    /// fills them with something different. These name what THIS estimate put
    /// in them, so a screen can label the figure it is showing.
    ///
    /// Without them every country borrowed India's vocabulary: a Canadian
    /// estimate showed its basic personal amount credits as "87A Rebate" — a
    /// section of the *Indian* Income Tax Act — its provincial tax as
    /// "Surcharge", and its CPP + EI as "Cess (4%)". An Australian saw the 2%
    /// Medicare levy labelled "Cess (4%)" too.
    ///
    /// Exhaustive with no `default`, so a new country has to decide rather than
    /// silently inheriting India's wording again.
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
    /// Scotland versus the rest of the UK. Unlike the other two this is NOT a choice
    /// the taxpayer makes — it follows where they live — so it is presented as a
    /// difference, never as a recommendation.
    case ukRegions
    /// Australia: holding private hospital cover versus paying the Medicare levy
    /// surcharge. Unlike ukRegions this IS a choice, so a recommendation is fair —
    /// though the surcharge saved is not the whole picture, since cover costs a
    /// premium the estimate cannot know.
    case auPrivateCover
    /// Canada: the effect of the RRSP contribution entered, against none. A real
    /// choice and the largest lever most Canadians have, so a recommendation is
    /// fair — but it is a deferral rather than a saving, and the view says so.
    case caRRSPImpact
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
