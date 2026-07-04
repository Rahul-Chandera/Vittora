import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("Money Parsing Tests")
struct MoneyParsingTests {

    @Test("en_US parses grouping and decimal separators")
    func enUSParsing() {
        let locale = Locale(identifier: "en_US")
        #expect(Decimal(localizedAmount: "1,000", locale: locale) == 1000)
        #expect(Decimal(localizedAmount: "1,000.50", locale: locale) == Decimal(string: "1000.5"))
        #expect(Decimal(localizedAmount: "1.5", locale: locale) == Decimal(string: "1.5"))
    }

    @Test("de_DE parses European grouping and decimal separators")
    func deDEParsing() {
        let locale = Locale(identifier: "de_DE")
        #expect(Decimal(localizedAmount: "1.000,50", locale: locale) == Decimal(string: "1000.5"))
        #expect(Decimal(localizedAmount: "1,5", locale: locale) == Decimal(string: "1.5"))
    }

    @Test("fr_FR parses comma decimal separator")
    func frFRParsing() {
        let locale = Locale(identifier: "fr_FR")
        #expect(Decimal(localizedAmount: "1,5", locale: locale) == Decimal(string: "1.5"))
    }

    @Test("Unparseable and empty input returns nil, never silent zero")
    func rejectsUnparseableInput() {
        let locale = Locale(identifier: "en_US")
        #expect(Decimal(localizedAmount: "", locale: locale) == nil)
        #expect(Decimal(localizedAmount: "   ", locale: locale) == nil)
        #expect(Decimal(localizedAmount: "abc", locale: locale) == nil)
        #expect(Decimal(localizedAmount: "12.34.56", locale: locale) == nil)
    }

    @Test("Zero is a valid parsed amount when explicitly entered")
    func zeroIsValid() {
        let locale = Locale(identifier: "en_US")
        #expect(Decimal(localizedAmount: "0", locale: locale) == 0)
        #expect(Decimal(localizedAmount: "0.00", locale: locale) == 0)
    }
}
