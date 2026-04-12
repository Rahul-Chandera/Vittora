import Foundation
import SwiftData

@ModelActor
actor SwiftDataPayeeRepository: PayeeRepository {
    func fetchAll() async throws -> [PayeeEntity] {
        let descriptor = FetchDescriptor<SDPayee>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(PayeeMapper.toEntity)
    }

    func fetchByID(_ id: UUID) async throws -> PayeeEntity? {
        let descriptor = FetchDescriptor<SDPayee>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }
        return PayeeMapper.toEntity(model)
    }

    func create(_ entity: PayeeEntity) async throws {
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

    func update(_ entity: PayeeEntity) async throws {
        let descriptor = FetchDescriptor<SDPayee>(
            predicate: #Predicate { $0.id == entity.id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Payee not found"))
        }
        PayeeMapper.updateModel(model, from: entity)
        try modelContext.save()
    }

    func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDPayee>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Payee not found"))
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    func search(query: String) async throws -> [PayeeEntity] {
        let descriptor = FetchDescriptor<SDPayee>(
            predicate: #Predicate { payee in
                payee.name.localizedStandardContains(query)
            },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        let models = try modelContext.fetch(descriptor)
        return models.map(PayeeMapper.toEntity)
    }

    func fetchFrequent(limit: Int) async throws -> [PayeeEntity] {
        let descriptor = FetchDescriptor<SDPayee>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        var models = try modelContext.fetch(descriptor)
        models = Array(models.prefix(limit))
        return models.map(PayeeMapper.toEntity)
    }
}
