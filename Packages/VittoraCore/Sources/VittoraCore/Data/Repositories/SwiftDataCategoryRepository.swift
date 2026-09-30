import Foundation
import SwiftData

@ModelActor
public actor SwiftDataCategoryRepository: CategoryRepository {
    public func fetchAll() async throws -> [CategoryEntity] {
        let descriptor = FetchDescriptor<SDCategory>(
            sortBy: [
                SortDescriptor(\.sortOrder, order: .forward),
                SortDescriptor(\.name, order: .forward)
            ]
        )
        return Self.uniqueEntities(try modelContext.fetch(descriptor))
    }

    public func fetchByID(_ id: UUID) async throws -> CategoryEntity? {
        let descriptor = FetchDescriptor<SDCategory>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }
        return CategoryMapper.toEntity(model)
    }

    public func create(_ entity: CategoryEntity) async throws {
        let model = SDCategory(
            id: entity.id,
            name: entity.name,
            icon: entity.icon,
            colorHex: entity.colorHex,
            type: entity.type,
            isDefault: entity.isDefault,
            sortOrder: entity.sortOrder,
            parentID: entity.parentID,
            spendingBucket: entity.spendingBucket,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
        modelContext.insert(model)
        try modelContext.save()
    }

    public func update(_ entity: CategoryEntity) async throws {
        let id = entity.id
        let descriptor = FetchDescriptor<SDCategory>(
            predicate: #Predicate { $0.id == id }
        )
        let models = try modelContext.fetch(descriptor)
        guard !models.isEmpty else {
            throw VittoraError.notFound(String(localized: "Category not found"))
        }
        for model in models {
            CategoryMapper.updateModel(model, from: entity)
        }
        try modelContext.save()
    }

    public func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDCategory>(
            predicate: #Predicate { $0.id == id }
        )
        let models = try modelContext.fetch(descriptor)
        guard !models.isEmpty else {
            throw VittoraError.notFound(String(localized: "Category not found"))
        }
        for model in models {
            modelContext.delete(model)
        }
        try modelContext.save()
    }

    public func fetchDefaults() async throws -> [CategoryEntity] {
        let descriptor = FetchDescriptor<SDCategory>(
            predicate: #Predicate { $0.isDefault == true },
            sortBy: [
                SortDescriptor(\.sortOrder, order: .forward),
                SortDescriptor(\.name, order: .forward)
            ]
        )
        return Self.uniqueEntities(try modelContext.fetch(descriptor))
    }

    public func fetchByType(_ type: CategoryType) async throws -> [CategoryEntity] {
        let typeRawValue = type.rawValue
        let descriptor = FetchDescriptor<SDCategory>(
            predicate: #Predicate { $0.typeRawValue == typeRawValue },
            sortBy: [
                SortDescriptor(\.sortOrder, order: .forward),
                SortDescriptor(\.name, order: .forward)
            ]
        )
        return Self.uniqueEntities(try modelContext.fetch(descriptor))
    }

    /// CloudKit mirroring has no unique constraints, so one category can exist as
    /// several rows with the same `id`: every device seeds the defaults with the
    /// same deterministic IDs, and a store that switches CloudKit environment
    /// (an Xcode build over the App Store one) re-imports what it already has.
    /// The launch-time seeder merges the defaults, but an import can land after
    /// it. Readers see one entity per id; update and delete act on every copy,
    /// so a deleted category cannot come back from its twin.
    private static func uniqueEntities(_ models: [SDCategory]) -> [CategoryEntity] {
        var seen = Set<UUID>()
        return models.filter { seen.insert($0.id).inserted }.map(CategoryMapper.toEntity)
    }
}
