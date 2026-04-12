import Foundation
import Testing
import SwiftData

@testable import Vittora

@Suite("TransactionMapper Tests")
struct TransactionMapperTests {
    @Test("toEntity maps all fields correctly")
    func testToEntityMapsAllFields() {
        let id = UUID()
        let amount = Decimal(150.0)
        let date = Date()
        let note = "Test transaction"
        let categoryID = UUID()
        let accountID = UUID()
        let payeeID = UUID()
        let destinationAccountID = UUID()
        let recurringRuleID = UUID()
        let tags = ["tag1", "tag2"]
        let createdAt = Date()
        let updatedAt = Date()

        let model = SDTransaction(
            id: id,
            amount: amount,
            date: date,
            note: note,
            type: .income,
            paymentMethod: .creditCard,
            currencyCode: "EUR",
            tags: tags,
            categoryID: categoryID,
            accountID: accountID,
            payeeID: payeeID,
            destinationAccountID: destinationAccountID,
            recurringRuleID: recurringRuleID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = TransactionMapper.toEntity(model)

        #expect(entity.id == id)
        #expect(entity.amount == amount)
        #expect(entity.date == date)
        #expect(entity.note == note)
        #expect(entity.type == .income)
        #expect(entity.paymentMethod == .creditCard)
        #expect(entity.currencyCode == "EUR")
        #expect(entity.tags == tags)
        #expect(entity.categoryID == categoryID)
        #expect(entity.accountID == accountID)
        #expect(entity.payeeID == payeeID)
        #expect(entity.destinationAccountID == destinationAccountID)
        #expect(entity.recurringRuleID == recurringRuleID)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == updatedAt)
    }

    @Test("toEntity maps default values correctly")
    func testToEntityMapsDefaults() {
        let model = SDTransaction()
        model.amount = Decimal(50.0)

        let entity = TransactionMapper.toEntity(model)

        #expect(entity.amount == Decimal(50.0))
        #expect(entity.type == .expense)
        #expect(entity.paymentMethod == .cash)
        #expect(entity.currencyCode == "USD")
        #expect(entity.tags == [])
        #expect(entity.categoryID == nil)
        #expect(entity.accountID == nil)
        #expect(entity.payeeID == nil)
        #expect(entity.destinationAccountID == nil)
        #expect(entity.recurringRuleID == nil)
    }

    @Test("toEntity with nil optional fields")
    func testToEntityWithNilOptionals() {
        let model = SDTransaction()
        model.amount = Decimal(100.0)
        model.note = nil
        model.categoryID = nil
        model.accountID = nil

        let entity = TransactionMapper.toEntity(model)

        #expect(entity.note == nil)
        #expect(entity.categoryID == nil)
        #expect(entity.accountID == nil)
    }

    @Test("updateModel modifies all fields")
    func testUpdateModelModifiesAllFields() {
        let model = SDTransaction()
        let originalID = model.id
        let originalCreatedAt = model.createdAt

        let entity = TransactionEntity(
            amount: Decimal(200.0),
            date: Date(),
            note: "Updated",
            type: .transfer,
            paymentMethod: .bankTransfer,
            currencyCode: "GBP",
            tags: ["updated"],
            categoryID: UUID(),
            accountID: UUID(),
            payeeID: UUID(),
            destinationAccountID: UUID(),
            recurringRuleID: UUID()
        )

        TransactionMapper.updateModel(model, from: entity)

        #expect(model.id == originalID)
        #expect(model.amount == Decimal(200.0))
        #expect(model.note == "Updated")
        #expect(model.type == .transfer)
        #expect(model.paymentMethod == .bankTransfer)
        #expect(model.currencyCode == "GBP")
        #expect(model.tags == ["updated"])
        #expect(model.categoryID == entity.categoryID)
        #expect(model.accountID == entity.accountID)
        #expect(model.payeeID == entity.payeeID)
        #expect(model.destinationAccountID == entity.destinationAccountID)
        #expect(model.recurringRuleID == entity.recurringRuleID)
        #expect(model.createdAt == originalCreatedAt)
        #expect(model.updatedAt > originalCreatedAt)
    }

    @Test("updateModel with nil values")
    func testUpdateModelWithNilValues() {
        let model = SDTransaction()
        model.amount = Decimal(50.0)
        model.note = "Original"
        model.categoryID = UUID()

        let entity = TransactionEntity(
            amount: Decimal(100.0),
            note: nil,
            categoryID: nil
        )

        TransactionMapper.updateModel(model, from: entity)

        #expect(model.amount == Decimal(100.0))
        #expect(model.note == nil)
        #expect(model.categoryID == nil)
    }

    @Test("Round-trip mapping preserves data")
    func testRoundTripMapping() {
        let amount = Decimal(250.0)
        let note = "Round trip test"
        let type = TransactionType.expense
        let paymentMethod = PaymentMethod.debitCard
        let tags = ["test", "roundtrip"]
        let categoryID = UUID()

        let model = SDTransaction(
            amount: amount,
            note: note,
            type: type,
            paymentMethod: paymentMethod,
            tags: tags,
            categoryID: categoryID
        )

        let entity = TransactionMapper.toEntity(model)

        #expect(entity.amount == amount)
        #expect(entity.note == note)
        #expect(entity.type == type)
        #expect(entity.paymentMethod == paymentMethod)
        #expect(entity.tags == tags)
        #expect(entity.categoryID == categoryID)
    }

    @Test("toEntity handles empty tags")
    func testToEntityHandlesEmptyTags() {
        let model = SDTransaction()
        model.amount = Decimal(50.0)
        model.tags = []

        let entity = TransactionMapper.toEntity(model)

        #expect(entity.tags == [])
    }

    @Test("Different transaction types map correctly")
    func testDifferentTypesMapCorrectly() {
        let types: [TransactionType] = [.expense, .income, .transfer, .adjustment]

        for type in types {
            let model = SDTransaction()
            model.amount = Decimal(50.0)
            model.type = type

            let entity = TransactionMapper.toEntity(model)

            #expect(entity.type == type)
        }
    }

    @Test("Different payment methods map correctly")
    func testDifferentPaymentMethodsMapCorrectly() {
        let methods: [PaymentMethod] = [.cash, .creditCard, .debitCard, .bankTransfer, .upi, .wallet, .other]

        for method in methods {
            let model = SDTransaction()
            model.amount = Decimal(50.0)
            model.paymentMethod = method

            let entity = TransactionMapper.toEntity(model)

            #expect(entity.paymentMethod == method)
        }
    }
}
