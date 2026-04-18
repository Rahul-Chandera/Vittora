import Foundation
import SwiftData

@Model
final class SDTaxProfile {
    var id: UUID = UUID()
    var countryRawValue: String = TaxCountry.india.rawValue
    var annualIncome: Decimal = Decimal(0)
    var indiaRegimeRawValue: String = IndiaRegime.newRegime.rawValue
    var filingStatusRawValue: String = USFilingStatus.single.rawValue
    /// JSON-encoded [TaxDeduction]
    var deductionsJSON: String = "[]"
    var financialYear: String = TaxCountry.india.defaultFinancialYear
    var incomeSourceTypeRawValue: String = IncomeSourceType.salaried.rawValue
    var dateOfBirth: Date? = nil
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init() {}

    init(
        id: UUID = UUID(),
        country: TaxCountry,
        annualIncome: Decimal,
        indiaRegime: IndiaRegime,
        filingStatus: USFilingStatus,
        customDeductions: [TaxDeduction] = [],
        financialYear: String,
        incomeSourceType: IncomeSourceType = .salaried,
        dateOfBirth: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.countryRawValue = country.rawValue
        self.annualIncome = annualIncome
        self.indiaRegimeRawValue = indiaRegime.rawValue
        self.filingStatusRawValue = filingStatus.rawValue
        self.deductionsJSON = SDTaxProfile.encode(customDeductions)
        self.financialYear = financialYear
        self.incomeSourceTypeRawValue = incomeSourceType.rawValue
        self.dateOfBirth = dateOfBirth
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var country: TaxCountry {
        get { TaxCountry(rawValue: countryRawValue) ?? .india }
        set { countryRawValue = newValue.rawValue }
    }

    var indiaRegime: IndiaRegime {
        get { IndiaRegime(rawValue: indiaRegimeRawValue) ?? .newRegime }
        set { indiaRegimeRawValue = newValue.rawValue }
    }

    var filingStatus: USFilingStatus {
        get { USFilingStatus(rawValue: filingStatusRawValue) ?? .single }
        set { filingStatusRawValue = newValue.rawValue }
    }

    var incomeSourceType: IncomeSourceType {
        get { IncomeSourceType(rawValue: incomeSourceTypeRawValue) ?? .salaried }
        set { incomeSourceTypeRawValue = newValue.rawValue }
    }

    var customDeductions: [TaxDeduction] {
        get { SDTaxProfile.decode(deductionsJSON) }
        set { deductionsJSON = SDTaxProfile.encode(newValue) }
    }

    private static func encode(_ deductions: [TaxDeduction]) -> String {
        guard let data = try? JSONEncoder().encode(deductions),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }

    private static func decode(_ json: String) -> [TaxDeduction] {
        guard let data = json.data(using: .utf8),
              let deductions = try? JSONDecoder().decode([TaxDeduction].self, from: data) else { return [] }
        return deductions
    }
}
