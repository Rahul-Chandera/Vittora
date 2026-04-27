import Foundation
import Testing
import SwiftData

@testable import Vittora

@Suite("SavingsGoalMapper Tests")
struct SavingsGoalMapperTests {

    @Test("toEntity maps all fields correctly")
    func testToEntityMapsAllFields() {
        let id = UUID()
        let name = "Europe Trip 2026"
        let category = GoalCategory.travel
        let targetAmount = Decimal(150000.0)
        let currentAmount = Decimal(45000.0)
        let targetDate = Date(timeIntervalSince1970: 1_780_000_000)
        let linkedAccountID = UUID()
        let note = "Summer vacation fund"
        let status = GoalStatus.active
        let colorHex = "#FF9500"
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_001_000)

        let model = SDSavingsGoal(
            id: id,
            name: name,
            category: category,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            targetDate: targetDate,
            linkedAccountID: linkedAccountID,
            note: note,
            status: status,
            colorHex: colorHex,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = SavingsGoalMapper.toEntity(model)

        #expect(entity.id == id)
        #expect(entity.name == name)
        #expect(entity.category == category)
        #expect(entity.targetAmount == targetAmount)
        #expect(entity.currentAmount == currentAmount)
        #expect(entity.targetDate == targetDate)
        #expect(entity.linkedAccountID == linkedAccountID)
        #expect(entity.note == note)
        #expect(entity.status == status)
        #expect(entity.colorHex == colorHex)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == updatedAt)
    }

    @Test("toEntity maps nil optional fields correctly")
    func testToEntityMapsNilOptionalFields() {
        let model = SDSavingsGoal(
            name: "Emergency Fund",
            category: .emergency,
            targetAmount: Decimal(50000)
        )

        let entity = SavingsGoalMapper.toEntity(model)

        #expect(entity.targetDate == nil)
        #expect(entity.linkedAccountID == nil)
        #expect(entity.note == nil)
    }

    @Test("updateModel modifies mutable fields and stamps updatedAt")
    func testUpdateModelModifiesMutableFields() {
        let model = SDSavingsGoal()
        let originalID = model.id
        let originalCreatedAt = model.createdAt

        let targetDate = Date(timeIntervalSince1970: 1_800_000_000)
        let linkedAccountID = UUID()
        let entity = SavingsGoalEntity(
            name: "New Car",
            category: .vehicle,
            targetAmount: Decimal(800000.0),
            currentAmount: Decimal(200000.0),
            targetDate: targetDate,
            linkedAccountID: linkedAccountID,
            note: "Down payment savings",
            status: .active,
            colorHex: "#5AC8FA"
        )

        SavingsGoalMapper.updateModel(model, from: entity)

        #expect(model.id == originalID)
        #expect(model.createdAt == originalCreatedAt)
        #expect(model.name == "New Car")
        #expect(model.category == .vehicle)
        #expect(model.targetAmount == Decimal(800000.0))
        #expect(model.currentAmount == Decimal(200000.0))
        #expect(model.targetDate == targetDate)
        #expect(model.linkedAccountID == linkedAccountID)
        #expect(model.note == "Down payment savings")
        #expect(model.status == .active)
        #expect(model.colorHex == "#5AC8FA")
        #expect(model.updatedAt > originalCreatedAt)
    }

    @Test("Round-trip mapping preserves all fields")
    func testRoundTripMapping() {
        let id = UUID()
        let targetDate = Date(timeIntervalSince1970: 1_760_000_000)
        let linkedAccountID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_695_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_695_001_000)

        let model = SDSavingsGoal(
            id: id,
            name: "Home Down Payment",
            category: .home,
            targetAmount: Decimal(500000.0),
            currentAmount: Decimal(100000.0),
            targetDate: targetDate,
            linkedAccountID: linkedAccountID,
            note: "Dream home fund",
            status: .active,
            colorHex: "#30D158",
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = SavingsGoalMapper.toEntity(model)
        SavingsGoalMapper.updateModel(model, from: entity)

        #expect(model.id == id)
        #expect(model.name == "Home Down Payment")
        #expect(model.category == .home)
        #expect(model.targetAmount == Decimal(500000.0))
        #expect(model.currentAmount == Decimal(100000.0))
        #expect(model.targetDate == targetDate)
        #expect(model.linkedAccountID == linkedAccountID)
        #expect(model.note == "Dream home fund")
        #expect(model.status == .active)
        #expect(model.colorHex == "#30D158")
        #expect(model.createdAt == createdAt)
    }

    @Test("toEntity with all goal statuses")
    func testToEntityWithAllGoalStatuses() {
        let statuses: [GoalStatus] = [.active, .achieved, .paused, .cancelled]

        for status in statuses {
            let model = SDSavingsGoal(name: "Test", category: .other, targetAmount: Decimal(1000), status: status)
            let entity = SavingsGoalMapper.toEntity(model)
            #expect(entity.status == status)
        }
    }

    @Test("toEntity with all goal categories")
    func testToEntityWithAllGoalCategories() {
        let categories: [GoalCategory] = GoalCategory.allCases

        for category in categories {
            let model = SDSavingsGoal(name: "Test", category: category, targetAmount: Decimal(1000))
            let entity = SavingsGoalMapper.toEntity(model)
            #expect(entity.category == category)
        }
    }
}
