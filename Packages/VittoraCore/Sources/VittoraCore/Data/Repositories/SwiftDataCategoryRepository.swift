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
        let models = try modelContext.fetch(descriptor)
        return models.map(CategoryMapper.toEntity)
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
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Category not found"))
        }
        CategoryMapper.updateModel(model, from: entity)
        try modelContext.save()
    }

    public func delete(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDCategory>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Category not found"))
        }
        modelContext.delete(model)
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
        let models = try modelContext.fetch(descriptor)
        return models.map(CategoryMapper.toEntity)
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
        let models = try modelContext.fetch(descriptor)
        return models.map(CategoryMapper.toEntity)
    }
}
