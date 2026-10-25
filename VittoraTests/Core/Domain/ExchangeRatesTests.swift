import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Conversion changes the totals people make decisions on, so the arithmetic, the
/// fallbacks and the read-only guarantee are what these pin.
@MainActor
@Suite("Exchange Rates Tests")
struct ExchangeRatesTests {
    private func euroRates() -> ExchangeRates {
        var rates = ExchangeRates(anchor: "EUR")
        rates.applyECB(["USD": Decimal(string: "1.08") ?? 0, "INR": 90], date: .now)
        return rates
    }

    @Test("Cross rates go through the anchor")
    func crossRate() {
        let rates = euroRates()
        #expect(rates.convert(108, from: "USD", to: "EUR") == 100)
        #expect(rates.convert(1, from: "USD", to: "INR") == Decimal(string: "83.33"))
        #expect(rates.convert(50, from: "INR", to: "INR") == 50)
        #expect(rates.convert(10, from: "AED", to: "INR") == nil)
    }

    @Test("A manual rate is stated against the main currency and round-trips")
    func manualRate() {
        var rates = ExchangeRates(anchor: "EUR")
        rates.setManual("USD", worth: Decimal(string: "83.20") ?? 0, in: "INR")
        #expect(rates.anchor == "INR")
        #expect(rates.convert(10, from: "USD", to: "INR") == 832)
        #expect(rates.rate(of: "USD", in: "INR") == Decimal(string: "83.20"))
        #expect(rates.rates["USD"]?.source == .manual)
    }

    @Test("ECB update keeps a manual rate the ECB does not publish, re-anchored to the euro")
    func ecbKeepsManualOnly() {
        var rates = ExchangeRates(anchor: "EUR")
        rates.setManual("AED", worth: Decimal(string: "22.70") ?? 0, in: "INR")
        rates.applyECB(["INR": 90, "USD": Decimal(string: "1.08") ?? 0], date: .now)
        #expect(rates.anchor == "EUR")
        #expect(rates.convert(1, from: "AED", to: "INR") == Decimal(string: "22.70"))
        #expect(rates.rates["INR"]?.source == .ecb)
        #expect(rates.rates["AED"]?.source == .manual)
    }

    @Test("Parses the ECB daily file")
    func parsesECB() throws {
        let xml = """
        <gesmes:Envelope><Cube><Cube time='2026-10-23'>
        <Cube currency='USD' rate='1.0825'/><Cube currency='INR' rate='90.12'/><Cube currency='JPY' rate='162.4'/>
        </Cube></Cube></gesmes:Envelope>
        """
        let parsed = try #require(ECBRates.parse(xml))
        #expect(parsed.perEuro["USD"] == Decimal(string: "1.0825"))
        #expect(parsed.perEuro["INR"] == Decimal(string: "90.12"))
        #expect(parsed.perEuro.count == 3)
        #expect(ECBRates.parse("<html>not rates</html>") == nil)
    }

    // MARK: - Converting repository

    private func makeStore(base: String, rates: ExchangeRates) -> ExchangeRateStore {
        let defaults = UserDefaults(suiteName: "fx-\(UUID().uuidString)") ?? .standard
        defaults.set(base, forKey: AppUserDefaults.StandardKey.currencyCode)
        let store = ExchangeRateStore(defaults: defaults)
        store.rates = rates
        return store
    }

    @Test("Reads come back in the main currency; a currency without a rate is left as it was")
    func convertingReads() async throws {
        let repository = MockTransactionRepository()
        try await repository.create(TransactionEntity(amount: 10, type: .expense, currencyCode: "USD"))
        try await repository.create(TransactionEntity(amount: 5, type: .expense, currencyCode: "AED"))
        try await repository.create(TransactionEntity(amount: 100, type: .expense, currencyCode: "INR"))
        let converting = ConvertingTransactionRepository(base: repository, store: makeStore(base: "INR", rates: euroRates()))

        let all = try await converting.fetchAll(filter: nil)
        #expect(all.first { $0.amount == Decimal(string: "833.33") }?.currencyCode == "INR")
        #expect(all.first { $0.currencyCode == "AED" }?.amount == 5)
        #expect(all.filter { $0.currencyCode == "INR" }.count == 2)
        // The stored rows are untouched.
        #expect(try await repository.fetchAll(filter: nil).contains { $0.currencyCode == "USD" && $0.amount == 10 })
    }

    @Test("Writes through the converting view are refused")
    func convertingWritesThrow() async {
        let converting = ConvertingTransactionRepository(base: MockTransactionRepository(), store: makeStore(base: "INR", rates: euroRates()))
        await #expect(throws: ConvertingTransactionRepository.ConversionError.self) {
            try await converting.create(TransactionEntity(amount: 1))
        }
        await #expect(throws: ConvertingTransactionRepository.ConversionError.self) {
            try await converting.delete(UUID())
        }
    }

    @Test("Net worth converts what it can and names what it can't")
    func netWorthConverted() {
        let summary = NetWorthSummary.build(from: [
            AccountEntity(name: "HDFC", type: .bank, balance: 100_000, currencyCode: "INR"),
            AccountEntity(name: "Chase", type: .bank, balance: 1_000, currencyCode: "USD"),
            AccountEntity(name: "Emirates NBD", type: .bank, balance: 500, currencyCode: "AED"),
        ])
        let (total, missing) = summary.converted(to: "INR", using: euroRates())
        #expect(total == Decimal(string: "183333.33"))
        #expect(missing == ["AED"])
    }
}
