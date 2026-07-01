import CoreGraphics
import Foundation
import Testing
@testable import Vittora

@Suite("ReceiptParserService Tests")
@MainActor
struct ReceiptParserServiceTests {

    private let parser = ReceiptParserService()

    private func blocks(_ lines: [String]) -> [RecognizedTextBlock] {
        lines.map { RecognizedTextBlock(text: $0, confidence: 1, boundingBox: .zero) }
    }

    @Test("USD total with dollar sign and comma grouping")
    func usdTotalWithCommaGrouping() {
        let result = parser.parse(blocks: blocks([
            "Whole Foods Market",
            "Organic Milk",
            "GRAND TOTAL $1,234.56",
        ]))
        #expect(result.totalAmount == Decimal(string: "1234.56"))
        #expect(result.merchantName == "Whole Foods Market")
    }

    @Test("INR total with Rs prefix")
    func inrTotalWithRsPrefix() {
        let result = parser.parse(blocks: blocks([
            "Reliance Fresh",
            "Basmati Rice",
            "Total Amount Rs. 2,499.00",
        ]))
        #expect(result.totalAmount == Decimal(string: "2499.00"))
        #expect(result.merchantName == "Reliance Fresh")
    }

    @Test("prefers total keyword line over earlier amounts")
    func prefersTotalKeywordLine() {
        let result = parser.parse(blocks: blocks([
            "Corner Cafe",
            "Latte          4.50",
            "Tax            0.36",
            "GRAND TOTAL    $4.86",
        ]))
        #expect(result.totalAmount == Decimal(string: "4.86"))
    }

    @Test("falls back to last monetary value when no total keyword")
    func fallbackToLastMonetaryValue() {
        let result = parser.parse(blocks: blocks([
            "Parking Receipt",
            "Duration 2h",
            "Paid 12.00",
        ]))
        #expect(result.totalAmount == Decimal(string: "12.00"))
    }

    @Test("returns nil total when receipt has no amounts")
    func noAmountReceipt() {
        let result = parser.parse(blocks: blocks([
            "Thank you for visiting",
            "Have a nice day",
        ]))
        #expect(result.totalAmount == nil)
        #expect(result.lineItems.isEmpty)
    }

    @Test("parses MM/dd/yyyy date format")
    func parsesSlashDate() {
        let result = parser.parse(blocks: blocks([
            "Target",
            "Date 06/15/2024",
            "TOTAL $19.99",
        ]))
        let components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day],
            from: result.date ?? .distantPast
        )
        #expect(components.year == 2024)
        #expect(components.month == 6)
        #expect(components.day == 15)
    }

    @Test("parses dd-MM-yyyy date format")
    func parsesDashDate() {
        let result = parser.parse(blocks: blocks([
            "DMart",
            "Bill Date 28-06-2024",
            "Total Rs 500.00",
        ]))
        let components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day],
            from: result.date ?? .distantPast
        )
        #expect(components.year == 2024)
        #expect(components.month == 6)
        #expect(components.day == 28)
    }

    @Test("parses yyyy-MM-dd date format")
    func parsesIsoDate() {
        let result = parser.parse(blocks: blocks([
            "Online Store",
            "2024-12-01",
            "Amount Due $42.00",
        ]))
        let components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day],
            from: result.date ?? .distantPast
        )
        #expect(components.year == 2024)
        #expect(components.month == 12)
        #expect(components.day == 1)
    }

    @Test("parses dd MMM yyyy date format")
    func parsesMonthNameDate() {
        let result = parser.parse(blocks: blocks([
            "Bookshop",
            "15 Jan 2024",
            "Total $18.50",
        ]))
        let components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day],
            from: result.date ?? .distantPast
        )
        #expect(components.year == 2024)
        #expect(components.month == 1)
        #expect(components.day == 15)
    }

    @Test("extracts line items with name and price")
    func extractsLineItems() {
        let result = parser.parse(blocks: blocks([
            "Grocery Outlet",
            "Apples         3.49",
            "Bread          2.99",
        ]))
        #expect(result.lineItems.count == 2)
        #expect(result.lineItems[0].name == "Apples")
        #expect(result.lineItems[0].amount == Decimal(string: "3.49"))
        #expect(result.lineItems[1].name == "Bread")
        #expect(result.lineItems[1].amount == Decimal(string: "2.99"))
    }
}
