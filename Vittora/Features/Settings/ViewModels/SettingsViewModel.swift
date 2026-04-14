import Foundation
import SwiftUI

@Observable
@MainActor
final class SettingsViewModel {
    // Currency
    var selectedCurrencyCode: String {
        get { UserDefaults.standard.string(forKey: "vittora.currencyCode") ?? "USD" }
        set { UserDefaults.standard.set(newValue, forKey: "vittora.currencyCode") }
    }

    // Appearance
    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: UserDefaults.standard.string(forKey: "vittora.appearanceMode") ?? "") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "vittora.appearanceMode") }
    }

    // App lock
    var isAppLockEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "vittora.appLockEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "vittora.appLockEnabled") }
    }

    // Notifications
    var isNotificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "vittora.notificationsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "vittora.notificationsEnabled") }
    }

    // iCloud Sync
    var isCloudSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "vittora.cloudSyncEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "vittora.cloudSyncEnabled") }
    }

    // User profile
    var userName: String {
        get { UserDefaults.standard.string(forKey: "vittora.userName") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "vittora.userName") }
    }

    // App version
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    let supportedCurrencies: [(code: String, name: String)] = [
        ("USD", "US Dollar ($)"),
        ("INR", "Indian Rupee (₹)"),
        ("EUR", "Euro (€)"),
        ("GBP", "British Pound (£)"),
        ("JPY", "Japanese Yen (¥)"),
        ("CAD", "Canadian Dollar (CA$)"),
        ("AUD", "Australian Dollar (A$)"),
        ("SGD", "Singapore Dollar (S$)"),
        ("AED", "UAE Dirham (AED)"),
    ]

    enum AppearanceMode: String, CaseIterable, Sendable {
        case system, light, dark

        var displayName: String {
            switch self {
            case .system: return String(localized: "System")
            case .light:  return String(localized: "Light")
            case .dark:   return String(localized: "Dark")
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }
    }
}
