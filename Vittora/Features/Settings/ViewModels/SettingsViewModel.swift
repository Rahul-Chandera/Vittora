import Foundation
import SwiftUI

@Observable
@MainActor
final class SettingsViewModel {
    private let keychainService: any KeychainServiceProtocol

    // Non-sensitive preferences remain in UserDefaults
    var selectedCurrencyCode: String {
        get { UserDefaults.standard.string(forKey: "vittora.currencyCode") ?? "USD" }
        set { UserDefaults.standard.set(newValue, forKey: "vittora.currencyCode") }
    }

    var appearanceMode: AppearanceMode {
        get {
            AppearanceMode(rawValue: UserDefaults.standard.string(forKey: "vittora.appearanceMode") ?? "") ?? .system
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "vittora.appearanceMode") }
    }

    var isNotificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "vittora.notificationsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "vittora.notificationsEnabled") }
    }

    var isCloudSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "vittora.cloudSyncEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "vittora.cloudSyncEnabled") }
    }

    // MARK: - Keychain-backed sensitive properties

    @ObservationIgnored private var _isAppLockEnabled: Bool
    var isAppLockEnabled: Bool {
        get {
            access(keyPath: \.isAppLockEnabled)
            return _isAppLockEnabled
        }
        set {
            withMutation(keyPath: \.isAppLockEnabled) {
                _isAppLockEnabled = newValue
            }
            Task { [keychainService] in
                try? await keychainService.save(Data([newValue ? 1 : 0]), forKey: "vittora.appLockEnabled")
            }
        }
    }

    @ObservationIgnored private var _userName: String
    var userName: String {
        get {
            access(keyPath: \.userName)
            return _userName
        }
        set {
            withMutation(keyPath: \.userName) {
                _userName = newValue
            }
            Task { [keychainService] in
                if newValue.isEmpty {
                    try? await keychainService.delete(forKey: "vittora.userName")
                } else if let data = newValue.data(using: .utf8) {
                    try? await keychainService.save(data, forKey: "vittora.userName")
                }
            }
        }
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

    /// Pass `nil` to use the default `KeychainService` (production path).
    init(keychainService: (any KeychainServiceProtocol)? = nil) {
        self.keychainService = keychainService ?? KeychainService()

        // appLockEnabled: read from Keychain; migrate from UserDefaults on first upgrade
        if let data = KeychainService.syncLoad(forKey: "vittora.appLockEnabled") {
            _isAppLockEnabled = data.first == 1
        } else {
            let udValue = UserDefaults.standard.bool(forKey: "vittora.appLockEnabled")
            _isAppLockEnabled = udValue
            KeychainService.syncSave(Data([udValue ? 1 : 0]), forKey: "vittora.appLockEnabled")
            UserDefaults.standard.removeObject(forKey: "vittora.appLockEnabled")
        }

        // userName: read from Keychain; migrate from UserDefaults on first upgrade
        if let data = KeychainService.syncLoad(forKey: "vittora.userName"),
           let name = String(data: data, encoding: .utf8) {
            _userName = name
        } else {
            let udValue = UserDefaults.standard.string(forKey: "vittora.userName") ?? ""
            _userName = udValue
            if !udValue.isEmpty, let data = udValue.data(using: .utf8) {
                KeychainService.syncSave(data, forKey: "vittora.userName")
            }
            UserDefaults.standard.removeObject(forKey: "vittora.userName")
        }
    }

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
