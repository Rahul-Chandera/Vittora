import Foundation
import SwiftData
import Testing
import VittoraCore
@testable import Vittora

@MainActor
@Suite("SyncIntegrityValidator Tests", .serialized)
struct SyncIntegrityValidatorTests {

    private func makeValidator() throws -> (ModelContainer, SyncIntegrityValidator) {
        let container = try ModelContainerConfig.makePreviewContainer()
        let validator = SyncIntegrityValidator(modelContainer: container)
        return (container, validator)
    }

    private func save(_ container: ModelContainer, _ block: (ModelContext) throws -> Void) throws {
        let ctx = ModelContext(container)
        try block(ctx)
        try ctx.save()
    }

    @Test("returns no violations for valid seeded data")
    func validDataProducesNoViolations() async throws {
        let (container, validator) = try makeValidator()
        let accountID = UUID()
        let payeeID = UUID()
        let groupID = UUID()

        try save(container) { ctx in
            ctx.insert(SDAccount(id: accountID, name: "Checking", type: .bank, balance: 500))
            ctx.insert(SDTransaction(amount: 25, accountID: accountID))
            ctx.insert(SDBudget(amount: 200, spent: 50, period: .monthly))
            ctx.insert(SDDebt(payeeID: payeeID, amount: 100, settledAmount: 40, direction: .lent))
            ctx.insert(SDGroupExpense(groupID: groupID, paidByMemberID: UUID(), amount: 60, title: "Dinner"))
        }

        let violations = await validator.validateAmountBearingEntities()
        #expect(violations.isEmpty)
    }

    @Test("flags non-finite transaction amount")
    func flagsNonFiniteTransactionAmount() async throws {
        let (container, validator) = try makeValidator()
        let txID = UUID()
        let nonFinite = Decimal(Double.nan)

        try save(container) { ctx in
            ctx.insert(SDTransaction(id: txID, amount: nonFinite))
        }

        let violations = await validator.validateAmountBearingEntities()
        #expect(violations.contains { $0.entityType == "Transaction" && $0.entityID == txID })
    }

    @Test("flags invalid transaction currency code")
    func flagsInvalidTransactionCurrency() async throws {
        let (container, validator) = try makeValidator()
        let txID = UUID()

        try save(container) { ctx in
            ctx.insert(SDTransaction(id: txID, amount: 10, currencyCode: "US"))
        }

        let violations = await validator.validateAmountBearingEntities()
        #expect(violations.contains { $0.entityType == "Transaction" && $0.entityID == txID })
    }

    @Test("flags negative asset account balance")
    func flagsNegativeAssetBalance() async throws {
        let (container, validator) = try makeValidator()
        let accountID = UUID()

        try save(container) { ctx in
            ctx.insert(SDAccount(id: accountID, name: "Overdrawn", type: .bank, balance: -1))
        }

        let violations = await validator.validateAmountBearingEntities()
        #expect(violations.contains { $0.entityType == "Account" && $0.entityID == accountID })
    }

    @Test("flags invalid account currency code")
    func flagsInvalidAccountCurrency() async throws {
        let (container, validator) = try makeValidator()
        let accountID = UUID()

        try save(container) { ctx in
            ctx.insert(SDAccount(id: accountID, name: "Bad Currency", type: .bank, currencyCode: ""))
        }

        let violations = await validator.validateAmountBearingEntities()
        #expect(violations.contains { $0.entityType == "Account" && $0.entityID == accountID })
    }

    @Test("flags non-positive budget limit")
    func flagsNonPositiveBudget() async throws {
        let (container, validator) = try makeValidator()
        let budgetID = UUID()

        try save(container) { ctx in
            ctx.insert(SDBudget(id: budgetID, amount: 0, spent: 0, period: .monthly))
        }

        let violations = await validator.validateAmountBearingEntities()
        #expect(violations.contains { $0.entityType == "Budget" && $0.entityID == budgetID })
    }

    @Test("flags over-settled debt")
    func flagsOverSettledDebt() async throws {
        let (container, validator) = try makeValidator()
        let debtID = UUID()

        try save(container) { ctx in
            ctx.insert(SDDebt(
                id: debtID,
                payeeID: UUID(),
                amount: 100,
                settledAmount: 150,
                direction: .borrowed
            ))
        }

        let violations = await validator.validateAmountBearingEntities()
        #expect(violations.contains { $0.entityType == "Debt" && $0.entityID == debtID })
    }

    @Test("flags non-positive group expense amount")
    func flagsNonPositiveGroupExpense() async throws {
        let (container, validator) = try makeValidator()
        let expenseID = UUID()

        try save(container) { ctx in
            ctx.insert(SDGroupExpense(id: expenseID, groupID: UUID(), paidByMemberID: UUID(), amount: 0, title: "Split"))
        }

        let violations = await validator.validateAmountBearingEntities()
        #expect(violations.contains { $0.entityType == "Group Expense" && $0.entityID == expenseID })
    }
}
