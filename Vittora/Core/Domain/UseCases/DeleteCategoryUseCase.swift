import Foundation
import VittoraCore

struct DeleteCategoryUseCase: Sendable {
    let categoryRepository: any CategoryRepository
    /// REQUIRED: nullifying dependent references and deleting the category must
    /// persist atomically (A10, DATAINTEGRITY-6). No repository-only fallback.
    let ledgerWriting: any LedgerWriting

    nonisolated init(
        categoryRepository: any CategoryRepository,
        ledgerWriting: any LedgerWriting
    ) {
        self.categoryRepository = categoryRepository
        self.ledgerWriting = ledgerWriting
    }

    func execute(id: UUID) async throws {
        guard let category = try await categoryRepository.fetchByID(id) else {
            throw VittoraError.notFound(String(localized: "Category not found"))
        }
        guard !category.isDefault else {
            throw VittoraError.validationFailed(
                String(localized: "Cannot delete a default category.")
            )
        }
        try await ledgerWriting.performDeleteCategory(categoryID: id)
    }
}
