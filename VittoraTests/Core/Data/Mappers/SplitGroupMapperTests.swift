import Foundation
import Testing
import SwiftData

@testable import Vittora

@Suite("SplitGroupMapper Tests")
struct SplitGroupMapperTests {

    // MARK: - SplitGroupMapper

    @Test("toEntity maps all SplitGroup fields correctly")
    func testSplitGroupToEntityMapsAllFields() {
        let id = UUID()
        let name = "Weekend Getaway"
        let memberIDs = [UUID(), UUID(), UUID()]
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_001_000)

        let model = SDSplitGroup(
            id: id,
            name: name,
            memberIDs: memberIDs,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = SplitGroupMapper.toEntity(model)

        #expect(entity.id == id)
        #expect(entity.name == name)
        #expect(entity.memberIDs == memberIDs)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == updatedAt)
    }

    @Test("toEntity maps empty memberIDs correctly")
    func testSplitGroupToEntityMapsEmptyMembers() {
        let model = SDSplitGroup(name: "Empty Group", memberIDs: [])

        let entity = SplitGroupMapper.toEntity(model)

        #expect(entity.memberIDs.isEmpty)
    }

    @Test("updateModel modifies mutable SplitGroup fields and stamps updatedAt")
    func testSplitGroupUpdateModelModifiesMutableFields() {
        let model = SDSplitGroup()
        let originalID = model.id
        let originalCreatedAt = model.createdAt

        let memberIDs = [UUID(), UUID()]
        let entity = SplitGroup(
            name: "Family Trip",
            memberIDs: memberIDs
        )

        SplitGroupMapper.updateModel(model, from: entity)

        #expect(model.id == originalID)
        #expect(model.createdAt == originalCreatedAt)
        #expect(model.name == "Family Trip")
        #expect(model.memberIDs == memberIDs)
        #expect(model.updatedAt > originalCreatedAt)
    }

    @Test("Round-trip mapping preserves all SplitGroup fields")
    func testSplitGroupRoundTripMapping() {
        let id = UUID()
        let memberIDs = [UUID(), UUID(), UUID(), UUID()]
        let createdAt = Date(timeIntervalSince1970: 1_695_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_695_001_000)

        let model = SDSplitGroup(
            id: id,
            name: "Office Lunch Group",
            memberIDs: memberIDs,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = SplitGroupMapper.toEntity(model)
        SplitGroupMapper.updateModel(model, from: entity)

        #expect(model.id == id)
        #expect(model.name == "Office Lunch Group")
        #expect(model.memberIDs == memberIDs)
        #expect(model.createdAt == createdAt)
    }

    // MARK: - GroupExpenseMapper

    @Test("toEntity maps all GroupExpense fields correctly")
    func testGroupExpenseToEntityMapsAllFields() {
        let id = UUID()
        let groupID = UUID()
        let paidByMemberID = UUID()
        let amount = Decimal(3600.0)
        let title = "Hotel stay"
        let date = Date(timeIntervalSince1970: 1_705_000_000)
        let splitMethod = SplitMethod.exact
        let memberID1 = UUID()
        let memberID2 = UUID()
        let shares = [SplitShare(memberID: memberID1, amount: Decimal(1800)), SplitShare(memberID: memberID2, amount: Decimal(1800))]
        let categoryID = UUID()
        let note = "3 nights"
        let isSettled = false
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_001_000)

        let model = SDGroupExpense(
            id: id,
            groupID: groupID,
            paidByMemberID: paidByMemberID,
            amount: amount,
            title: title,
            date: date,
            splitMethod: splitMethod,
            shares: shares,
            categoryID: categoryID,
            note: note,
            isSettled: isSettled,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = GroupExpenseMapper.toEntity(model)

        #expect(entity.id == id)
        #expect(entity.groupID == groupID)
        #expect(entity.paidByMemberID == paidByMemberID)
        #expect(entity.amount == amount)
        #expect(entity.title == title)
        #expect(entity.date == date)
        #expect(entity.splitMethod == splitMethod)
        #expect(entity.shares == shares)
        #expect(entity.categoryID == categoryID)
        #expect(entity.note == note)
        #expect(entity.isSettled == isSettled)
        #expect(entity.createdAt == createdAt)
        #expect(entity.updatedAt == updatedAt)
    }

    @Test("toEntity maps nil optional GroupExpense fields correctly")
    func testGroupExpenseToEntityMapsNilOptionalFields() {
        let model = SDGroupExpense(
            groupID: UUID(),
            paidByMemberID: UUID(),
            amount: Decimal(100),
            title: "Coffee"
        )

        let entity = GroupExpenseMapper.toEntity(model)

        #expect(entity.categoryID == nil)
        #expect(entity.note == nil)
        #expect(entity.isSettled == false)
    }

    @Test("updateModel modifies mutable GroupExpense fields and stamps updatedAt")
    func testGroupExpenseUpdateModelModifiesMutableFields() {
        let model = SDGroupExpense()
        let originalID = model.id
        let originalCreatedAt = model.createdAt

        let groupID = UUID()
        let paidByMemberID = UUID()
        let date = Date(timeIntervalSince1970: 1_710_000_000)
        let memberID = UUID()
        let shares = [SplitShare(memberID: memberID, amount: Decimal(500))]
        let categoryID = UUID()

        let entity = GroupExpense(
            groupID: groupID,
            paidByMemberID: paidByMemberID,
            amount: Decimal(500.0),
            title: "Dinner at steakhouse",
            date: date,
            splitMethod: .equal,
            shares: shares,
            categoryID: categoryID,
            note: "Birthday dinner",
            isSettled: true
        )

        GroupExpenseMapper.updateModel(model, from: entity)

        #expect(model.id == originalID)
        #expect(model.createdAt == originalCreatedAt)
        #expect(model.groupID == groupID)
        #expect(model.paidByMemberID == paidByMemberID)
        #expect(model.amount == Decimal(500.0))
        #expect(model.title == "Dinner at steakhouse")
        #expect(model.date == date)
        #expect(model.splitMethod == .equal)
        #expect(model.shares == shares)
        #expect(model.categoryID == categoryID)
        #expect(model.note == "Birthday dinner")
        #expect(model.isSettled == true)
        #expect(model.updatedAt > originalCreatedAt)
    }

    @Test("Round-trip mapping preserves all GroupExpense fields")
    func testGroupExpenseRoundTripMapping() {
        let id = UUID()
        let groupID = UUID()
        let paidByMemberID = UUID()
        let date = Date(timeIntervalSince1970: 1_705_000_000)
        let memberID1 = UUID()
        let memberID2 = UUID()
        let shares = [SplitShare(memberID: memberID1, amount: Decimal(250)), SplitShare(memberID: memberID2, amount: Decimal(250))]
        let categoryID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_695_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_695_001_000)

        let model = SDGroupExpense(
            id: id,
            groupID: groupID,
            paidByMemberID: paidByMemberID,
            amount: Decimal(500.0),
            title: "Groceries run",
            date: date,
            splitMethod: .percentage,
            shares: shares,
            categoryID: categoryID,
            note: "Weekly shop",
            isSettled: false,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let entity = GroupExpenseMapper.toEntity(model)
        GroupExpenseMapper.updateModel(model, from: entity)

        #expect(model.id == id)
        #expect(model.groupID == groupID)
        #expect(model.paidByMemberID == paidByMemberID)
        #expect(model.amount == Decimal(500.0))
        #expect(model.title == "Groceries run")
        #expect(model.date == date)
        #expect(model.splitMethod == .percentage)
        #expect(model.shares == shares)
        #expect(model.categoryID == categoryID)
        #expect(model.note == "Weekly shop")
        #expect(model.isSettled == false)
        #expect(model.createdAt == createdAt)
    }

    @Test("toEntity with all split methods")
    func testGroupExpenseToEntityWithAllSplitMethods() {
        let methods: [SplitMethod] = [.equal, .percentage, .exact, .shares]

        for method in methods {
            let model = SDGroupExpense(
                groupID: UUID(),
                paidByMemberID: UUID(),
                amount: Decimal(100),
                title: "Test",
                splitMethod: method
            )
            let entity = GroupExpenseMapper.toEntity(model)
            #expect(entity.splitMethod == method)
        }
    }
}
