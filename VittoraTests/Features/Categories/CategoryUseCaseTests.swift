import Foundation
import Testing

@testable import Vittora

@Suite("Category Use Case Tests")
struct CategoryUseCaseTests {

    // MARK: - FetchCategoriesUseCase

    @Suite("FetchCategoriesUseCase")
    struct FetchCategoriesUseCaseTests {
        @Test("Execute returns all categories sorted by sortOrder")
        func testExecuteReturnsSorted() async throws {
            let repo = MockCategoryRepository()
            await repo.seed(CategoryEntity(id: UUID(), name: "B", icon: "tag", sortOrder: 2))
            await repo.seed(CategoryEntity(id: UUID(), name: "A", icon: "tag", sortOrder: 1))
            await repo.seed(CategoryEntity(id: UUID(), name: "C", icon: "tag", sortOrder: 3))

            let useCase = FetchCategoriesUseCase(repository: repo)
            let result = try await useCase.execute()

            #expect(result.count == 3)
            #expect(result[0].name == "A")
            #expect(result[1].name == "B")
            #expect(result[2].name == "C")
        }

        @Test("ExecuteGrouped returns expense and income categories separately")
        func testExecuteGrouped() async throws {
            let repo = MockCategoryRepository()
            await repo.seed(CategoryEntity(name: "Food", icon: "fork.knife", type: .expense, sortOrder: 1))
            await repo.seed(CategoryEntity(name: "Transport", icon: "car.fill", type: .expense, sortOrder: 2))
            await repo.seed(CategoryEntity(name: "Salary", icon: "dollarsign.circle", type: .income, sortOrder: 1))

            let useCase = FetchCategoriesUseCase(repository: repo)
            let grouped = try await useCase.executeGrouped()

            #expect(grouped.expense.count == 2)
            #expect(grouped.income.count == 1)
            #expect(grouped.expense[0].name == "Food")
            #expect(grouped.income[0].name == "Salary")
        }

        @Test("ExecuteByType returns only matching categories")
        func testExecuteByType() async throws {
            let repo = MockCategoryRepository()
            await repo.seed(CategoryEntity(name: "Food", icon: "fork.knife", type: .expense))
            await repo.seed(CategoryEntity(name: "Salary", icon: "dollarsign.circle", type: .income))

            let useCase = FetchCategoriesUseCase(repository: repo)
            let expenses = try await useCase.executeByType(.expense)

            #expect(expenses.count == 1)
            #expect(expenses[0].name == "Food")
        }
    }

    // MARK: - CreateCategoryUseCase

    @Suite("CreateCategoryUseCase")
    struct CreateCategoryUseCaseTests {
        @Test("Creates a new expense category")
        func testCreateExpenseCategory() async throws {
            let repo = MockCategoryRepository()
            let useCase = CreateCategoryUseCase(repository: repo)

            try await useCase.execute(
                name: "Groceries",
                icon: "cart.fill",
                colorHex: "#FF6B35",
                type: .expense,
                parentID: nil
            )

            let all = await repo.categories
            #expect(all.count == 1)
            #expect(all[0].name == "Groceries")
            #expect(all[0].type == .expense)
            #expect(all[0].colorHex == "#FF6B35")
        }

        @Test("Creates a new income category")
        func testCreateIncomeCategory() async throws {
            let repo = MockCategoryRepository()
            let useCase = CreateCategoryUseCase(repository: repo)

            try await useCase.execute(
                name: "Freelance",
                icon: "person.fill",
                colorHex: "#34C759",
                type: .income,
                parentID: nil
            )

            let all = await repo.categories
            #expect(all.count == 1)
            #expect(all[0].type == .income)
        }
    }

    // MARK: - DeleteCategoryUseCase

    @Suite("DeleteCategoryUseCase")
    struct DeleteCategoryUseCaseTests {
        @Test("Deletes an existing non-default category")
        func testDeleteNonDefaultCategory() async throws {
            let repo = MockCategoryRepository()
            let category = CategoryEntity(name: "Old Category", icon: "tag.fill", isDefault: false)
            await repo.seed(category)

            let useCase = DeleteCategoryUseCase(repository: repo)
            try await useCase.execute(id: category.id)

            let all = await repo.categories
            #expect(all.isEmpty)
        }

        @Test("Throws error when deleting non-existent category")
        func testThrowsWhenDeletingNonExistent() async throws {
            let repo = MockCategoryRepository()
            let useCase = DeleteCategoryUseCase(repository: repo)

            await #expect(throws: (any Error).self) {
                try await useCase.execute(id: UUID())
            }
        }
    }

    // MARK: - UpdateCategoryUseCase

    @Suite("UpdateCategoryUseCase")
    struct UpdateCategoryUseCaseTests {
        @Test("Updates category name and icon")
        func testUpdateCategory() async throws {
            let repo = MockCategoryRepository()
            var category = CategoryEntity(name: "Old Name", icon: "tag.fill")
            await repo.seed(category)

            category.name = "New Name"
            category.icon = "star.fill"

            let useCase = UpdateCategoryUseCase(repository: repo)
            try await useCase.execute(category)

            let updated = await repo.categories.first { $0.id == category.id }
            #expect(updated?.name == "New Name")
            #expect(updated?.icon == "star.fill")
        }
    }
}
