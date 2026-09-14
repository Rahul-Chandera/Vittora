import Foundation
import Testing

@Suite("Plural localization variations")
struct PluralVariationTests {
    @Test("English one/other plural forms resolve at runtime")
    func englishPlurals() throws {
        try assertPlurals(lang: "en", expectations: englishExpectations)
    }

    @Test("Hindi one/other plural forms resolve at runtime")
    func hindiPlurals() throws {
        try assertPlurals(lang: "hi", expectations: hindiExpectations)
    }

    @Test("Spanish one/other plural forms resolve at runtime")
    func spanishPlurals() throws {
        try assertPlurals(lang: "es", expectations: spanishExpectations)
    }
}

private struct PluralExpectations {
    let transactions: (one: String, other: String)
    let debts: (one: String, other: String)
    let goalsPastDeadline: (one: String, other: String)
    let monthsOfHistory: (one: String, other: String)
    let overdueDebts: (one: String, other: String)
    let usuallySettlesComma: (one: String, other: String)
    let basedOnMonths: (one: String, other: String)
    let oldest: (one: String, other: String)
    let repaired: (one: String, other: String)
    let typicallySettled: (one: String, other: String)
    let usuallySettles: (one: String, other: String)
    let worst: (one: String, other: String)
    let nameNetOldest: (one: String, other: String)
    let typicallySettledMedian: (one: String, other: String)
    let syncEvents: (a1b3: String, a3b1: String)
    let overdueRisk: (a1d1e1: String, a3d5e2: String)
}

private let englishExpectations = PluralExpectations(
    transactions: (one: "1 transaction", other: "5 transactions"),
    debts: (one: "1 debt", other: "5 debts"),
    goalsPastDeadline: (one: "1 goal past deadline", other: "5 goals past deadline"),
    monthsOfHistory: (one: "1 month of available history", other: "5 months of available history"),
    overdueDebts: (one: "1 overdue debt", other: "5 overdue debts"),
    usuallySettlesComma: (one: ", usually settles in 1 day", other: ", usually settles in 5 days"),
    basedOnMonths: (
        one: "Based on 1 month until your deadline.",
        other: "Based on 5 months until your deadline."
    ),
    oldest: (one: "Oldest: 1 day", other: "Oldest: 5 days"),
    repaired: (one: "Repaired 1 account balance.", other: "Repaired 5 account balances."),
    typicallySettled: (one: "Typically settled in 1 day", other: "Typically settled in 5 days"),
    usuallySettles: (one: "Usually settles in 1 day", other: "Usually settles in 5 days"),
    worst: (one: "Worst: 1 day overdue", other: "Worst: 5 days overdue"),
    nameNetOldest: (one: "Asha, net $120.00, oldest 1 day", other: "Asha, net $120.00, oldest 5 days"),
    typicallySettledMedian: (
        one: "Typically settled in 1 day, median of 4 settled debts",
        other: "Typically settled in 5 days, median of 4 settled debts"
    ),
    syncEvents: (
        a1b3: "1 sync event needs review. 3 were auto-resolved.",
        a3b1: "3 sync events need review. 1 was auto-resolved."
    ),
    overdueRisk: (
        a1d1e1: "1 overdue debt, $120.00 outstanding, worst 1 day overdue, 1 due in the next 7 days",
        a3d5e2: "3 overdue debts, $120.00 outstanding, worst 5 days overdue, 2 due in the next 7 days"
    )
)

private let hindiExpectations = PluralExpectations(
    transactions: (one: "1 ट्रांज़ैक्शन", other: "5 ट्रांज़ैक्शन"),
    debts: (one: "1 उधार", other: "5 उधार"),
    goalsPastDeadline: (
        one: "1 लक्ष्य की समय-सीमा बीत चुकी है",
        other: "5 लक्ष्यों की समय-सीमा बीत चुकी है"
    ),
    monthsOfHistory: (one: "1 महीने का उपलब्ध इतिहास", other: "5 महीनों का उपलब्ध इतिहास"),
    overdueDebts: (one: "1 अतिदेय उधार", other: "5 अतिदेय उधार"),
    usuallySettlesComma: (
        one: ", आमतौर पर 1 दिन में चुकता है",
        other: ", आमतौर पर 5 दिन में चुकता है"
    ),
    basedOnMonths: (
        one: "आपकी समय-सीमा तक बचे 1 महीने के आधार पर।",
        other: "आपकी समय-सीमा तक बचे 5 महीनों के आधार पर।"
    ),
    oldest: (one: "सबसे पुराना: 1 दिन", other: "सबसे पुराना: 5 दिन"),
    repaired: (one: "1 अकाउंट बैलेंस ठीक किया गया।", other: "5 अकाउंट बैलेंस ठीक किए गए।"),
    typicallySettled: (one: "आमतौर पर 1 दिन में चुकता है", other: "आमतौर पर 5 दिन में चुकता है"),
    usuallySettles: (one: "आमतौर पर 1 दिन में चुकता है", other: "आमतौर पर 5 दिन में चुकता है"),
    worst: (one: "सबसे ज़्यादा: 1 दिन का विलंब", other: "सबसे ज़्यादा: 5 दिन का विलंब"),
    nameNetOldest: (
        one: "Asha, नेट $120.00, सबसे पुराना 1 दिन",
        other: "Asha, नेट $120.00, सबसे पुराना 5 दिन"
    ),
    typicallySettledMedian: (
        one: "आमतौर पर 1 दिन में चुकता है, 4 चुकाए गए उधारों की माध्यिका",
        other: "आमतौर पर 5 दिन में चुकता है, 4 चुकाए गए उधारों की माध्यिका"
    ),
    syncEvents: (
        a1b3: "1 सिंक इवेंट की समीक्षा ज़रूरी है। 3 अपने-आप हल हो गए।",
        a3b1: "3 सिंक इवेंट की समीक्षा ज़रूरी है। 1 अपने-आप हल हो गया।"
    ),
    overdueRisk: (
        a1d1e1: "1 अतिदेय उधार, $120.00 बकाया, सबसे अधिक 1 दिन का विलंब, अगले 7 दिनों में 1 देय",
        a3d5e2: "3 अतिदेय उधार, $120.00 बकाया, सबसे अधिक 5 दिन का विलंब, अगले 7 दिनों में 2 देय"
    )
)

private let spanishExpectations = PluralExpectations(
    transactions: (one: "1 transacción", other: "5 transacciones"),
    debts: (one: "1 deuda", other: "5 deudas"),
    goalsPastDeadline: (one: "1 meta vencida", other: "5 metas vencidas"),
    monthsOfHistory: (one: "1 mes de historial disponible", other: "5 meses de historial disponible"),
    overdueDebts: (one: "1 deuda vencida", other: "5 deudas vencidas"),
    usuallySettlesComma: (
        one: ", normalmente se salda en 1 día",
        other: ", normalmente se salda en 5 días"
    ),
    basedOnMonths: (
        one: "Según 1 mes hasta su fecha límite.",
        other: "Según 5 meses hasta su fecha límite."
    ),
    oldest: (one: "Más antiguo: 1 día", other: "Más antiguo: 5 días"),
    repaired: (one: "Se reparó 1 saldo de cuenta.", other: "Se repararon 5 saldos de cuenta."),
    typicallySettled: (one: "Normalmente se salda en 1 día", other: "Normalmente se salda en 5 días"),
    usuallySettles: (one: "Suele saldarse en 1 día", other: "Suele saldarse en 5 días"),
    worst: (one: "Peor: 1 día de retraso", other: "Peor: 5 días de retraso"),
    nameNetOldest: (
        one: "Asha, neto $120.00, más antiguo 1 día",
        other: "Asha, neto $120.00, más antiguo 5 días"
    ),
    typicallySettledMedian: (
        one: "Normalmente se salda en 1 día, mediana de 4 deudas saldadas",
        other: "Normalmente se salda en 5 días, mediana de 4 deudas saldadas"
    ),
    syncEvents: (
        a1b3: "1 evento de sincronización requiere revisión. 3 se resolvieron automáticamente.",
        a3b1: "3 eventos de sincronización requieren revisión. 1 se resolvió automáticamente."
    ),
    overdueRisk: (
        a1d1e1: "1 deuda vencida, $120.00 pendiente, la peor con 1 día de retraso, 1 vence en los próximos 7 días",
        a3d5e2: "3 deudas vencidas, $120.00 pendiente, la peor con 5 días de retraso, 2 vencen en los próximos 7 días"
    )
)

private func assertPlurals(lang: String, expectations: PluralExpectations) throws {
    let lproj = try #require(Bundle.main.path(forResource: lang, ofType: "lproj"))
    let bundle = try #require(Bundle(path: lproj))
    let locale = Locale(identifier: lang)

    let name = "Asha"
    let net = "$120.00"
    let amount = "$120.00"

    #expect(String(localized: "\(1) transactions", bundle: bundle, locale: locale) == expectations.transactions.one)
    #expect(String(localized: "\(5) transactions", bundle: bundle, locale: locale) == expectations.transactions.other)

    #expect(String(localized: "\(1) debts", bundle: bundle, locale: locale) == expectations.debts.one)
    #expect(String(localized: "\(5) debts", bundle: bundle, locale: locale) == expectations.debts.other)

    #expect(String(localized: "\(1) goals past deadline", bundle: bundle, locale: locale) == expectations.goalsPastDeadline.one)
    #expect(String(localized: "\(5) goals past deadline", bundle: bundle, locale: locale) == expectations.goalsPastDeadline.other)

    #expect(String(localized: "\(1) months of available history", bundle: bundle, locale: locale) == expectations.monthsOfHistory.one)
    #expect(String(localized: "\(5) months of available history", bundle: bundle, locale: locale) == expectations.monthsOfHistory.other)

    #expect(String(localized: "\(1) overdue debts", bundle: bundle, locale: locale) == expectations.overdueDebts.one)
    #expect(String(localized: "\(5) overdue debts", bundle: bundle, locale: locale) == expectations.overdueDebts.other)

    #expect(String(localized: ", usually settles in \(1) days", bundle: bundle, locale: locale) == expectations.usuallySettlesComma.one)
    #expect(String(localized: ", usually settles in \(5) days", bundle: bundle, locale: locale) == expectations.usuallySettlesComma.other)

    #expect(String(localized: "Based on \(1) months until your deadline.", bundle: bundle, locale: locale) == expectations.basedOnMonths.one)
    #expect(String(localized: "Based on \(5) months until your deadline.", bundle: bundle, locale: locale) == expectations.basedOnMonths.other)

    #expect(String(localized: "Oldest: \(1) days", bundle: bundle, locale: locale) == expectations.oldest.one)
    #expect(String(localized: "Oldest: \(5) days", bundle: bundle, locale: locale) == expectations.oldest.other)

    #expect(String(localized: "Repaired \(1) account balances.", bundle: bundle, locale: locale) == expectations.repaired.one)
    #expect(String(localized: "Repaired \(5) account balances.", bundle: bundle, locale: locale) == expectations.repaired.other)

    #expect(String(localized: "Typically settled in \(1) days", bundle: bundle, locale: locale) == expectations.typicallySettled.one)
    #expect(String(localized: "Typically settled in \(5) days", bundle: bundle, locale: locale) == expectations.typicallySettled.other)

    #expect(String(localized: "Usually settles in \(1) days", bundle: bundle, locale: locale) == expectations.usuallySettles.one)
    #expect(String(localized: "Usually settles in \(5) days", bundle: bundle, locale: locale) == expectations.usuallySettles.other)

    #expect(String(localized: "Worst: \(1) days overdue", bundle: bundle, locale: locale) == expectations.worst.one)
    #expect(String(localized: "Worst: \(5) days overdue", bundle: bundle, locale: locale) == expectations.worst.other)

    #expect(String(localized: "\(name), net \(net), oldest \(1) days", bundle: bundle, locale: locale) == expectations.nameNetOldest.one)
    #expect(String(localized: "\(name), net \(net), oldest \(5) days", bundle: bundle, locale: locale) == expectations.nameNetOldest.other)

    #expect(
        String(localized: "Typically settled in \(1) days, median of \(4) settled debts", bundle: bundle, locale: locale)
            == expectations.typicallySettledMedian.one
    )
    #expect(
        String(localized: "Typically settled in \(5) days, median of \(4) settled debts", bundle: bundle, locale: locale)
            == expectations.typicallySettledMedian.other
    )

    #expect(
        String(localized: "\(1) sync events need review. \(3) were auto-resolved.", bundle: bundle, locale: locale)
            == expectations.syncEvents.a1b3
    )
    #expect(
        String(localized: "\(3) sync events need review. \(1) were auto-resolved.", bundle: bundle, locale: locale)
            == expectations.syncEvents.a3b1
    )

    #expect(
        String(
            localized: "\(1) overdue debts, \(amount) outstanding, worst \(1) days overdue, \(1) due in the next 7 days",
            bundle: bundle,
            locale: locale
        ) == expectations.overdueRisk.a1d1e1
    )
    #expect(
        String(
            localized: "\(3) overdue debts, \(amount) outstanding, worst \(5) days overdue, \(2) due in the next 7 days",
            bundle: bundle,
            locale: locale
        ) == expectations.overdueRisk.a3d5e2
    )
}
