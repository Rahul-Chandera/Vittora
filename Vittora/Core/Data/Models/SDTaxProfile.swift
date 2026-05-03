import Foundation
import OSLog
import SwiftData

@Model
final class SDTaxProfile {
    #Index<SDTaxProfile>([\.countryRawValue], [\.financialYear])

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
    /// JSON-encoded `TaxAdvancedInputs` (special-rate income, US NIIT/FICA bases).
    var advancedInputsJSON: String = "{}"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    private static let logger = Logger(subsystem: "com.vittora.app", category: "persistence")

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
        advancedInputs: TaxAdvancedInputs = TaxAdvancedInputs(),
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
        self.advancedInputsJSON = SDTaxProfile.encodeAdvanced(advancedInputs)
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

    var advancedInputs: TaxAdvancedInputs {
        get { SDTaxProfile.decodeAdvanced(advancedInputsJSON) }
        set { advancedInputsJSON = SDTaxProfile.encodeAdvanced(newValue) }
    }

    private static func encode(_ deductions: [TaxDeduction]) -> String {
        do {
            let data = try JSONEncoder().encode(deductions)
            guard let str = String(data: data, encoding: .utf8) else {
                logger.error("Failed to encode tax deductions as UTF-8.")
                return "[]"
            }
            return str
        } catch {
            logger.error("Failed to encode tax deductions: \(error.localizedDescription, privacy: .public)")
            return "[]"
        }
    }

    private static func decode(_ json: String) -> [TaxDeduction] {
        guard let data = json.data(using: .utf8) else {
            logger.error("Failed to decode tax deductions JSON as UTF-8.")
            return []
        }

        do {
            return try JSONDecoder().decode([TaxDeduction].self, from: data)
        } catch {
            logger.error("Failed to decode tax deductions: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private static func encodeAdvanced(_ value: TaxAdvancedInputs) -> String {
        do {
            let data = try JSONEncoder().encode(value)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            logger.error("Failed to encode advanced tax inputs: \(error.localizedDescription, privacy: .public)")
            return "{}"
        }
    }

    private static func decodeAdvanced(_ json: String) -> TaxAdvancedInputs {
        guard let data = json.data(using: .utf8) else {
            logger.error("Failed to decode advanced tax inputs as UTF-8.")
            return TaxAdvancedInputs()
        }
        do {
            return try JSONDecoder().decode(TaxAdvancedInputs.self, from: data)
        } catch {
            logger.error("Failed to decode advanced tax inputs: \(error.localizedDescription, privacy: .public)")
            return TaxAdvancedInputs()
        }
    }
}
