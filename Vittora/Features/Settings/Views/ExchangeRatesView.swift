import SwiftUI
import VittoraCore

/// Settings › Exchange Rates: the rates used to add other currencies into the main one.
/// Users type them in, or choose to download the European Central Bank's daily rates.
struct ExchangeRatesView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.currencyCode) private var baseCurrency
    @State private var rates = ExchangeRates(anchor: "EUR")
    @State private var codes: [String] = []
    @State private var drafts: [String: String] = [:]
    @State private var isUpdating = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                if codes.isEmpty {
                    Text(String(localized: "All your accounts and transactions are in \(baseCurrency), so no rates are needed."))
                        .foregroundStyle(VColors.textSecondary)
                }
                ForEach(codes, id: \.self) { code in
                    rateRow(code)
                }
            } header: {
                VFormSectionHeader(String(localized: "Rates in \(baseCurrency)"))
            } footer: {
                Text(String(localized: "Used to add other currencies into your totals, net worth and reports. Your transactions keep the amount and currency you entered."))
            }

            Section {
                Button {
                    Task { await updateFromECB() }
                } label: {
                    HStack {
                        Text(String(localized: "Update from the European Central Bank"))
                        if isUpdating { Spacer(); ProgressView() }
                    }
                }
                .disabled(isUpdating)
                .accessibilityIdentifier("exchange-rates-update-ecb")
            } footer: {
                Text(String(localized: "Downloads the ECB's public daily rates, about 30 currencies. Nothing about you or your money is sent. Rates you entered for currencies the ECB doesn't publish are kept."))
            }
        }
        .navigationTitle(String(localized: "Exchange Rates"))
        .task { await load() }
        .errorAlert(message: $error)
    }

    private func rateRow(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: "1 \(code) =")
                TextField(String(localized: "Rate"), text: Binding(
                    get: { drafts[code] ?? "" },
                    set: { drafts[code] = $0 }
                ))
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .multilineTextAlignment(.trailing)
                .onSubmit { commit(code) }
                .accessibilityLabel(String(localized: "Rate for \(code) in \(baseCurrency)"))
                Text(verbatim: baseCurrency).foregroundStyle(VColors.textSecondary)
            }
            if let rate = rates.rates[code] ?? rates.rates[baseCurrency] {
                Text(rate.source == .ecb
                     ? String(localized: "From the ECB, \(rate.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                     : String(localized: "Entered by you, \(rate.updatedAt.formatted(date: .abbreviated, time: .omitted))"))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.textSecondary)
            } else {
                Text(String(localized: "No rate yet. \(code) amounts are left out of combined totals."))
                    .font(VTypography.caption1)
                    .foregroundStyle(VColors.warning)
            }
        }
        .onChange(of: drafts[code]) { _, _ in commit(code) }
    }

    private func commit(_ code: String) {
        guard let text = drafts[code]?.replacingOccurrences(of: ",", with: ""),
              let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), value > 0
        else { return }
        if let current = rates.rate(of: code, in: baseCurrency), current == value { return }
        rates.setManual(code, worth: value, in: baseCurrency)
        dependencies.exchangeRateStore.rates = rates
    }

    private func load() async {
        rates = dependencies.exchangeRateStore.rates
        let accounts = (try? await dependencies.accountRepository.fetchAll()) ?? []
        let transactions = (try? await dependencies.transactionRepository.fetchPage(filter: nil, offset: 0, limit: 2000)) ?? []
        let inUse = Set(accounts.map(\.currencyCode) + transactions.map(\.currencyCode))
        codes = inUse.subtracting([baseCurrency]).sorted()
        drafts = Dictionary(uniqueKeysWithValues: codes.compactMap { code in
            rates.rate(of: code, in: baseCurrency).map { (code, Self.format($0)) }
        })
    }

    private func updateFromECB() async {
        isUpdating = true
        defer { isUpdating = false }
        do {
            let (date, perEuro) = try await ECBRates.fetch()
            rates.applyECB(perEuro, date: date)
            dependencies.exchangeRateStore.rates = rates
            await load()
        } catch {
            self.error = String(localized: "Couldn't download the ECB rates. Check your connection and try again.")
        }
    }

    private static func format(_ value: Decimal) -> String {
        var value = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 4, .plain)
        return NSDecimalNumber(decimal: rounded).stringValue
    }
}
