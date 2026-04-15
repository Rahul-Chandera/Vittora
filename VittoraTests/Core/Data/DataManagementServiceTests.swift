import Testing
import Foundation
@testable import Vittora

// MARK: - Minimal mock repositories for DataManagementService

private actor MockBudgetRepo: BudgetRepository {
    var items: [BudgetEntity] = []
    func fetchAll() async throws -> [BudgetEntity] { items }
    func fetchByID(_ id: UUID) async throws -> BudgetEntity? { items.first { $0.id == id } }
    func create(_ e: BudgetEntity) async throws { items.append(e) }
    func update(_ e: BudgetEntity) async throws {
        if let i = items.firstIndex(where: { $0.id == e.id }) { items[i] = e }
    }
    func delete(_ id: UUID) async throws { items.removeAll { $0.id == id } }
    func fetchActive() async throws -> [BudgetEntity] { items.filter { !$0.isOverBudget } }
    func fetchForCategory(_ categoryID: UUID, period: BudgetPeriod) async throws -> BudgetEntity? { nil }
}

private actor MockDebtRepo: DebtRepository {
    var items: [DebtEntry] = []
    func fetchAll() async throws -> [DebtEntry] { items }
    func fetchByID(_ id: UUID) async throws -> DebtEntry? { items.first { $0.id == id } }
    func create(_ e: DebtEntry) async throws { items.append(e) }
    func update(_ e: DebtEntry) async throws {
        if let i = items.firstIndex(where: { $0.id == e.id }) { items[i] = e }
    }
    func delete(_ id: UUID) async throws { items.removeAll { $0.id == id } }
    func fetchForPayee(_ payeeID: UUID) async throws -> [DebtEntry] { [] }
    func fetchOverdue(before date: Date) async throws -> [DebtEntry] { [] }
}

private actor MockSavingsGoalRepo: SavingsGoalRepository {
    var items: [SavingsGoalEntity] = []
    func fetchAll() async throws -> [SavingsGoalEntity] { items }
    func fetchByID(_ id: UUID) async throws -> SavingsGoalEntity? { items.first { $0.id == id } }
    func fetchActive() async throws -> [SavingsGoalEntity] { items.filter { $0.status == .active } }
    func create(_ g: SavingsGoalEntity) async throws { items.append(g) }
    func update(_ g: SavingsGoalEntity) async throws {
        if let i = items.firstIndex(where: { $0.id == g.id }) { items[i] = g }
    }
    func delete(_ id: UUID) async throws { items.removeAll { $0.id == id } }
}

private actor MockSplitGroupRepo: SplitGroupRepository {
    var groups: [SplitGroup] = []
    var expenses: [GroupExpense] = []
    func fetchAllGroups() async throws -> [SplitGroup] { groups }
    func fetchGroupByID(_ id: UUID) async throws -> SplitGroup? { groups.first { $0.id == id } }
    func createGroup(_ g: SplitGroup) async throws { groups.append(g) }
    func updateGroup(_ g: SplitGroup) async throws {
        if let i = groups.firstIndex(where: { $0.id == g.id }) { groups[i] = g }
    }
    func deleteGroup(_ id: UUID) async throws { groups.removeAll { $0.id == id } }
    func fetchExpenses(forGroup groupID: UUID) async throws -> [GroupExpense] { [] }
    func fetchExpenseByID(_ id: UUID) async throws -> GroupExpense? { nil }
    func createExpense(_ e: GroupExpense) async throws { expenses.append(e) }
    func updateExpense(_ e: GroupExpense) async throws {}
    func deleteExpense(_ id: UUID) async throws { expenses.removeAll { $0.id == id } }
}

private actor MockDocumentRepo: DocumentRepository {
    var items: [DocumentEntity] = []
    func fetchAll() async throws -> [DocumentEntity] { items }
    func fetchByID(_ id: UUID) async throws -> DocumentEntity? { items.first { $0.id == id } }
    func create(_ e: DocumentEntity) async throws { items.append(e) }
    func update(_ e: DocumentEntity) async throws {}
    func delete(_ id: UUID) async throws { items.removeAll { $0.id == id } }
    func fetchForTransaction(_ transactionID: UUID) async throws -> [DocumentEntity] { [] }
}

// MARK: - Test Suite

@Suite("DataManagementService Tests")
@MainActor
struct DataManagementServiceTests {

    private func makeService() -> (
        DataManagementService,
        MockTransactionRepository,
        MockAccountRepository,
        MockCategoryRepository,
        MockBudgetRepo,
        MockDebtRepo,
        MockSavingsGoalRepo,
        MockSplitGroupRepo,
        MockDocumentRepo
    ) {
        let txRepo    = MockTransactionRepository()
        let accRepo   = MockAccountRepository()
        let catRepo   = MockCategoryRepository()
        let budRepo   = MockBudgetRepo()
        let debtRepo  = MockDebtRepo()
        let goalRepo  = MockSavingsGoalRepo()
        let splitRepo = MockSplitGroupRepo()
        let docRepo   = MockDocumentRepo()

        let service = DataManagementService(
            transactionRepository: txRepo,
            accountRepository: accRepo,
            categoryRepository: catRepo,
            budgetRepository: budRepo,
            debtRepository: debtRepo,
            savingsGoalRepository: goalRepo,
            splitGroupRepository: splitRepo,
            documentRepository: docRepo
        )
        return (service, txRepo, accRepo, catRepo, budRepo, debtRepo, goalRepo, splitRepo, docRepo)
    }

    @Test("fetchStats returns zero counts for empty repositories")
    func fetchStatsEmpty() async throws {
        let (service, _, _, _, _, _, _, _, _) = makeService()
        let stats = try await service.fetchStats()
        #expect(stats.transactionCount == 0)
        #expect(stats.accountCount == 0)
        #expect(stats.budgetCount == 0)
        #expect(stats.totalRecords == 0)
    }

    @Test("fetchStats counts transactions correctly")
    func fetchStatsTransactionCount() async throws {
        let (service, txRepo, _, _, _, _, _, _, _) = makeService()
        for i in 0..<4 {
            let tx = TransactionEntity(amount: Decimal(i), type: .expense, paymentMethod: .cash)
            try await txRepo.create(tx)
        }
        let stats = try await service.fetchStats()
        #expect(stats.transactionCount == 4)
    }

    @Test("fetchStats totalRecords sums all entities")
    func fetchStatsTotalRecords() async throws {
        let (service, txRepo, accRepo, _, _, _, _, _, _) = makeService()
        try await txRepo.create(TransactionEntity(amount: 10, type: .expense, paymentMethod: .cash))
        try await txRepo.create(TransactionEntity(amount: 20, type: .income, paymentMethod: .bankTransfer))
        try await accRepo.create(AccountEntity(name: "Wallet", type: .cash))
        let stats = try await service.fetchStats()
        #expect(stats.totalRecords == 3)
    }

    @Test("clearData(.transactions) deletes all transactions")
    func clearTransactions() async throws {
        let (service, txRepo, _, _, _, _, _, _, _) = makeService()
        for _ in 0..<3 {
            try await txRepo.create(TransactionEntity(amount: 5, type: .expense, paymentMethod: .cash))
        }
        try await service.clearData(scope: .transactions)
        let stats = try await service.fetchStats()
        #expect(stats.transactionCount == 0)
    }

    @Test("clearData(.transactions) does not delete other entities")
    func clearTransactionsKeepsAccounts() async throws {
        let (service, txRepo, accRepo, _, _, _, _, _, _) = makeService()
        try await txRepo.create(TransactionEntity(amount: 5, type: .expense, paymentMethod: .cash))
        try await accRepo.create(AccountEntity(name: "Savings", type: .bank))
        try await service.clearData(scope: .transactions)
        let stats = try await service.fetchStats()
        #expect(stats.transactionCount == 0)
        #expect(stats.accountCount == 1)
    }

    @Test("clearData(.budgets) deletes all budgets")
    func clearBudgets() async throws {
        let (service, _, _, _, budRepo, _, _, _, _) = makeService()
        try await budRepo.create(BudgetEntity(id: UUID(), amount: 500, spent: 0, period: .monthly, startDate: .now))
        try await budRepo.create(BudgetEntity(id: UUID(), amount: 1000, spent: 0, period: .weekly, startDate: .now))
        try await service.clearData(scope: .budgets)
        let stats = try await service.fetchStats()
        #expect(stats.budgetCount == 0)
    }

    @Test("clearData(.splits) deletes all split groups")
    func clearSplitGroups() async throws {
        let (service, _, _, _, _, _, _, splitRepo, _) = makeService()
        let group = SplitGroup(id: UUID(), name: "Trip", memberIDs: [UUID()])
        try await splitRepo.createGroup(group)
        try await service.clearData(scope: .splits)
        let stats = try await service.fetchStats()
        #expect(stats.splitGroupCount == 0)
    }

    @Test("clearData(.all) clears transactions, budgets, debts, goals, splits")
    func clearAll() async throws {
        let (service, txRepo, _, _, budRepo, debtRepo, goalRepo, splitRepo, _) = makeService()
        try await txRepo.create(TransactionEntity(amount: 10, type: .expense, paymentMethod: .cash))
        try await budRepo.create(BudgetEntity(id: UUID(), amount: 500, spent: 0, period: .monthly, startDate: .now))
        let goal = SavingsGoalEntity(name: "Car", category: .vehicle, targetAmount: 10000, colorHex: "#FF0000")
        try await goalRepo.create(goal)
        let group = SplitGroup(id: UUID(), name: "Friends", memberIDs: [UUID()])
        try await splitRepo.createGroup(group)

        try await service.clearData(scope: .all)

        let stats = try await service.fetchStats()
        #expect(stats.transactionCount == 0)
        #expect(stats.budgetCount == 0)
        #expect(stats.savingsGoalCount == 0)
        #expect(stats.splitGroupCount == 0)
    }

    @Test("clearData(.all) keeps accounts and categories")
    func clearAllKeepsAccountsAndCategories() async throws {
        let (service, _, accRepo, catRepo, _, _, _, _, _) = makeService()
        try await accRepo.create(AccountEntity(name: "Bank", type: .bank))
        try await catRepo.create(CategoryEntity(name: "Food", icon: "fork.knife", colorHex: "#FF0000", type: .expense))
        try await service.clearData(scope: .all)
        let stats = try await service.fetchStats()
        #expect(stats.accountCount == 1)
        #expect(stats.categoryCount == 1)
    }
}
