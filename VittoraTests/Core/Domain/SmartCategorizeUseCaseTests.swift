import Foundation
import Testing
import VittoraCore
@testable import Vittora

final class InMemoryCategorizationRuleStore: CategorizationRuleStoring, @unchecked Sendable {
    private var rules: [CategorizationRule] = []
    private let lock = NSLock()

    func fetchAll() throws -> [CategorizationRule] {
        lock.lock()
        defer { lock.unlock() }
        return rules
    }

    func save(_ rule: CategorizationRule) throws {
        lock.lock()
        defer { lock.unlock() }
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }
    }

    func delete(id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        rules.removeAll { $0.id == id }
    }
}

@Suite("SmartCategorizeUseCase Tests")
@MainActor
struct SmartCategorizeUseCaseTests {

    private func makeUseCase(
        txRepo: MockTransactionRepository = MockTransactionRepository(),
        ruleStore: InMemoryCategorizationRuleStore = InMemoryCategorizationRuleStore(),
        categoryRepo: MockCategoryRepository = MockCategoryRepository()
    ) -> (SmartCategorizeUseCase, MockTransactionRepository, InMemoryCategorizationRuleStore, MockCategoryRepository) {
        let useCase = SmartCategorizeUseCase(
            transactionRepository: txRepo,
            ruleStore: ruleStore,
            categoryRepository: categoryRepo
        )
        return (useCase, txRepo, ruleStore, categoryRepo)
    }

    @Test("haystack combines payee, note, merchant, and OCR text")
    func haystackCombinesFields() {
        let haystack = SmartCategorizeUseCase.haystack(
            payeeName: "Starbucks",
            note: "Morning coffee",
            merchantText: "SBUX",
            rawOCRText: "Receipt total"
        )
        #expect(haystack.contains("starbucks"))
        #expect(haystack.contains("morning coffee"))
        #expect(haystack.contains("sbux"))
        #expect(haystack.contains("receipt total"))
    }

    @Test("rule match returns category before payee history")
    func ruleMatchTakesPriority() async throws {
        let (useCase, txRepo, ruleStore, categoryRepo) = makeUseCase()
        let payeeID = UUID()
        let historyCategoryID = UUID()
        let ruleCategoryID = UUID()

        try await categoryRepo.create(
            CategoryEntity(id: ruleCategoryID, name: "Dining", icon: "fork.knife", colorHex: "#FF0000", type: .expense)
        )
        try await categoryRepo.create(
            CategoryEntity(
                id: historyCategoryID,
                name: "Transport",
                icon: "car.fill",
                colorHex: "#0000FF",
                type: .expense
            )
        )

        await txRepo.seed(
            TransactionEntity(amount: 10, type: .expense, categoryID: historyCategoryID, payeeID: payeeID)
        )

        try ruleStore.save(
            CategorizationRule(keyword: "uber", categoryID: ruleCategoryID)
        )

        let result = try await useCase.execute(
            SmartCategorizeRequest(
                payeeID: payeeID,
                payeeName: "Uber Trip",
                amount: 25
            )
        )

        #expect(result == ruleCategoryID)
    }

    @Test("longer keyword wins when multiple rules match")
    func longerKeywordWins() async throws {
        let (useCase, _, ruleStore, categoryRepo) = makeUseCase()
        let shortCategoryID = UUID()
        let longCategoryID = UUID()

        try await categoryRepo.create(
            CategoryEntity(id: shortCategoryID, name: "Food", icon: "fork.knife", colorHex: "#FF0000", type: .expense)
        )
        try await categoryRepo.create(
            CategoryEntity(
                id: longCategoryID,
                name: "Groceries",
                icon: "cart.fill",
                colorHex: "#00FF00",
                type: .expense
            )
        )

        try ruleStore.save(CategorizationRule(keyword: "whole", categoryID: shortCategoryID))
        try ruleStore.save(CategorizationRule(keyword: "whole foods", categoryID: longCategoryID))

        let result = try await useCase.execute(
            SmartCategorizeRequest(
                note: "Purchase at Whole Foods Market",
                amount: 50
            )
        )

        #expect(result == longCategoryID)
    }

    @Test("falls back to payee history when no rule matches")
    func payeeHistoryFallback() async throws {
        let (useCase, txRepo, _, _) = makeUseCase()
        let payeeID = UUID()
        let categoryID = UUID()

        await txRepo.seed(
            TransactionEntity(amount: 10, type: .expense, categoryID: categoryID, payeeID: payeeID)
        )
        await txRepo.seed(
            TransactionEntity(amount: 20, type: .expense, categoryID: categoryID, payeeID: payeeID)
        )

        let result = try await useCase.execute(
            SmartCategorizeRequest(payeeID: payeeID, payeeName: "Generic Vendor", amount: 15)
        )

        #expect(result == categoryID)
    }

    @Test("disabled rules are skipped")
    func disabledRulesSkipped() async throws {
        let (useCase, txRepo, ruleStore, categoryRepo) = makeUseCase()
        let payeeID = UUID()
        let historyCategoryID = UUID()
        let ruleCategoryID = UUID()

        try await categoryRepo.create(
            CategoryEntity(id: ruleCategoryID, name: "Dining", icon: "fork.knife", colorHex: "#FF0000", type: .expense)
        )

        await txRepo.seed(
            TransactionEntity(amount: 10, type: .expense, categoryID: historyCategoryID, payeeID: payeeID)
        )

        try ruleStore.save(
            CategorizationRule(keyword: "coffee", categoryID: ruleCategoryID, isEnabled: false)
        )

        let result = try await useCase.execute(
            SmartCategorizeRequest(payeeID: payeeID, note: "Morning coffee", amount: 5)
        )

        #expect(result == historyCategoryID)
    }

    @Test("invalid category rules are skipped")
    func invalidCategorySkipped() async throws {
        let (useCase, _, ruleStore, _) = makeUseCase()
        let missingCategoryID = UUID()

        try ruleStore.save(
            CategorizationRule(keyword: "netflix", categoryID: missingCategoryID)
        )

        let result = try await useCase.execute(
            SmartCategorizeRequest(note: "Netflix subscription", amount: 15)
        )

        #expect(result == nil)
    }
}

@Suite("ManageCategorizationRulesUseCase Tests")
@MainActor
struct ManageCategorizationRulesUseCaseTests {

    @Test("save rejects empty keyword")
    func saveRejectsEmptyKeyword() async throws {
        let store = InMemoryCategorizationRuleStore()
        let categoryRepo = MockCategoryRepository()
        let useCase = ManageCategorizationRulesUseCase(ruleStore: store, categoryRepository: categoryRepo)
        let categoryID = UUID()

        try await categoryRepo.create(
            CategoryEntity(id: categoryID, name: "Food", icon: "fork.knife", colorHex: "#FF0000", type: .expense)
        )

        await #expect(throws: VittoraError.self) {
            try await useCase.save(CategorizationRule(keyword: "   ", categoryID: categoryID))
        }
    }
}
