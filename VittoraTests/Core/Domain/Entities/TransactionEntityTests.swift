import Foundation
import Testing

@testable import Vittora

@MainActor
@Suite("TransactionEntity Tests")
struct TransactionEntityTests {
    @Test("Initializer with defaults")
    func testInitializerWithDefaults() {
        let amount = Decimal(50.0)
        let entity = TransactionEntity(amount: amount)

        #expect(entity.id != UUID())
        #expect(entity.amount == amount)
        #expect(entity.date <= Date.now)
        #expect(entity.note == nil)
        #expect(entity.type == .expense)
        #expect(entity.paymentMethod == .cash)
        #expect(entity.currencyCode == "USD")
        #expect(entity.tags == [])
        #expect(entity.categoryID == nil)
        #expect(entity.accountID == nil)
        #expect(entity.payeeID == nil)
        #expect(entity.destinationAccountID == nil)
        #expect(entity.recurringRuleID == nil)
        #expect(entity.documentIDs == [])
    }

    @Test("Initializer with all parameters")
    func testInitializerWithAllParameters() {
        let id = UUID()
        let amount = Decimal(100.0)
        let date = Date()
        let note = "Test transaction"
        let type = TransactionType.income
        let paymentMethod = PaymentMethod.creditCard
        let currencyCode = "EUR"
        let tags = ["tag1", "tag2"]
        let categoryID = UUID()
        let accountID = UUID()
        let payeeID = UUID()
        let destinationAccountID = UUID()
        let recurringRuleID = UUID()
        let documentIDs = [UUID(), UUID()]
        let createdAt = Date()
        let updatedAt = Date()

        let entity = TransactionEntity(
            id: id,
            amount: amount,
            date: date,
            note: note,
            type: type,
            paymentMethod: paymentMethod,
            currencyCode: currencyCode,
            tags: tags,
            categoryID: categoryID,
            accountID: accountID,
            payeeID: payeeID,
            destinationAccountID: destinationAccountID,
            recurringRuleID: recurringRuleID,
            documentIDs: documentIDs,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        #expect(entity.id == id)
        #expect(entity.amount == amount)
        #expect(entity.date == date)
        #expect(entity.note == note)
        #expect(entity.type == type)
        #expect(entity.paymentMethod == paymentMethod)
        #expect(entity.currencyCode == currencyCode)
        #expect(entity.tags == tags)
        #expect(entity.categoryID == categoryID)
        #expect(entity.accountID == accountID)
        #expect(entity.payeeID == payeeID)
        #expect(entity.destinationAccountID == destinationAccountID)
        #expect(entity.recurringRuleID == recurringRuleID)
        #expect(entity.documentIDs == documentIDs)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == updatedAt)
    }

    @Test("Equatable conformance")
    func testEquatable() {
        let id = UUID()
        let entity1 = TransactionEntity(
            id: id,
            amount: Decimal(50.0),
            type: .expense
        )
        let entity2 = TransactionEntity(
            id: id,
            amount: Decimal(50.0),
            type: .expense
        )
        let entity3 = TransactionEntity(
            id: UUID(),
            amount: Decimal(50.0),
            type: .expense
        )

        #expect(entity1 == entity2)
        #expect(entity1 != entity3)
    }

    @Test("Hashable conformance")
    func testHashable() {
        let id = UUID()
        let entity1 = TransactionEntity(
            id: id,
            amount: Decimal(50.0),
            type: .expense
        )
        let entity2 = TransactionEntity(
            id: id,
            amount: Decimal(50.0),
            type: .expense
        )

        var set: Set<TransactionEntity> = [entity1]
        set.insert(entity2)

        #expect(set.count == 1)
    }

    @Test("Identifiable conformance")
    func testIdentifiable() {
        let id = UUID()
        let entity = TransactionEntity(
            id: id,
            amount: Decimal(50.0)
        )

        #expect(entity.id == id)
    }

    @Test("Sendable conformance - types are Sendable")
    func testSendableConformance() {
        let entity = TransactionEntity(
            amount: Decimal(50.0),
            type: .transfer,
            paymentMethod: .bankTransfer
        )

        #expect(entity.type == .transfer)
        #expect(entity.paymentMethod == .bankTransfer)
    }
}
