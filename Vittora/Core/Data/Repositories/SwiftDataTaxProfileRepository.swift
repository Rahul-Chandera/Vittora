import Foundation
import SwiftData

@ModelActor
actor SwiftDataTaxProfileRepository: TaxProfileRepository {

    func fetch() async throws -> TaxProfile? {
        let descriptor = FetchDescriptor<SDTaxProfile>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first.map(TaxProfileMapper.toEntity)
    }

    func save(_ profile: TaxProfile) async throws {
        let descriptor = FetchDescriptor<SDTaxProfile>()
        let existing = try modelContext.fetch(descriptor)

        if let model = existing.first {
            // Replace the existing profile in-place
            TaxProfileMapper.updateModel(model, from: profile)
        } else {
            // First save — create a new record
            let model = SDTaxProfile(
                id: profile.id,
                country: profile.country,
                annualIncome: profile.annualIncome,
                indiaRegime: profile.indiaRegime,
                filingStatus: profile.filingStatus,
                customDeductions: profile.customDeductions,
                financialYear: profile.financialYear,
                createdAt: profile.createdAt,
                updatedAt: profile.updatedAt
            )
            modelContext.insert(model)
        }
        try modelContext.save()
    }

    func delete() async throws {
        let descriptor = FetchDescriptor<SDTaxProfile>()
        let all = try modelContext.fetch(descriptor)
        for model in all { modelContext.delete(model) }
        try modelContext.save()
    }
}
