import Foundation
import Testing
import VittoraCore

@testable import Vittora

@MainActor
@Suite("BudgetEntity Tests")
struct BudgetEntityTests {
    @Test("Remaining calculation - spent less than amount")
    func testRemainingWhenSpentLessThanAmount() {
        let entity = BudgetEntity(
            amount: Decimal(1000.0),
            spent: Decimal(350.0)
        )

        #expect(entity.remaining == Decimal(650.0))
    }

    @Test("Remaining calculation - spent equals amount")
    func testRemainingWhenSpentEqualsAmount() {
        let entity = BudgetEntity(
            amount: Decimal(500.0),
            spent: Decimal(500.0)
        )

        #expect(entity.remaining == Decimal(0.0))
    }

    @Test("Remaining calculation - spent more than amount")
    func testRemainingWhenSpentMoreThanAmount() {
        let entity = BudgetEntity(
            amount: Decimal(500.0),
            spent: Decimal(750.0)
        )

        #expect(entity.remaining == Decimal(-250.0))
    }

    @Test("Progress calculation - no spending")
    func testProgressWithNoSpending() {
        let entity = BudgetEntity(
            amount: Decimal(1000.0),
            spent: Decimal(0.0)
        )

        #expect(entity.progress == 0.0)
    }

    @Test("Progress calculation - half spent")
    func testProgressWhenHalfSpent() {
        let entity = BudgetEntity(
            amount: Decimal(1000.0),
            spent: Decimal(500.0)
        )

        #expect(entity.progress == 0.5)
    }

    @Test("Progress calculation - fully spent")
    func testProgressWhenFullySpent() {
        let entity = BudgetEntity(
            amount: Decimal(1000.0),
            spent: Decimal(1000.0)
        )

        #expect(entity.progress == 1.0)
    }

    @Test("Progress calculation - overspent")
    func testProgressWhenOverspent() {
        let entity = BudgetEntity(
            amount: Decimal(1000.0),
            spent: Decimal(1500.0)
        )

        #expect(entity.progress == 1.5)
    }

    @Test("Progress calculation - capped at 2.0")
    func testProgressCapAtTwoWhenGreatlyOverspent() {
        let entity = BudgetEntity(
            amount: Decimal(1000.0),
            spent: Decimal(3000.0)
        )

        #expect(entity.progress == 2.0)
    }

    @Test("Progress calculation - zero amount")
    func testProgressWithZeroAmount() {
        let entity = BudgetEntity(
            amount: Decimal(0.0),
            spent: Decimal(100.0)
        )

        #expect(entity.progress == 0.0)
    }

    @Test("isOverBudget when not over")
    func testIsOverBudgetWhenNotOver() {
        let entity = BudgetEntity(
            amount: Decimal(1000.0),
            spent: Decimal(800.0)
        )

        #expect(entity.isOverBudget == false)
    }

    @Test("isOverBudget when exactly at limit")
    func testIsOverBudgetWhenAtLimit() {
        let entity = BudgetEntity(
            amount: Decimal(1000.0),
            spent: Decimal(1000.0)
        )

        #expect(entity.isOverBudget == false)
    }

    @Test("isOverBudget when over")
    func testIsOverBudgetWhenOver() {
        let entity = BudgetEntity(
            amount: Decimal(1000.0),
            spent: Decimal(1001.0)
        )

        #expect(entity.isOverBudget == true)
    }

    @Test("Default initializer values")
    func testDefaultInitializerValues() {
        let entity = BudgetEntity(
            amount: Decimal(500.0)
        )

        #expect(entity.period == .monthly)
        #expect(entity.rollover == false)
        #expect(entity.categoryID == nil)
    }

    @Test("Custom period initialization")
    func testCustomPeriodInitialization() {
        let entity = BudgetEntity(
            amount: Decimal(1000.0),
            spent: Decimal(500.0),
            period: .quarterly
        )

        #expect(entity.period == .quarterly)
    }

    @Test("Identifiable conformance")
    func testIdentifiable() {
        let id = UUID()
        let entity = BudgetEntity(
            id: id,
            amount: Decimal(1000.0)
        )

        #expect(entity.id == id)
    }

    @Test("Equatable conformance")
    func testEquatable() {
        // Value equality: same id AND same content. `startDate` is pinned
        // because it defaults to .now, so two fixtures built a moment apart
        // are genuinely different values.
        let id = UUID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let entity1 = BudgetEntity(
            id: id, amount: Decimal(1000.0), spent: Decimal(500.0), startDate: start
        )
        let entity2 = BudgetEntity(
            id: id, amount: Decimal(1000.0), spent: Decimal(500.0), startDate: start
        )

        #expect(entity1 == entity2)

        // The property the UI depends on: a changed `spent` must NOT compare
        // equal. An id-only `==` here made SwiftUI skip re-rendering the budget
        // row, so it showed a stale figure until the app was relaunched.
        let spentMore = BudgetEntity(
            id: id, amount: Decimal(1000.0), spent: Decimal(620.0), startDate: start
        )
        #expect(entity1 != spentMore)
    }

    @Test("Hashable conformance")
    func testHashable() {
        // Hash is id-only by design, so equal values share a bucket and
        // Set/Dictionary membership stays stable as mutable fields change.
        let id = UUID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let entity1 = BudgetEntity(id: id, amount: Decimal(1000.0), startDate: start)
        let entity2 = BudgetEntity(id: id, amount: Decimal(1000.0), startDate: start)

        var set: Set<BudgetEntity> = [entity1]
        set.insert(entity2)

        #expect(set.count == 1)
    }
}
