import Foundation
import OSLog
import SwiftData

@Model
public final class SDTaxProfile {
    #Index<SDTaxProfile>([\.countryRawValue], [\.financialYear])

    public var id: UUID = UUID()
    public var countryRawValue: String = TaxCountry.india.rawValue
    public var annualIncome: Decimal = Decimal(0)
    public var indiaRegimeRawValue: String = IndiaRegime.newRegime.rawValue
    public var filingStatusRawValue: String = USFilingStatus.single.rawValue
    /// JSON-encoded [TaxDeduction]
    public var deductionsJSON: String = "[]"
    public var financialYear: String = TaxCountry.india.defaultFinancialYear
    public var incomeSourceTypeRawValue: String = IncomeSourceType.salaried.rawValue
    public var dateOfBirth: Date? = nil
    /// JSON-encoded `TaxAdvancedInputs` (special-rate income, US NIIT/FICA bases).
    public var advancedInputsJSON: String = "{}"
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    private static let logger = Logger(subsystem: "com.vittora.app", category: "persistence")

    public init() {}

    public init(
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

    public var country: TaxCountry {
        get { TaxCountry(rawValue: countryRawValue) ?? .india }
        set { countryRawValue = newValue.rawValue }
    }

    public var indiaRegime: IndiaRegime {
        get { IndiaRegime(rawValue: indiaRegimeRawValue) ?? .newRegime }
        set { indiaRegimeRawValue = newValue.rawValue }
    }

    public var filingStatus: USFilingStatus {
        get { USFilingStatus(rawValue: filingStatusRawValue) ?? .single }
        set { filingStatusRawValue = newValue.rawValue }
    }

    public var incomeSourceType: IncomeSourceType {
        get { IncomeSourceType(rawValue: incomeSourceTypeRawValue) ?? .salaried }
        set { incomeSourceTypeRawValue = newValue.rawValue }
    }

    public var customDeductions: [TaxDeduction] {
        get { SDTaxProfile.decode(deductionsJSON) }
        set { deductionsJSON = SDTaxProfile.encode(newValue) }
    }

    public var advancedInputs: TaxAdvancedInputs {
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
