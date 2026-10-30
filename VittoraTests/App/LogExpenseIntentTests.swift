import AppIntents
import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// The Shortcuts actions only queue: the app books the entry. These run the real
/// `perform()` against the App Group queue and remove only what they added.
@MainActor
@Suite("Log Expense Intent Tests", .serialized)
struct LogExpenseIntentTests {
    private func takeEntry(where match: (QuickLogEntry) -> Bool) throws -> QuickLogEntry {
        let queue = try #require(QuickLogQueue())
        let found = queue.pending().first(where: match)
        let entry = try #require(found)
        queue.remove(id: entry.id)
        return entry
    }

    @Test("Log Expense queues amount, currency, payee and payment method")
    func logExpenseQueuesEntry() async throws {
        let marker = "Intent Test Payee \(UUID().uuidString.prefix(6))"
        var intent = LogExpenseIntent()
        intent.amount = IntentCurrencyAmount(amount: Decimal(string: "12.34") ?? 0, currencyCode: "USD")
        intent.payee = "  \(marker) "
        intent.paidWith = .card

        _ = try await intent.perform()

        let entry = try takeEntry { $0.payeeName == marker }
        #expect(entry.amount == Decimal(string: "12.34"))
        #expect(entry.currencyCode == "USD")
        #expect(entry.paymentMethod == PaymentMethod.creditCard.rawValue)
        #expect(entry.note == nil)
    }

    @Test("Log Expense from Message queues the parsed debit")
    func logFromMessageQueuesDebit() async throws {
        var intent = LogExpenseFromMessageIntent()
        intent.message = "Rs.733.00 debited from A/c XX1234 on 25-Oct-26 to VPA intenttestshop@axis (UPI Ref No 629812345678)"

        _ = try await intent.perform()

        let entry = try takeEntry { $0.payeeName == "Intenttestshop" }
        #expect(entry.amount == 733)
        #expect(entry.currencyCode == "INR")
        #expect(entry.paymentMethod == PaymentMethod.upi.rawValue)
    }

    @Test("A message that is not a payment queues nothing")
    func nonPaymentQueuesNothing() async throws {
        let before = try #require(QuickLogQueue()).pendingCount
        var intent = LogExpenseFromMessageIntent()
        intent.message = "123456 is your OTP for txn of Rs 999.00 at FLIPKART."

        _ = try await intent.perform()

        #expect(try #require(QuickLogQueue()).pendingCount == before)
    }

    /// App Store Connect rejects a build whose intent metadata names Apple
    /// (ITMS-90626, 1.8.2 build 15: "Apple Pay" in Log Expense's description).
    @Test("No intent title or description mentions Apple, in any language")
    func intentMetadataAvoidsApple() {
        let resources: [LocalizedStringResource] = [
            LogExpenseIntent.title, LogExpenseIntent.description.descriptionText,
            LogExpenseFromMessageIntent.title, LogExpenseFromMessageIntent.description.descriptionText,
            AddExpenseIntent.title, AddExpenseIntent.description.descriptionText,
            GetTodaySpendingIntent.title, GetTodaySpendingIntent.description.descriptionText,
        ]
        for language in ["en", "es", "hi"] {
            for var resource in resources {
                resource.locale = Locale(identifier: language)
                let text = String(localized: resource)
                #expect(!text.localizedCaseInsensitiveContains("apple"), "\(language): \(text)")
            }
        }
    }
}
