import Foundation
import SwiftData

@ModelActor
public actor SwiftDataPayeeRepository: PayeeRepository {
    public func fetchAll() async throws -> [PayeeEntity] {
        let descriptor = FetchDescriptor<SDPayee>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(PayeeMapper.toEntity)
    }

    public func fetchByID(_ id: UUID) async throws -> PayeeEntity? {
        let descriptor = FetchDescriptor<SDPayee>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }
        return PayeeMapper.toEntity(model)
    }

    public func create(_ entity: PayeeEntity) async throws {
        let model = SDPayee(
            id: entity.id,
            name: entity.name,
            type: entity.type,
            phone: entity.phone,
            email: entity.email,
            notes: entity.notes,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
        modelContext.insert(model)
        try modelContext.save()
    }

    public func update(_ entity: PayeeEntity) async throws {
        let id = entity.id
        let descriptor = FetchDescriptor<SDPayee>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Payee not found"))
        }
        PayeeMapper.updateModel(model, from: entity)
        try modelContext.save()
    }

    public func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDPayee>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Payee not found"))
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    public func search(query: String) async throws -> [PayeeEntity] {
        let searchQuery = query
        let descriptor = FetchDescriptor<SDPayee>(
            predicate: #Predicate { payee in
                payee.name.localizedStandardContains(searchQuery)
            },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(PayeeMapper.toEntity)
    }

    public func fetchFrequent(limit: Int) async throws -> [PayeeEntity] {
        let descriptor = FetchDescriptor<SDPayee>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        var models = try modelContext.fetch(descriptor)
        models = Array(models.prefix(limit))
        return models.map(PayeeMapper.toEntity)
    }
}
