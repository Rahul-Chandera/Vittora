import Foundation

enum TaxProfileMapper {
    nonisolated static func toEntity(_ model: SDTaxProfile) -> TaxProfile {
        TaxProfile(
            id: model.id,
            country: model.country,
            annualIncome: model.annualIncome,
            indiaRegime: model.indiaRegime,
            filingStatus: model.filingStatus,
            customDeductions: model.customDeductions,
            financialYear: model.financialYear,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    nonisolated static func updateModel(_ model: SDTaxProfile, from entity: TaxProfile) {
        model.country = entity.country
        model.annualIncome = entity.annualIncome
        model.indiaRegime = entity.indiaRegime
        model.filingStatus = entity.filingStatus
        model.customDeductions = entity.customDeductions
        model.financialYear = entity.financialYear
        model.updatedAt = .now
    }
}
