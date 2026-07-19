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
        let originalStandard = UserDefaults.standard.string(forKey: key)
        let originalGroup = AppUserDefaults.appGroup.string(forKey: key)
        defer {
            restore(key, originalStandard, on: .standard)
            restore(key, originalGroup, on: AppUserDefaults.appGroup)
        }

        UserDefaults.standard.set("USD", forKey: key)
        #expect(CurrencyDefaults.code == "USD")

        UserDefaults.standard.set("EUR", forKey: key)
        #expect(CurrencyDefaults.code == "EUR")
    }

    @Test("code falls back to the locale when no currency is persisted")
    func testCodeFallsBackToLocale() {
        let key = AppUserDefaults.StandardKey.currencyCode
        let originalStandard = UserDefaults.standard.string(forKey: key)
        let originalGroup = AppUserDefaults.appGroup.string(forKey: key)
        defer {
            restore(key, originalStandard, on: .standard)
            restore(key, originalGroup, on: AppUserDefaults.appGroup)
        }

        // Clear both stores: `.standard` is authoritative in-app, but the App
        // Group mirror (written for widgets) must also be empty or it shadows
        // the locale fallback. Synchronize so CFPreferences doesn't serve a
        // stale mirrored value from a prior process write.
        UserDefaults.standard.removeObject(forKey: key)
        AppUserDefaults.appGroup.removeObject(forKey: key)
        UserDefaults.standard.synchronize()
        AppUserDefaults.appGroup.synchronize()
        let expected = Locale.current.currency?.identifier ?? CurrencyDefaults.fallbackCode
        #expect(CurrencyDefaults.code == expected)
    }

    private func restore(_ key: String, _ value: String?, on defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
