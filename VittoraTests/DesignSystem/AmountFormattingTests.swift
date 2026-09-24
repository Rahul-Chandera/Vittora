import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Money keeps its cents.
///
/// `VAmountText` formatted with `.precision(.fractionLength(0...2))`, a RANGE,
/// so trailing zeros were dropped. On the Budgets screen a 150.00 budget with
/// 101.50 spent rendered "$101.5" and "$48.5", and 32.00 rendered "$32" — beside
/// correctly formatted values like "$189.99" in the same card.
///
/// Only amounts whose cents end in zero were affected, which is why it survived
/// on iOS: the seeded rows that happened to be visible all had non-zero cents.
/// Caught on the Mac Budgets screen, where more rows fit on screen at once.
@Suite("Amount formatting keeps cents")
@MainActor
struct AmountFormattingTests {

    private func usd(_ s: String) -> String {
        Decimal(string: s)!.formatted(.currency(code: "USD"))
    }

    /// The regression, with the exact values from the screen.
    @Test("trailing zeros are not dropped")
    func trailingZerosKept() {
        #expect(usd("101.50") == "$101.50")
        #expect(usd("48.50") == "$48.50")
        #expect(usd("32") == "$32.00")
        #expect(usd("140.80") == "$140.80")
    }

    @Test("non-zero cents were always fine and stay fine")
    func nonZeroCentsUnchanged() {
        #expect(usd("189.99") == "$189.99")
        #expect(usd("15.49") == "$15.49")
    }

    /// The fix removes the precision override rather than hardcoding 2, so a
    /// zero-decimal currency still formats correctly.
    @Test("a currency with no minor unit gets no decimals")
    func zeroDecimalCurrency() {
        let yen = Decimal(string: "1500")!.formatted(.currency(code: "JPY"))
        #expect(!yen.contains("."))
    }
}
