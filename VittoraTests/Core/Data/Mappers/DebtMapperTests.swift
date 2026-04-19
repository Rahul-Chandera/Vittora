import Foundation
import Testing
import SwiftData

@testable import Vittora

@Suite("DebtMapper Tests")
struct DebtMapperTests {

    @Test("toEntity maps all fields correctly")
    func testToEntityMapsAllFields() {
        let id = UUID()
        let payeeID = UUID()
        let amount = Decimal(4500.0)
        let settledAmount = Decimal(1000.0)
        let direction = DebtDirection.borrowed
        let dueDate = Date(timeIntervalSince1970: 1_720_000_000)
        let note = "Personal loan repayment"
        let isSettled = false
        let linkedTransactionID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_001_000)

        let model = SDDebt(
            id: id,
            payeeID: payeeID,
            amount: amount,
            settledAmount: settledAmount,
            direction: direction,
            dueDate: dueDate,
            note: note,
            isSettled: isSettled,
            linkedTransactionID: linkedTransactionID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = DebtMapper.toEntity(model)

        #expect(entity.id == id)
        #expect(entity.payeeID == payeeID)
        #expect(entity.amount == amount)
        #expect(entity.settledAmount == settledAmount)
        #expect(entity.direction == direction)
        #expect(entity.dueDate == dueDate)
        #expect(entity.note == note)
        #expect(entity.isSettled == isSettled)
        #expect(entity.linkedTransactionID == linkedTransactionID)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == updatedAt)
    }

    @Test("toEntity maps optional fields as nil when absent")
    func testToEntityMapsOptionalFieldsNil() {
        let payeeID = UUID()
        let model = SDDebt(
            payeeID: payeeID,
            amount: Decimal(200),
            direction: .lent
        )

        let entity = DebtMapper.toEntity(model)

        #expect(entity.dueDate == nil)
        #expect(entity.note == nil)
        #expect(entity.linkedTransactionID == nil)
        #expect(entity.isSettled == false)
    }

    @Test("updateModel modifies mutable fields and stamps updatedAt")
    func testUpdateModelModifiesMutableFields() {
        let model = SDDebt()
        let originalID = model.id
        let originalCreatedAt = model.createdAt

        let payeeID = UUID()
        let dueDate = Date(timeIntervalSince1970: 1_730_000_000)
        let linkedTransactionID = UUID()
        let entity = DebtEntry(
            payeeID: payeeID,
            amount: Decimal(7500.0),
            settledAmount: Decimal(2500.0),
            direction: .lent,
            dueDate: dueDate,
            note: "Dinner split",
            isSettled: false,
            linkedTransactionID: linkedTransactionID
        )

        DebtMapper.updateModel(model, from: entity)

        #expect(model.id == originalID)
        #expect(model.createdAt == originalCreatedAt)
        #expect(model.payeeID == payeeID)
        #expect(model.amount == Decimal(7500.0))
        #expect(model.settledAmount == Decimal(2500.0))
        #expect(model.direction == .lent)
        #expect(model.dueDate == dueDate)
        #expect(model.note == "Dinner split")
        #expect(model.isSettled == false)
        #expect(model.linkedTransactionID == linkedTransactionID)
        #expect(model.updatedAt > originalCreatedAt)
    }

    @Test("Round-trip mapping preserves all fields")
    func testRoundTripMapping() {
        let id = UUID()
        let payeeID = UUID()
        let dueDate = Date(timeIntervalSince1970: 1_710_000_000)
        let linkedTransactionID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_695_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_695_001_000)

        let model = SDDebt(
            id: id,
            payeeID: payeeID,
            amount: Decimal(3000.0),
            settledAmount: Decimal(500.0),
            direction: .borrowed,
            dueDate: dueDate,
            note: "Car repair",
            isSettled: false,
            linkedTransactionID: linkedTransactionID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = DebtMapper.toEntity(model)
        DebtMapper.updateModel(model, from: entity)

        #expect(model.id == id)
        #expect(model.payeeID == payeeID)
        #expect(model.amount == Decimal(3000.0))
        #expect(model.settledAmount == Decimal(500.0))
        #expect(model.direction == .borrowed)
        #expect(model.dueDate == dueDate)
        #expect(model.note == "Car repair")
        #expect(model.isSettled == false)
        #expect(model.linkedTransactionID == linkedTransactionID)
        #expect(model.createdAt == createdAt)
    }

    @Test("toEntity with both debt directions")
    func testToEntityWithBothDirections() {
        let directions: [DebtDirection] = [.lent, .borrowed]

        for direction in directions {
            let model = SDDebt(payeeID: UUID(), amount: Decimal(100), direction: direction)
            let entity = DebtMapper.toEntity(model)
            #expect(entity.direction == direction)
        }
    }

    @Test("updateModel handles settled debt")
    func testUpdateModelHandlesSettledDebt() {
        let model = SDDebt()
        model.isSettled = false

        let entity = DebtEntry(
            payeeID: UUID(),
            amount: Decimal(500),
            settledAmount: Decimal(500),
            direction: .lent,
            isSettled: true
        )

        DebtMapper.updateModel(model, from: entity)

        #expect(model.isSettled == true)
        #expect(model.settledAmount == Decimal(500))
    }
}
