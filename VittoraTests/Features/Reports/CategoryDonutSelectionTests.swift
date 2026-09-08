import Foundation
import Testing
import VittoraCore

@testable import Vittora

/// Selecting a sector of the category donut.
///
/// Crashed on device with `Fatal error: Index out of range` at
/// `selectedCategory = breakdowns[index].id`. `chartAngleSelection` reports a
/// position on the axis the marks are plotted against — here the summed
/// `amount` — and that value was being used as an array index. With four
/// categories totalling 3,510 the reported value ran into the thousands, so
/// the first drag past the opening sliver killed the app.
///
/// These pin the mapping the crash proved was missing: an amount along the
/// arc resolves to the sector that covers it, and never to an index.
@Suite("Category donut selection")
struct CategoryDonutSelectionTests {

    /// The data from the reported crash: 2,000 / 650 / 560 / 300 = 3,510.
    private func breakdowns() -> [CategoryBreakdown] {
        [("Groceries", "2000"), ("Shopping", "650"), ("Utilities", "560"), ("Dining", "300")]
            .map { name, amount in
                CategoryBreakdown(
                    category: CategoryEntity(name: name, icon: "tag", colorHex: "#000000", type: .expense),
                    amount: Decimal(string: amount)!,
                    percentage: 0,
                    transactionCount: 1
                )
            }
    }

    @Test("a value far beyond the element count resolves instead of crashing")
    func largeValueDoesNotCrash() {
        let data = breakdowns()
        // 2,600 is a valid point on the arc and a catastrophic array index.
        let hit = CategoryDonutSelection.category(atCumulativeAmount: 2600, in: data)
        #expect(hit?.category.name == "Shopping")
    }

    @Test("each sector's own span selects that sector")
    func spansMapToTheirSector() {
        let data = breakdowns()
        func name(_ v: Int) -> String? {
            CategoryDonutSelection.category(atCumulativeAmount: v, in: data)?.category.name
        }
        #expect(name(0) == "Groceries")       // start of the first arc
        #expect(name(1999) == "Groceries")
        #expect(name(2000) == "Groceries")    // its exact upper bound
        #expect(name(2001) == "Shopping")
        #expect(name(2650) == "Shopping")
        #expect(name(2651) == "Utilities")
        #expect(name(3210) == "Utilities")
        #expect(name(3211) == "Dining")
        #expect(name(3510) == "Dining")       // the total
    }

    @Test("a value past the total lands on the last sector, not out of bounds")
    func pastTheTotalClampsToTheLastSector() {
        let data = breakdowns()
        #expect(CategoryDonutSelection.category(atCumulativeAmount: 99_999, in: data)?.category.name == "Dining")
    }

    @Test("a negative value selects nothing")
    func negativeSelectsNothing() {
        #expect(CategoryDonutSelection.category(atCumulativeAmount: -1, in: breakdowns()) == nil)
    }

    @Test("no data selects nothing rather than trapping")
    func emptyDataIsSafe() {
        #expect(CategoryDonutSelection.category(atCumulativeAmount: 0, in: []) == nil)
        #expect(CategoryDonutSelection.category(atCumulativeAmount: 500, in: []) == nil)
    }

    @Test("a sector's midpoint round-trips back to that sector")
    func midpointRoundTrips() {
        let data = breakdowns()
        for item in data {
            let midpoint = try? #require(CategoryDonutSelection.cumulativeMidpoint(of: item.id, in: data))
            let resolved = CategoryDonutSelection.category(atCumulativeAmount: midpoint ?? -1, in: data)
            #expect(resolved?.id == item.id, "\(item.category.name) should round-trip")
        }
    }

    /// The chart draws only the first eight sectors, so selection has to
    /// resolve against those. The crashing version looked the index up in the
    /// unclipped array, where a ninth category could never round-trip.
    @Test("only the drawn sectors participate in selection")
    func selectionIsScopedToTheDrawnSectors() {
        let many = (1...12).map { i in
            CategoryBreakdown(
                category: CategoryEntity(name: "C\(i)", icon: "tag", colorHex: "#000000", type: .expense),
                amount: Decimal(100),
                percentage: 0,
                transactionCount: 1
            )
        }
        // Eight sectors of 100 each: the arc ends at 800.
        #expect(CategoryDonutSelection.category(atCumulativeAmount: 800, in: many)?.category.name == "C8")
        // Beyond the drawn arc still resolves to the last DRAWN sector.
        #expect(CategoryDonutSelection.category(atCumulativeAmount: 1100, in: many)?.category.name == "C8")
        // A category the chart never drew has no angular position.
        #expect(CategoryDonutSelection.cumulativeMidpoint(of: many[10].id, in: many) == nil)
    }
}
