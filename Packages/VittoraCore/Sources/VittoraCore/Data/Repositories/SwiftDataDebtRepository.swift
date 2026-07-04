import Foundation
import SwiftData

@ModelActor
public actor SwiftDataDebtRepository: DebtRepository {
    public func fetchAll() async throws -> [DebtEntry] {
        let descriptor = FetchDescriptor<SDDebt>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(DebtMapper.toEntity)
    }

    public func fetchByID(_ id: UUID) async throws -> DebtEntry? {
        let descriptor = FetchDescriptor<SDDebt>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first.map(DebtMapper.toEntity)
    }

    public func create(_ entity: DebtEntry) async throws {
        let model = SDDebt(
            id: entity.id,
            payeeID: entity.payeeID,
            amount: entity.amount,
            settledAmount: entity.settledAmount,
            direction: entity.direction,
            dueDate: entity.dueDate,
            note: entity.note,
            isSettled: entity.isSettled,
            linkedTransactionIDs: entity.linkedTransactionIDs,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
        modelContext.insert(model)
        try modelContext.save()
    }

    public func update(_ entity: DebtEntry) async throws {
        let id = entity.id
        let descriptor = FetchDescriptor<SDDebt>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Debt entry not found"))
        }
        DebtMapper.updateModel(model, from: entity)
        try modelContext.save()
    }

    public func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDDebt>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Debt entry not found"))
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    public func fetchOutstanding() async throws -> [DebtEntry] {
        let descriptor = FetchDescriptor<SDDebt>(
            predicate: #Predicate { $0.isSettled == false },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(DebtMapper.toEntity)
    }

    public func fetchForPayee(_ payeeID: UUID) async throws -> [DebtEntry] {
        let descriptor = FetchDescriptor<SDDebt>(
            predicate: #Predicate { $0.payeeID == payeeID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(DebtMapper.toEntity)
    }

    public func fetchOverdue(before date: Date) async throws -> [DebtEntry] {
        let descriptor = FetchDescriptor<SDDebt>(
            predicate: #Predicate { $0.dueDate != nil && $0.isSettled == false },
            sortBy: [SortDescriptor(\.dueDate, order: .forward)]
        )
        let all = try modelContext.fetch(descriptor).map(DebtMapper.toEntity)
        return all.filter { ($0.dueDate ?? .distantFuture) < date }
    }
}
