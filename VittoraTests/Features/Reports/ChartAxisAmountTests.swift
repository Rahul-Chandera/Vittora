import Foundation
import Testing
@testable import Vittora

/// Axis labels must be distinguishable from one another.
///
/// Both chart components formatted with `String(format: "%.0fk", amount/1000)`,
/// rounding to whole thousands. A Spending Trends axis running
/// 0 / 500 / 1,000 / 1,500 / 2,000 therefore printed "$2k" for BOTH 1,500 and
/// 2,000 — two identical labels at different heights, seen on iPhone 17e.
@Suite("Chart axis amounts")
struct ChartAxisAmountTests {

    private func label(_ value: Double) -> String {
        ChartAxisAmount.compact(value, symbol: "$")
    }

    /// The regression: the exact ticks from the screen must all differ.
    @Test("the axis that collided now reads distinctly")
    func collidingAxisIsDistinct() {
        let ticks = [0.0, 500, 1_000, 1_500, 2_000].map(label)
        #expect(ticks == ["$0", "$500", "$1k", "$1.5k", "$2k"])
        #expect(Set(ticks).count == ticks.count)
    }

    @Test("whole thousands keep no decimal")
    func wholeThousandsStayWhole() {
        #expect(label(1_000) == "$1k")
        #expect(label(2_000) == "$2k")
        #expect(label(10_000) == "$10k")
    }

    @Test("millions abbreviate too")
    func millions() {
        #expect(label(1_000_000) == "$1M")
        #expect(label(2_500_000) == "$2.5M")
    }

    @Test("under a thousand is shown in full")
    func smallValues() {
        #expect(label(0) == "$0")
        #expect(label(750) == "$750")
    }

    /// Rounding to one place first, so a near-miss does not print "2.0k".
    @Test("a near-whole value does not print a trailing .0")
    func nearWholeHasNoTrailingZero() {
        #expect(label(1_999) == "$2k")
    }

    @Test("negatives keep their sign")
    func negatives() {
        #expect(label(-1_500) == "-$1.5k")
    }
}
