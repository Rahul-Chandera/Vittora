import Foundation
import Testing
import VittoraCore

/// `CurrencyDefaults.code` must reflect the user's chosen currency, not the
/// device locale. Regression guard for the bug where components defaulting to
/// `CurrencyDefaults.code` (VAmountText, budget cards, charts) showed the
/// locale currency (₹ on an India-region device) even with USD selected in
/// Settings.
@Suite("CurrencyDefaults")
struct CurrencyDefaultsTests {

    @Test("code prefers the persisted app currency over the locale")
    func testCodePrefersPersistedCurrency() {
        let suiteName = "CurrencyDefaultsTests.\(UUID().uuidString)"
        let standard = UserDefaults(suiteName: suiteName) ?? .standard
        let groupName = "CurrencyDefaultsTests.group.\(UUID().uuidString)"
        let group = UserDefaults(suiteName: groupName) ?? .standard
        defer {
            standard.removePersistentDomain(forName: suiteName)
            group.removePersistentDomain(forName: groupName)
        }
        let key = AppUserDefaults.StandardKey.currencyCode

        standard.set("USD", forKey: key)
        #expect(CurrencyDefaults.code(userDefaults: standard, groupDefaults: group) == "USD")

        standard.set("EUR", forKey: key)
        #expect(CurrencyDefaults.code(userDefaults: standard, groupDefaults: group) == "EUR")
    }

    @Test("code falls back to the locale when no currency is persisted")
    func testCodeFallsBackToLocale() {
        let suiteName = "CurrencyDefaultsTests.\(UUID().uuidString)"
        let standard = UserDefaults(suiteName: suiteName) ?? .standard
        let groupName = "CurrencyDefaultsTests.group.\(UUID().uuidString)"
        let group = UserDefaults(suiteName: groupName) ?? .standard
        defer {
            standard.removePersistentDomain(forName: suiteName)
            group.removePersistentDomain(forName: groupName)
        }
        let key = AppUserDefaults.StandardKey.currencyCode

        #expect(standard.string(forKey: key) == nil)
        #expect(group.string(forKey: key) == nil)
        let expected = Locale.current.currency?.identifier ?? CurrencyDefaults.fallbackCode
        #expect(CurrencyDefaults.code(userDefaults: standard, groupDefaults: group) == expected)
    }
}
