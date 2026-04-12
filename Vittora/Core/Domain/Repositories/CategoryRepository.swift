import Foundation

protocol CategoryRepository: Sendable {
    func fetchAll() async throws -> [CategoryEntity]
    func fetchByID(_ id: UUID) async throws -> CategoryEntity?
    func create(_ entity: CategoryEntity) async throws
    func update(_ entity: CategoryEntity) async throws
    func delete(_ id: UUID) async throws
    func fetchDefaults() async throws -> [CategoryEntity]
    func fetchByType(_ type: CategoryType) async throws -> [CategoryEntity]
}
