import Foundation
import Testing
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
}
