import Foundation
import VittoraCore

/// Exchange rates the user typed in or chose to download from the European Central
/// Bank, kept on this device.
///
/// Rates are stored as units of each currency per one unit of an anchor currency (the
/// ECB publishes per euro), so any pair converts through the anchor and changing the
/// main currency never invalidates them. A rate the user entered is kept when the ECB
/// rates are updated, unless the ECB publishes that currency.
nonisolated struct ExchangeRates: Codable, Equatable, Sendable {
    enum Source: String, Codable, Sendable { case manual, ecb }

    struct Rate: Codable, Equatable, Sendable {
        /// Units of this currency per one unit of `anchor`.
        var perAnchor: Decimal
        var source: Source
        var updatedAt: Date
    }

    var anchor: String
    var rates: [String: Rate] = [:]

    func units(of code: String) -> Decimal? {
        code == anchor ? 1 : rates[code]?.perAnchor
    }

    /// `amount` in `from`, expressed in `to`. Nil when either rate is missing.
    func convert(_ amount: Decimal, from: String, to: String) -> Decimal? {
        guard from != to else { return amount }
        guard let fromUnits = units(of: from), let toUnits = units(of: to), fromUnits > 0 else { return nil }
        var result = amount * toUnits / fromUnits
        var rounded = Decimal()
        NSDecimalRound(&rounded, &result, 2, .bankers)
        return rounded
    }

    /// How many `base` one unit of `code` is worth, for display: "1 USD = 83.20 INR".
    func rate(of code: String, in base: String) -> Decimal? {
        guard let codeUnits = units(of: code), let baseUnits = units(of: base), codeUnits > 0 else { return nil }
        // Rounded: dividing back through the anchor leaves noise in the 30th place.
        var rate = baseUnits / codeUnits
        var rounded = Decimal()
        NSDecimalRound(&rounded, &rate, 6, .plain)
        return rounded
    }

    /// Records "1 `code` = `value` `base`" as entered by the user.
    mutating func setManual(_ code: String, worth value: Decimal, in base: String, now: Date = .now) {
        guard value > 0, code != base else { return }
        if units(of: base) == nil {
            if rates.isEmpty {
                anchor = base
            } else {
                // A base the anchor table has never seen: start it at 1 anchor unit
                // so the user's own rate still converts correctly against it.
                rates[base] = Rate(perAnchor: 1, source: .manual, updatedAt: now)
            }
        }
        guard let baseUnits = units(of: base) else { return }
        rates[code] = Rate(perAnchor: baseUnits / value, source: .manual, updatedAt: now)
    }

    /// Replaces the rates the ECB publishes and keeps the user's other ones. The ECB
    /// table is per euro; existing rates are re-expressed per euro first when they used
    /// another anchor and can be.
    mutating func applyECB(_ perEuro: [String: Decimal], date: Date) {
        if anchor != "EUR" {
            // Re-anchor what we have to euros, through a currency both tables know.
            let shared = ([anchor] + Array(rates.keys)).first { perEuro[$0] != nil }
            if let shared, let ourUnits = units(of: shared), ourUnits > 0, let euroUnits = perEuro[shared] {
                let factor = euroUnits / ourUnits                // our anchor units → per euro
                rates = rates.mapValues { Rate(perAnchor: $0.perAnchor * factor, source: $0.source, updatedAt: $0.updatedAt) }
                if anchor != "EUR" { rates[anchor] = Rate(perAnchor: factor, source: .manual, updatedAt: date) }
            } else {
                rates = [:]
            }
            anchor = "EUR"
            rates["EUR"] = nil
        }
        for (code, value) in perEuro where value > 0 {
            rates[code] = Rate(perAnchor: value, source: .ecb, updatedAt: date)
        }
    }
}

/// Persists `ExchangeRates` in the app's own defaults. Local to the device: rates are
/// cheap to re-enter or re-download, and syncing them is not worth a schema change.
nonisolated final class ExchangeRateStore: @unchecked Sendable {
    static let shared = ExchangeRateStore()
    private static let key = "vittora.exchangeRates"
    private nonisolated(unsafe) let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var rates: ExchangeRates {
        get {
            lock.lock(); defer { lock.unlock() }
            guard let data = defaults.data(forKey: Self.key),
                  let decoded = try? JSONDecoder().decode(ExchangeRates.self, from: data)
            else { return ExchangeRates(anchor: "EUR") }
            return decoded
        }
        set {
            lock.lock(); defer { lock.unlock() }
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.key)
        }
    }

    /// The app's main (display) currency.
    var baseCurrency: String {
        defaults.string(forKey: AppUserDefaults.StandardKey.currencyCode) ?? CurrencyDefaults.code
    }
}

/// The European Central Bank's public daily reference rates (about 30 currencies, per
/// euro). Only fetched when the user asks; the request carries nothing about them.
nonisolated enum ECBRates {
    static let url = URL(string: "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")

    /// Parses `<Cube time='2026-10-24'>` and `<Cube currency='USD' rate='1.0825'/>`.
    static func parse(_ xml: String) -> (date: Date, perEuro: [String: Decimal])? {
        func attribute(_ name: String, in tag: Substring) -> String? {
            guard let range = tag.range(of: "\(name)=['\"]([^'\"]+)['\"]", options: .regularExpression) else { return nil }
            return String(tag[range].split(separator: "=", maxSplits: 1)[1]).trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
        }
        var perEuro: [String: Decimal] = [:]
        var date: Date?
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "yyyy-MM-dd"
        for tag in xml.split(separator: "<").filter({ $0.hasPrefix("Cube") }) {
            if let time = attribute("time", in: tag) { date = formatter.date(from: time) }
            if let code = attribute("currency", in: tag), let raw = attribute("rate", in: tag),
               let value = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")), value > 0 {
                perEuro[code] = value
            }
        }
        guard let date, !perEuro.isEmpty else { return nil }
        return (date, perEuro)
    }

    static func fetch() async throws -> (date: Date, perEuro: [String: Decimal]) {
        guard let url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let parsed = parse(String(decoding: data, as: UTF8.self))
        else { throw URLError(.cannotParseResponse) }
        return parsed
    }
}
