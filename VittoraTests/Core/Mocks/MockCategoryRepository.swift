import Foundation
import VittoraCore
@testable import Vittora

actor MockCategoryRepository: CategoryRepository {
    private(set) var categories: [CategoryEntity] = []
    var shouldThrowError: Bool = false
    var throwError: VittoraError = .unknown(String(localized: "Mock error"))
    var writeFailureControls = MockWriteFailureControls()

    private func checkWriteFailure(for entityID: UUID? = nil) throws {
        try writeFailureControls.checkWrite(entityID: entityID)
    }

    func fetchAll() async throws -> [CategoryEntity] {
        if shouldThrowError { throw throwError }
        return categories.sorted { $0.sortOrder < $1.sortOrder }
    }

    func fetchByID(_ id: UUID) async throws -> CategoryEntity? {
        if shouldThrowError { throw throwError }
        return categories.first { $0.id == id }
    }

    func create(_ entity: CategoryEntity) async throws {
        try checkWriteFailure(for: entity.id)
        if shouldThrowError { throw throwError }
        categories.append(entity)
    }

    func update(_ entity: CategoryEntity) async throws {
        try checkWriteFailure(for: entity.id)
        if shouldThrowError { throw throwError }
        if let index = categories.firstIndex(where: { $0.id == entity.id }) {
            categories[index] = entity
        } else {
            throw VittoraError.notFound(String(localized: "Category not found"))
        }
    }

    func delete(_ id: UUID) async throws {
        try checkWriteFailure(for: id)
        if shouldThrowError { throw throwError }
        if let index = categories.firstIndex(where: { $0.id == id }) {
            categories.remove(at: index)
        } else {
            throw VittoraError.notFound(String(localized: "Category not found"))
        }
    }

    func fetchDefaults() async throws -> [CategoryEntity] {
        if shouldThrowError { throw throwError }
        return categories.filter { $0.isDefault }
    }

    func fetchByType(_ type: CategoryType) async throws -> [CategoryEntity] {
        if shouldThrowError { throw throwError }
        return categories.filter { $0.type == type }.sorted { $0.sortOrder < $1.sortOrder }
    }

    // Test helpers
    func seed(_ entity: CategoryEntity) {
        categories.append(entity)
    }

    func seedMany(_ entities: [CategoryEntity]) {
        categories.append(contentsOf: entities)
    }
}
