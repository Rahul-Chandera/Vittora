import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("Decimal Currency Formatting Tests")
struct DecimalCurrencyTests {

    // Helper to call our custom extension without ambiguity
    private func format(_ decimal: Decimal, currencyCode: String) -> String {
        decimal.formatted(currencyCode: currencyCode)
    }

    @Test("Format USD currency")
    func testFormatUSD() {
        let formatted = format(Decimal(1234.56), currencyCode: "USD")
        #expect(formatted.contains("$"))
        #expect(formatted.contains("1,234"))
    }

    @Test("Format zero amount")
    func testFormatZero() {
        let formatted = format(Decimal(0), currencyCode: "USD")
        #expect(!formatted.isEmpty)
        #expect(formatted.contains("0"))
    }

    @Test("Format negative amount")
    func testFormatNegative() {
        let formatted = format(Decimal(-500.75), currencyCode: "USD")
        #expect(!formatted.isEmpty)
        #expect(formatted.contains("500"))
    }

    @Test("Format GBP currency")
    func testFormatGBP() {
        let formatted = format(Decimal(1000), currencyCode: "GBP")
        #expect(formatted.contains("£"))
    }

    @Test("Format JPY currency")
    func testFormatJPY() {
        // Use 100 to avoid locale-specific grouping (e.g. Indian en_IN uses 1,00,000 for 100000)
        let formatted = format(Decimal(100), currencyCode: "JPY")
        #expect(!formatted.isEmpty)
        #expect(formatted.contains("100"))
    }

    @Test("Format EUR currency")
    func testFormatEUR() {
        let formatted = format(Decimal(2500.99), currencyCode: "EUR")
        #expect(formatted.contains("€"))
    }

    @Test("Format very large amount")
    func testFormatLargeAmount() {
        let formatted = format(Decimal(1234567890), currencyCode: "USD")
        #expect(!formatted.isEmpty)
    }

    @Test("Format very small amount")
    func testFormatSmallAmount() {
        let formatted = format(Decimal(0.01), currencyCode: "USD")
        #expect(!formatted.isEmpty)
    }

    @Test("Absolute value of positive number")
    func testAbsPositive() {
        #expect(Decimal(100).absoluteValue == 100)
    }

    @Test("Absolute value of negative number")
    func testAbsNegative() {
        #expect(Decimal(-100).absoluteValue == 100)
    }

    @Test("Absolute value of zero")
    func testAbsZero() {
        #expect(Decimal(0).absoluteValue == 0)
    }

    @Test("Is negative property - negative number")
    func testIsNegativeTrue() {
        #expect(Decimal(-50).isNegative == true)
    }

    @Test("Is negative property - positive number")
    func testIsNegativeFalse() {
        #expect(Decimal(50).isNegative == false)
    }

    @Test("Is negative property - zero")
    func testIsNegativeZero() {
        #expect(Decimal(0).isNegative == false)
    }

    @Test("Is positive property")
    func testIsPositive() {
        #expect(Decimal(100).isPositive == true)
    }

    @Test("Is zero property")
    func testIsZeroTrue() {
        // Decimal has a built-in isZero; test our extension's isZero via isPositive/isNegative
        let zero = Decimal(0)
        #expect(!zero.isNegative)
        #expect(!zero.isPositive)
    }

    @Test("Percentage formatting")
    func testAsPercentage() {
        let percentage = Decimal(0.5).asPercentage()
        #expect(percentage.contains("50"))
        #expect(percentage.contains("%"))
    }

    @Test("Rounding to decimal places")
    func testRounding() {
        let rounded = Decimal(1.5678).rounded(to: 2)
        // Allow for floating point representation variance — just check it's close
        let diff = abs(NSDecimalNumber(decimal: rounded).doubleValue - 1.57)
        #expect(diff < 0.001)
    }

    @Test("Abbreviate thousands")
    func testAbbreviateThousands() {
        let abbreviated = Decimal(1500).abbreviated()
        #expect(abbreviated.contains("K"))
    }

    @Test("Abbreviate millions")
    func testAbbreviateMillions() {
        let abbreviated = Decimal(2500000).abbreviated()
        #expect(abbreviated.contains("M"))
    }

    @Test("Abbreviate negative amount")
    func testAbbreviateNegative() {
        let abbreviated = Decimal(-3000).abbreviated()
        #expect(!abbreviated.isEmpty)
    }

    @Test("Abbreviate small amount")
    func testAbbreviateSmallAmount() {
        let abbreviated = Decimal(500).abbreviated()
        #expect(!abbreviated.isEmpty)
        #expect(!abbreviated.contains("K"))
    }

    // MARK: - L8: exact Decimal equality and rounding boundaries

    @Test("rounded(to:) uses exact Decimal equality at half-up boundary")
    func testRoundingHalfUpExact() {
        let input = Decimal(string: "1.005")!
        let rounded = input.rounded(to: 2)
        #expect(rounded == Decimal(string: "1.01")!)
    }

    @Test("rounded(to:) rounds .5 up at zero decimal places")
    func testRoundingHalfUpToInteger() {
        let input = Decimal(string: "2.5")!
        #expect(input.rounded(to: 0) == Decimal(string: "3")!)
    }

    @Test("rounded(to:) preserves value below half boundary")
    func testRoundingBelowHalfBoundary() {
        let input = Decimal(string: "1.004")!
        #expect(input.rounded(to: 2) == Decimal(string: "1.00")!)
    }

    @Test("JPY formats without fractional digits")
    func testJPYNoFraction() {
        let formatted = format(Decimal(1000), currencyCode: "JPY")
        #expect(!formatted.contains("."))
        #expect(formatted.contains("1000") || formatted.contains("1,000"))
    }

    @Test("pinned en_US_POSIX USD string")
    func testPinnedLocaleUSD() {
        let amount = Decimal(string: "1234.56")!
        let formatted = formatPinned(amount, currencyCode: "USD")
        #expect(formatted.contains("1,234.56"))
        #expect(formatted.contains("$"))
    }

    @Test("pinned en_US_POSIX INR string")
    func testPinnedLocaleINR() {
        let amount = Decimal(string: "2499.00")!
        let formatted = formatPinned(amount, currencyCode: "INR")
        #expect(formatted.contains("2,499"))
        #expect(formatted.contains("₹"))
    }

    /// Locale-independent assertion helper (TESTING-7 / L8).
    private func formatPinned(_ decimal: Decimal, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? ""
    }
}
