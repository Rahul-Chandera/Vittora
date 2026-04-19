import Foundation
import Testing
import SwiftData

@testable import Vittora

@Suite("BudgetMapper Tests")
struct BudgetMapperTests {

    @Test("toEntity maps all fields correctly")
    func testToEntityMapsAllFields() {
        let id = UUID()
        let amount = Decimal(3500.0)
        let spent = Decimal(1200.0)
        let period = BudgetPeriod.quarterly
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let rollover = true
        let categoryID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_001_000)

        let model = SDBudget(
            id: id,
            amount: amount,
            spent: spent,
            period: period,
            startDate: startDate,
            rollover: rollover,
            categoryID: categoryID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = BudgetMapper.toEntity(model)

        #expect(entity.id == id)
        #expect(entity.amount == amount)
        #expect(entity.spent == spent)
        #expect(entity.period == period)
        #expect(entity.startDate == startDate)
        #expect(entity.rollover == rollover)
        #expect(entity.categoryID == categoryID)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == updatedAt)
    }

    @Test("toEntity maps nil categoryID correctly")
    func testToEntityMapsNilCategoryID() {
        let model = SDBudget(
            amount: Decimal(500),
            spent: Decimal(0),
            period: .monthly
        )

        let entity = BudgetMapper.toEntity(model)

        #expect(entity.categoryID == nil)
        #expect(entity.rollover == false)
    }

    @Test("updateModel modifies mutable fields and stamps updatedAt")
    func testUpdateModelModifiesMutableFields() {
        let model = SDBudget()
        let originalID = model.id
        let originalCreatedAt = model.createdAt

        let categoryID = UUID()
        let entity = BudgetEntity(
            amount: Decimal(2000.0),
            spent: Decimal(800.0),
            period: .yearly,
            startDate: Date(timeIntervalSince1970: 1_690_000_000),
            rollover: true,
            categoryID: categoryID
        )

        BudgetMapper.updateModel(model, from: entity)

        #expect(model.id == originalID)
        #expect(model.createdAt == originalCreatedAt)
        #expect(model.amount == Decimal(2000.0))
        #expect(model.spent == Decimal(800.0))
        #expect(model.period == .yearly)
        #expect(model.startDate == Date(timeIntervalSince1970: 1_690_000_000))
        #expect(model.rollover == true)
        #expect(model.categoryID == categoryID)
        #expect(model.updatedAt > originalCreatedAt)
    }

    @Test("Round-trip mapping preserves all fields")
    func testRoundTripMapping() {
        let id = UUID()
        let amount = Decimal(1500.0)
        let spent = Decimal(300.0)
        let period = BudgetPeriod.weekly
        let startDate = Date(timeIntervalSince1970: 1_695_000_000)
        let rollover = true
        let categoryID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_695_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_695_001_000)

        let model = SDBudget(
            id: id,
            amount: amount,
            spent: spent,
            period: period,
            startDate: startDate,
            rollover: rollover,
            categoryID: categoryID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = BudgetMapper.toEntity(model)
        BudgetMapper.updateModel(model, from: entity)

        #expect(model.id == id)
        #expect(model.amount == amount)
        #expect(model.spent == spent)
        #expect(model.period == period)
        #expect(model.startDate == startDate)
        #expect(model.rollover == rollover)
        #expect(model.categoryID == categoryID)
        #expect(model.createdAt == createdAt)
    }

    @Test("toEntity with all period types")
    func testToEntityWithAllPeriodTypes() {
        let periods: [BudgetPeriod] = [.weekly, .monthly, .quarterly, .yearly]

        for period in periods {
            let model = SDBudget(amount: Decimal(100), period: period)
            let entity = BudgetMapper.toEntity(model)
            #expect(entity.period == period)
        }
    }
}
