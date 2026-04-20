import Foundation
import SwiftData

@ModelActor
actor SwiftDataAccountRepository: AccountRepository {
    func fetchAll() async throws -> [AccountEntity] {
        let descriptor = FetchDescriptor<SDAccount>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(AccountMapper.toEntity)
    }

    func fetchActive() async throws -> [AccountEntity] {
        let descriptor = FetchDescriptor<SDAccount>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(AccountMapper.toEntity)
    }

    func fetchByID(_ id: UUID) async throws -> AccountEntity? {
        let descriptor = FetchDescriptor<SDAccount>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }
        return AccountMapper.toEntity(model)
    }

    func create(_ entity: AccountEntity) async throws {
        let model = SDAccount(
            id: entity.id,
            name: entity.name,
            type: entity.type,
            balance: entity.balance,
            currencyCode: entity.currencyCode,
            icon: entity.icon,
            isArchived: entity.isArchived,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
        modelContext.insert(model)
        try modelContext.save()
    }

    func update(_ entity: AccountEntity) async throws {
        let id = entity.id
        let descriptor = FetchDescriptor<SDAccount>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Account not found"))
        }
        AccountMapper.updateModel(model, from: entity)
        try modelContext.save()
    }

    func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDAccount>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Account not found"))
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    func fetchByType(_ type: AccountType) async throws -> [AccountEntity] {
        let typeRawValue = type.rawValue
        let descriptor = FetchDescriptor<SDAccount>(
            predicate: #Predicate { $0.typeRawValue == typeRawValue },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(AccountMapper.toEntity)
    }
}
