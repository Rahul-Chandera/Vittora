import Foundation
import Testing
import VittoraCore

@testable import Vittora

/// Net worth is subtotalled per currency, never summed across currencies.
///
/// Accounts carry their own `currencyCode` and the app holds no exchange rates.
/// The previous code added every balance into one figure and labelled it with
/// the display currency, so a ₹72,15,490 account was reported as
/// "$72,15,490.00" on the Dashboard, the Accounts screen and the Net Worth
/// report — overstating net worth by the entire FX factor rather than by a
/// rounding error.
///
/// Owner decision (2026-08-16): subtotal per currency rather than convert.
/// These are money figures, so the behaviour is pinned.
@Suite("Net worth per currency")
@MainActor
struct NetWorthPerCurrencyTests {

    private func account(
        _ name: String,
        _ balance: String,
        _ code: String,
        type: AccountType = .bank,
        archived: Bool = false
    ) -> AccountEntity {
        AccountEntity(
            name: name,
            type: type,
            balance: Decimal(string: balance)!,
            currencyCode: code,
            isArchived: archived
        )
    }

    @Test("balances in different currencies are never added together")
    func currenciesAreNotCombined() {
        let summary = NetWorthSummary.build(from: [
            account("ICICI", "7215490", "INR"),
            account("Chase", "28000", "USD")
        ])

        #expect(summary.isMultiCurrency)
        #expect(summary.byCurrency.count == 2)

        let inr = summary.byCurrency.first { $0.currencyCode == "INR" }
        let usd = summary.byCurrency.first { $0.currencyCode == "USD" }
        #expect(inr?.netWorth == Decimal(string: "7215490")!)
        #expect(usd?.netWorth == Decimal(string: "28000")!)

        // The bug: 7215490 + 28000 presented as one number.
        #expect(!summary.byCurrency.contains { $0.netWorth == Decimal(string: "7243490")! })
    }

    @Test("a single-currency ledger reports that currency, not the display one")
    func singleCurrencyKeepsItsOwnCode() {
        let summary = NetWorthSummary.build(from: [account("ICICI", "7215490", "INR")])

        #expect(!summary.isMultiCurrency)
        #expect(summary.singleCurrency?.currencyCode == "INR")
        #expect(summary.singleCurrency?.netWorth == Decimal(string: "7215490")!)
    }

    /// Card balances are NEGATIVE here, which is what the app actually stores:
    /// a balance is `opening + Σ transaction effects`, and spending on a card
    /// decrements it. The earlier version of this test passed positive card
    /// balances — a state the app never produces — so it passed while every
    /// net worth on screen was wrong.
    @Test("liabilities subtract only within their own currency")
    func liabilitiesStayInTheirCurrency() {
        let summary = NetWorthSummary.build(from: [
            account("ICICI", "100000", "INR"),
            account("INR Card", "-40000", "INR", type: .creditCard),
            account("Chase", "5000", "USD"),
            account("US Card", "-1000", "USD", type: .creditCard)
        ])

        let inr = summary.byCurrency.first { $0.currencyCode == "INR" }
        let usd = summary.byCurrency.first { $0.currencyCode == "USD" }
        #expect(inr?.assets == Decimal(string: "100000")!)
        #expect(inr?.liabilities == Decimal(string: "40000")!)
        #expect(inr?.netWorth == Decimal(string: "60000")!)
        #expect(usd?.netWorth == Decimal(string: "4000")!)
    }

    /// The exact figures from the Net Worth report on iPhone 17 Pro Max /
    /// iOS 26.5 with the seeded demo data. It showed 14,391.92 — assets PLUS
    /// the card, because the raw negative balance was subtracted.
    @Test("a card reduces net worth rather than increasing it")
    func cardDebtReducesNetWorth() {
        let summary = NetWorthSummary.build(from: [
            account("Chase Checking", "12902.30", "USD"),
            account("Cash", "222.65", "USD", type: .cash),
            account("Amex Credit Card", "-1266.97", "USD", type: .creditCard)
        ])

        let usd = try! #require(summary.singleCurrency)
        #expect(usd.assets == Decimal(string: "13124.95")!)
        #expect(usd.liabilities == Decimal(string: "1266.97")!)
        #expect(usd.netWorth == Decimal(string: "11857.98")!)
        #expect(usd.netWorth < usd.assets)
    }

    /// An overpaid card holds a positive balance, so it is money owed TO the
    /// user and should raise net worth, not lower it.
    @Test("an overpaid card adds to net worth")
    func overpaidCardAddsToNetWorth() {
        let summary = NetWorthSummary.build(from: [
            account("Chase Checking", "1000", "USD"),
            account("Amex Credit Card", "250", "USD", type: .creditCard)
        ])

        let usd = try! #require(summary.singleCurrency)
        #expect(usd.liabilities == Decimal(string: "-250")!)
        #expect(usd.netWorth == Decimal(string: "1250")!)
    }

    @Test("singleCurrency is nil when several are present, so no caller shows one figure")
    func noSingleFigureAcrossCurrencies() {
        let summary = NetWorthSummary.build(from: [
            account("ICICI", "1", "INR"),
            account("Chase", "1", "USD")
        ])
        #expect(summary.singleCurrency == nil)
    }

    @Test("ordering is deterministic: largest position first, then by code")
    func orderingIsStable() {
        let accounts = [
            account("A", "100", "USD"),
            account("B", "500", "INR"),
            account("C", "100", "EUR")
        ]
        let first = NetWorthSummary.build(from: accounts)
        let second = NetWorthSummary.build(from: accounts.reversed())

        #expect(first.byCurrency.map(\.currencyCode) == ["INR", "EUR", "USD"])
        // Same inputs in a different order must not reshuffle the display.
        #expect(first.byCurrency == second.byCurrency)
    }

    @Test("no accounts yields no subtotals rather than a zero in some currency")
    func emptyIsEmpty() {
        let summary = NetWorthSummary.build(from: [])
        #expect(summary.byCurrency.isEmpty)
        #expect(summary.singleCurrency == nil)
        #expect(!summary.isMultiCurrency)
    }
}
