import Foundation
import SwiftData

@ModelActor
public actor SwiftDataInvestmentRepository: InvestmentRepository {

    public func fetchAll() async throws -> [Investment] {
        // Sorted in Swift rather than the descriptor: SwiftData puts nil first on an
        // ascending optional sort, which would float every age-linked record above the
        // ones that actually have a deadline — the opposite of what a timeline is for.
        let models = try modelContext.fetch(FetchDescriptor<SDInvestment>())
        return models.map(InvestmentMapper.toEntity).sorted { lhs, rhs in
            switch (lhs.maturityDate, rhs.maturityDate) {
            case let (l?, r?): return l == r ? lhs.name < rhs.name : l < r
            case (nil, nil): return lhs.name < rhs.name
            case (nil, _): return false
            case (_, nil): return true
            }
        }
    }

    public func save(_ investment: Investment) async throws {
        let id = investment.id
        let descriptor = FetchDescriptor<SDInvestment>(predicate: #Predicate { $0.id == id })
        if let model = try modelContext.fetch(descriptor).first {
            InvestmentMapper.updateModel(model, from: investment)
        } else {
            modelContext.insert(
                SDInvestment(
                    id: investment.id,
                    name: investment.name,
                    instrumentID: investment.instrumentID,
                    amount: investment.amount,
                    sectionKey: investment.sectionKey,
                    startDate: investment.startDate,
                    maturityDate: investment.maturityDate,
                    remindsOnMaturity: investment.remindsOnMaturity,
                    note: investment.note,
                    createdAt: investment.createdAt,
                    updatedAt: investment.updatedAt
                )
            )
        }
        try modelContext.save()
    }

    public func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<SDInvestment>(predicate: #Predicate { $0.id == id })
        for model in try modelContext.fetch(descriptor) {
            modelContext.delete(model)
        }
        try modelContext.save()
    }
}
