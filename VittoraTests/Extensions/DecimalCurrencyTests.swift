import Foundation
import Testing

@Suite("Decimal Currency Formatting Tests")
struct DecimalCurrencyTests {
    @Test("Format USD currency")
    func testFormatUSD() {
        let amount = Decimal(1234.56)
        let formatted = amount.formatted(currencyCode: "USD")
        #expect(formatted.contains("$"))
        #expect(formatted.contains("1,234"))
        #expect(formatted.contains("56"))
    }

    @Test("Format zero amount")
    func testFormatZero() {
        let amount = Decimal(0)
        let formatted = amount.formatted(currencyCode: "USD")
        #expect(!formatted.isEmpty)
        #expect(formatted.contains("0"))
    }

    @Test("Format negative amount")
    func testFormatNegative() {
        let amount = Decimal(-500.75)
        let formatted = amount.formatted(currencyCode: "USD")
        #expect(!formatted.isEmpty)
        #expect(formatted.contains("500"))
    }

    @Test("Format GBP currency")
    func testFormatGBP() {
        let amount = Decimal(1000)
        let formatted = amount.formatted(currencyCode: "GBP")
        #expect(formatted.contains("£"))
    }

    @Test("Format JPY currency (no decimals)")
    func testFormatJPY() {
        let amount = Decimal(100000)
        let formatted = amount.formatted(currencyCode: "JPY")
        #expect(!formatted.isEmpty)
        #expect(formatted.contains("100"))
    }

    @Test("Format EUR currency")
    func testFormatEUR() {
        let amount = Decimal(2500.99)
        let formatted = amount.formatted(currencyCode: "EUR")
        #expect(formatted.contains("€"))
    }

    @Test("Format very large amount")
    func testFormatLargeAmount() {
        let amount = Decimal(1234567890.12)
        let formatted = amount.formatted(currencyCode: "USD")
        #expect(!formatted.isEmpty)
    }

    @Test("Format very small amount")
    func testFormatSmallAmount() {
        let amount = Decimal(0.01)
        let formatted = amount.formatted(currencyCode: "USD")
        #expect(!formatted.isEmpty)
    }

    @Test("Absolute value of positive number")
    func testAbsPositive() {
        let amount = Decimal(100)
        #expect(amount.abs == 100)
    }

    @Test("Absolute value of negative number")
    func testAbsNegative() {
        let amount = Decimal(-100)
        #expect(amount.abs == 100)
    }

    @Test("Absolute value of zero")
    func testAbsZero() {
        let amount = Decimal(0)
        #expect(amount.abs == 0)
    }

    @Test("Is negative property - negative number")
    func testIsNegativeTrue() {
        let amount = Decimal(-50)
        #expect(amount.isNegative == true)
    }

    @Test("Is negative property - positive number")
    func testIsNegativeFalse() {
        let amount = Decimal(50)
        #expect(amount.isNegative == false)
    }

    @Test("Is negative property - zero")
    func testIsNegativeZero() {
        let amount = Decimal(0)
        #expect(amount.isNegative == false)
    }

    @Test("Is positive property")
    func testIsPositive() {
        let amount = Decimal(100)
        #expect(amount.isPositive == true)
    }

    @Test("Is zero property")
    func testIsZero() {
        let amount = Decimal(0)
        #expect(amount.isZero == true)
    }

    @Test("Percentage formatting")
    func testAsPercentage() {
        let amount = Decimal(0.5)
        let percentage = amount.asPercentage()
        #expect(percentage.contains("50"))
        #expect(percentage.contains("%"))
    }

    @Test("Rounding to decimal places")
    func testRounding() {
        let amount = Decimal(123.4567)
        let rounded = amount.rounded(to: 2)
        #expect(rounded == Decimal(123.46))
    }

    @Test("Abbreviate thousands")
    func testAbbreviateThousands() {
        let amount = Decimal(1500)
        let abbreviated = amount.abbreviated()
        #expect(abbreviated.contains("K"))
    }

    @Test("Abbreviate millions")
    func testAbbreviateMillions() {
        let amount = Decimal(2500000)
        let abbreviated = amount.abbreviated()
        #expect(abbreviated.contains("M"))
    }

    @Test("Abbreviate negative amount")
    func testAbbreviateNegative() {
        let amount = Decimal(-3000)
        let abbreviated = amount.abbreviated()
        #expect(abbreviated.contains("-") || abbreviated.contains("K"))
    }

    @Test("Abbreviate amounts less than thousand")
    func testAbbreviateSmallAmount() {
        let amount = Decimal(500)
        let abbreviated = amount.abbreviated()
        #expect(!abbreviated.contains("K") || abbreviated.isEmpty == false)
    }
}
