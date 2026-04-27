import Foundation
import SwiftUI

@Observable
@MainActor
final class SettingsViewModel {
    private let keychainService: any KeychainServiceProtocol

    // Non-sensitive preferences remain in UserDefaults
    var selectedCurrencyCode: String {
        get { UserDefaults.standard.string(forKey: "vittora.currencyCode") ?? CurrencyDefaults.code }
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

    var notifyBillsDue: Bool {
        get { UserDefaults.standard.object(forKey: "vittora.notifyBillsDue") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "vittora.notifyBillsDue") }
    }

    var notifyBudgetAlerts: Bool {
        get { UserDefaults.standard.object(forKey: "vittora.notifyBudgetAlerts") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "vittora.notifyBudgetAlerts") }
    }

    var notifyGoalMilestones: Bool {
        get { UserDefaults.standard.object(forKey: "vittora.notifyGoalMilestones") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "vittora.notifyGoalMilestones") }
    }

    var notifyRecurringTransactions: Bool {
        get { UserDefaults.standard.object(forKey: "vittora.notifyRecurring") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "vittora.notifyRecurring") }
    }

    @ObservationIgnored private var _allowPasscodeFallback: Bool
    var allowPasscodeFallback: Bool {
        get {
            access(keyPath: \.allowPasscodeFallback)
            return _allowPasscodeFallback
        }
        set {
            withMutation(keyPath: \.allowPasscodeFallback) {
                _allowPasscodeFallback = newValue
            }
            Task { [keychainService] in
                do {
                    try await keychainService.save(Data([newValue ? 1 : 0]), forKey: "vittora.passcodeFallback")
                } catch {
                    keychainError = error.localizedDescription
                }
            }
        }
    }

    var exportSchedule: ExportSchedule {
        get { ExportSchedule(rawValue: UserDefaults.standard.string(forKey: "vittora.exportSchedule") ?? "") ?? .off }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "vittora.exportSchedule") }
    }

    var isCloudSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "vittora.cloudSyncEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "vittora.cloudSyncEnabled") }
    }

    enum ExportSchedule: String, CaseIterable, Sendable {
        case off, weekly, monthly

        var displayName: String {
            switch self {
            case .off:     return String(localized: "Off")
            case .weekly:  return String(localized: "Weekly")
            case .monthly: return String(localized: "Monthly")
            }
        }
    }

    // MARK: - Keychain-backed sensitive properties

    var keychainError: String?

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
                do {
                    try await keychainService.save(Data([newValue ? 1 : 0]), forKey: "vittora.appLockEnabled")
                } catch {
                    keychainError = error.localizedDescription
                }
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
                do {
                    if newValue.isEmpty {
                        try await keychainService.delete(forKey: "vittora.userName")
                    } else if let data = newValue.data(using: .utf8) {
                        try await keychainService.save(data, forKey: "vittora.userName")
                    }
                } catch {
                    keychainError = error.localizedDescription
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

        // passcodeFallback: read from Keychain; migrate from UserDefaults on first upgrade
        if let data = KeychainService.syncLoad(forKey: "vittora.passcodeFallback") {
            _allowPasscodeFallback = data.first == 1
        } else {
            let udValue = UserDefaults.standard.object(forKey: "vittora.passcodeFallback") as? Bool ?? true
            _allowPasscodeFallback = udValue
            KeychainService.syncSave(Data([udValue ? 1 : 0]), forKey: "vittora.passcodeFallback")
            UserDefaults.standard.removeObject(forKey: "vittora.passcodeFallback")
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
