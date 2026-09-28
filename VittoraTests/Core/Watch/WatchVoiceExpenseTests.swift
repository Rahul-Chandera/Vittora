import Foundation
import Testing
import VittoraCore

/// Voice entry on Apple Watch (M2.6.2): what "500 for groceries" becomes.
///
/// Dictation and Siri can't run in a unit test; everything they hand back goes
/// through this parser, which is where a wrong amount or a wrong category would
/// come from.
@Suite("Watch voice expense")
struct WatchVoiceExpenseTests {

    private let us = Locale(identifier: "en_US")
    private func money(_ text: String) -> Decimal { Decimal(string: text) ?? .nan }

    private struct Category: Equatable {
        let name: String
    }

    private let categories = [
        Category(name: "Groceries"),
        Category(name: "Food & Dining"),
        Category(name: "Coffee"),
        Category(name: "Gasoline Tax Refund"),
        Category(name: "Rent"),
    ]

    private func match(_ phrase: String) -> String? {
        WatchVoiceExpense.matchCategory(phrase, in: categories, name: \.name)?.name
    }

    // MARK: Amount

    @Test("the plan's own example")
    func planExample() {
        let parsed = WatchVoiceExpense.parse("Add 500 for groceries", locale: us)
        #expect(parsed.amount == 500)
        #expect(parsed.categoryPhrase == "groceries")
    }

    @Test("currency symbols, words and grouping are read as the amount")
    func amountForms() {
        #expect(WatchVoiceExpense.parse("$12.50 on coffee", locale: us).amount == money("12.50"))
        #expect(WatchVoiceExpense.parse("spent 1,200 dollars on rent", locale: us).amount == 1_200)
        #expect(WatchVoiceExpense.parse("₹500 groceries", locale: Locale(identifier: "en_IN")).amount == 500)
        #expect(WatchVoiceExpense.parse("12,50 para café", locale: Locale(identifier: "es_ES")).amount == money("12.50"))
    }

    /// The crown stops at 10,000; a spoken rupee rent does not.
    @Test("amounts above the crown's ceiling are accepted")
    func largeAmounts() {
        #expect(WatchVoiceExpense.parse("50000 for rent", locale: us).amount == 50_000)
    }

    @Test("no amount, a zero, or fractions of a cent give no amount")
    func invalidAmounts() {
        #expect(WatchVoiceExpense.parse("groceries", locale: us).amount == nil)
        #expect(WatchVoiceExpense.parse("0 for groceries", locale: us).amount == nil)
        #expect(WatchVoiceExpense.parse("1.005 for gum", locale: us).amount == nil)
    }

    /// Only the first number is money; "2 coffees" after it is description.
    @Test("a later number stays in the description")
    func laterNumbersAreDescription() {
        let parsed = WatchVoiceExpense.parse("9 for 2 coffees", locale: us)
        #expect(parsed.amount == 9)
        #expect(parsed.categoryPhrase == "2 coffees")
    }

    @Test("Hindi filler words are dropped")
    func hindiFiller() {
        let parsed = WatchVoiceExpense.parse("किराने के लिए 500 जोड़ें", locale: Locale(identifier: "hi_IN"))
        #expect(parsed.amount == 500)
        #expect(parsed.categoryPhrase == "किराने")
    }

    // MARK: Category

    @Test("exact, plural and singular names match")
    func namesMatch() {
        #expect(match("groceries") == "Groceries")
        #expect(match("grocery") == "Groceries")
        #expect(match("RENT") == "Rent")
    }

    @Test("a word of a longer name, or a name within a longer phrase, matches")
    func wordMatches() {
        #expect(match("food") == "Food & Dining")
        #expect(match("coffee at the station") == "Coffee")
    }

    /// A wrong category is worse than none: "gas" must not become a tax refund
    /// by prefix.
    @Test("partial words never match")
    func noPrefixGuessing() {
        #expect(match("gas") == nil)
        #expect(match("groc") == nil)
        #expect(match("") == nil)
    }

    @Test("an exact match beats a word match")
    func exactWins() {
        let both = [Category(name: "Coffee Beans"), Category(name: "Coffee")]
        #expect(WatchVoiceExpense.matchCategory("coffee", in: both, name: \.name)?.name == "Coffee")
    }

    // MARK: Transport

    /// The hint crosses to the phone in userInfo; an older payload without it
    /// must still decode.
    @Test("the category hint survives transport, and its absence is fine")
    func hintTransport() throws {
        let hinted = QueuedWatchExpense(amount: 500, categoryHint: "groceries")
        #expect(try QueuedWatchExpense.fromUserInfo(hinted.userInfoDictionary()).categoryHint == "groceries")

        let plain = QueuedWatchExpense(amount: 500, categoryID: UUID())
        #expect(try QueuedWatchExpense.fromUserInfo(plain.userInfoDictionary()).categoryHint == nil)

        let legacy = Data(#"{"amount":500,"createdAt":0}"#.utf8)
        #expect(try QueuedWatchExpense.decodeFromTransport(legacy).categoryHint == nil)
    }
}
