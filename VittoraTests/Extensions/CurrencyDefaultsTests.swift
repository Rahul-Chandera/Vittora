import Foundation
import Testing
import VittoraCore

/// `CurrencyDefaults.code` must reflect the user's chosen currency, not the
/// device locale. Regression guard for the bug where components defaulting to
/// `CurrencyDefaults.code` (VAmountText, budget cards, charts) showed the
/// locale currency (₹ on an India-region device) even with USD selected in
/// Settings.
@Suite("CurrencyDefaults", .serialized)
struct CurrencyDefaultsTests {

    @Test("code prefers the persisted app currency over the locale")
    func testCodePrefersPersistedCurrency() {
        let key = AppUserDefaults.StandardKey.currencyCode
        let original = UserDefaults.standard.string(forKey: key)
        defer {
            if let original {
                UserDefaults.standard.set(original, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.set("USD", forKey: key)
        #expect(CurrencyDefaults.code == "USD")

        UserDefaults.standard.set("EUR", forKey: key)
        #expect(CurrencyDefaults.code == "EUR")
    }

    @Test("code falls back to the locale when no currency is persisted")
    func testCodeFallsBackToLocale() {
        let key = AppUserDefaults.StandardKey.currencyCode
        let original = UserDefaults.standard.string(forKey: key)
        defer {
            if let original {
                UserDefaults.standard.set(original, forKey: key)
            }
        }

        UserDefaults.standard.removeObject(forKey: key)
        let expected = Locale.current.currency?.identifier ?? CurrencyDefaults.fallbackCode
        #expect(CurrencyDefaults.code == expected)
    }
}
