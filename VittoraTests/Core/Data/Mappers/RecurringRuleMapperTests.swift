import Foundation
import Testing
import SwiftData

@testable import Vittora

@Suite("RecurringRuleMapper Tests")
struct RecurringRuleMapperTests {

    @Test("toEntity maps all fields correctly")
    func testToEntityMapsAllFields() {
        let id = UUID()
        let frequency = RecurrenceFrequency.monthly
        let nextDate = Date(timeIntervalSince1970: 1_710_000_000)
        let isActive = true
        let endDate = Date(timeIntervalSince1970: 1_750_000_000)
        let templateAmount = Decimal(1200.0)
        let templateNote = "Rent payment"
        let templateCategoryID = UUID()
        let templateAccountID = UUID()
        let templatePayeeID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_001_000)

        let model = SDRecurringRule(
            id: id,
            frequency: frequency,
            nextDate: nextDate,
            isActive: isActive,
            endDate: endDate,
            templateAmount: templateAmount,
            templateNote: templateNote,
            templateCategoryID: templateCategoryID,
            templateAccountID: templateAccountID,
            templatePayeeID: templatePayeeID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = RecurringRuleMapper.toEntity(model)

        #expect(entity.id == id)
        #expect(entity.frequency == frequency)
        #expect(entity.nextDate == nextDate)
        #expect(entity.isActive == isActive)
        #expect(entity.endDate == endDate)
        #expect(entity.templateAmount == templateAmount)
        #expect(entity.templateNote == templateNote)
        #expect(entity.templateCategoryID == templateCategoryID)
        #expect(entity.templateAccountID == templateAccountID)
        #expect(entity.templatePayeeID == templatePayeeID)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == updatedAt)
    }

    @Test("toEntity maps nil optional fields correctly")
    func testToEntityMapsNilOptionalFields() {
        let model = SDRecurringRule(
            frequency: .weekly,
            nextDate: Date(timeIntervalSince1970: 1_700_000_000),
            templateAmount: Decimal(50)
        )

        let entity = RecurringRuleMapper.toEntity(model)

        #expect(entity.endDate == nil)
        #expect(entity.templateNote == nil)
        #expect(entity.templateCategoryID == nil)
        #expect(entity.templateAccountID == nil)
        #expect(entity.templatePayeeID == nil)
    }

    @Test("updateModel modifies mutable fields and stamps updatedAt")
    func testUpdateModelModifiesMutableFields() {
        let model = SDRecurringRule()
        let originalID = model.id
        let originalCreatedAt = model.createdAt

        let nextDate = Date(timeIntervalSince1970: 1_715_000_000)
        let endDate = Date(timeIntervalSince1970: 1_760_000_000)
        let categoryID = UUID()
        let accountID = UUID()
        let payeeID = UUID()

        let entity = RecurringRuleEntity(
            frequency: .biweekly,
            nextDate: nextDate,
            isActive: false,
            endDate: endDate,
            templateAmount: Decimal(350.0),
            templateNote: "Gym membership",
            templateCategoryID: categoryID,
            templateAccountID: accountID,
            templatePayeeID: payeeID
        )

        RecurringRuleMapper.updateModel(model, from: entity)

        #expect(model.id == originalID)
        #expect(model.createdAt == originalCreatedAt)
        #expect(model.frequency == .biweekly)
        #expect(model.nextDate == nextDate)
        #expect(model.isActive == false)
        #expect(model.endDate == endDate)
        #expect(model.templateAmount == Decimal(350.0))
        #expect(model.templateNote == "Gym membership")
        #expect(model.templateCategoryID == categoryID)
        #expect(model.templateAccountID == accountID)
        #expect(model.templatePayeeID == payeeID)
        #expect(model.updatedAt > originalCreatedAt)
    }

    @Test("Round-trip mapping preserves all fields")
    func testRoundTripMapping() {
        let id = UUID()
        let nextDate = Date(timeIntervalSince1970: 1_705_000_000)
        let endDate = Date(timeIntervalSince1970: 1_740_000_000)
        let categoryID = UUID()
        let accountID = UUID()
        let payeeID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_695_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_695_001_000)

        let model = SDRecurringRule(
            id: id,
            frequency: .yearly,
            nextDate: nextDate,
            isActive: true,
            endDate: endDate,
            templateAmount: Decimal(999.0),
            templateNote: "Annual subscription",
            templateCategoryID: categoryID,
            templateAccountID: accountID,
            templatePayeeID: payeeID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = RecurringRuleMapper.toEntity(model)
        RecurringRuleMapper.updateModel(model, from: entity)

        #expect(model.id == id)
        #expect(model.frequency == .yearly)
        #expect(model.nextDate == nextDate)
        #expect(model.isActive == true)
        #expect(model.endDate == endDate)
        #expect(model.templateAmount == Decimal(999.0))
        #expect(model.templateNote == "Annual subscription")
        #expect(model.templateCategoryID == categoryID)
        #expect(model.templateAccountID == accountID)
        #expect(model.templatePayeeID == payeeID)
        #expect(model.createdAt == createdAt)
    }

    @Test("toEntity with custom frequency round-trips correctly")
    func testToEntityWithCustomFrequency() {
        let model = SDRecurringRule(
            frequency: .custom(days: 45),
            nextDate: Date(timeIntervalSince1970: 1_700_000_000),
            templateAmount: Decimal(200)
        )

        let entity = RecurringRuleMapper.toEntity(model)

        #expect(entity.frequency == .custom(days: 45))
    }

    @Test("toEntity with all standard frequencies")
    func testToEntityWithAllFrequencies() {
        let frequencies: [RecurrenceFrequency] = [.daily, .weekly, .biweekly, .monthly, .quarterly, .yearly]

        for frequency in frequencies {
            let model = SDRecurringRule(
                frequency: frequency,
                nextDate: Date(timeIntervalSince1970: 1_700_000_000),
                templateAmount: Decimal(100)
            )
            let entity = RecurringRuleMapper.toEntity(model)
            #expect(entity.frequency == frequency)
        }
    }
}
