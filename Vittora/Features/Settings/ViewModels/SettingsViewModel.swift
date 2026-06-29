import Foundation
import SwiftUI
import VittoraCore

@Observable
@MainActor
final class SettingsViewModel {
    private let keychainService: any KeychainServiceProtocol
    private let keychainWriter: KeychainSettingsWriter

    // Non-sensitive preferences remain in UserDefaults
    var selectedCurrencyCode: String {
        get { UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.currencyCode) ?? CurrencyDefaults.code }
        set { UserDefaults.standard.set(newValue, forKey: AppUserDefaults.StandardKey.currencyCode) }
    }

    var appearanceMode: AppearanceMode {
        get {
            AppearanceMode(
                rawValue: UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.appearanceMode) ?? ""
            ) ?? .system
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: AppUserDefaults.StandardKey.appearanceMode) }
    }

    var isNotificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: AppUserDefaults.StandardKey.notificationsEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: AppUserDefaults.StandardKey.notificationsEnabled) }
    }

    var notifyBillsDue: Bool {
        get { UserDefaults.standard.object(forKey: AppUserDefaults.StandardKey.notifyBillsDue) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: AppUserDefaults.StandardKey.notifyBillsDue) }
    }

    var notifyBudgetAlerts: Bool {
        get { UserDefaults.standard.object(forKey: AppUserDefaults.StandardKey.notifyBudgetAlerts) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: AppUserDefaults.StandardKey.notifyBudgetAlerts) }
    }

    var notifyGoalMilestones: Bool {
        get { UserDefaults.standard.object(forKey: AppUserDefaults.StandardKey.notifyGoalMilestones) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: AppUserDefaults.StandardKey.notifyGoalMilestones) }
    }

    var notifyRecurringTransactions: Bool {
        get { UserDefaults.standard.object(forKey: AppUserDefaults.StandardKey.notifyRecurring) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: AppUserDefaults.StandardKey.notifyRecurring) }
    }

    @ObservationIgnored private var _allowPasscodeFallback: Bool
    var allowPasscodeFallback: Bool {
        get {
            access(keyPath: \.allowPasscodeFallback)
            return _allowPasscodeFallback
        }
    }

    var exportSchedule: ExportSchedule {
        get {
            ExportSchedule(
                rawValue: UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.exportSchedule) ?? ""
            ) ?? .off
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: AppUserDefaults.StandardKey.exportSchedule) }
    }

    var isCloudSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: AppUserDefaults.StandardKey.cloudSyncEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: AppUserDefaults.StandardKey.cloudSyncEnabled) }
    }

    var appLockTimeout: AppLockTimeout {
        get {
            AppLockTimeout(
                rawValue: UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.appLockTimeout) ?? ""
            ) ?? .fiveMinutes
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: AppUserDefaults.StandardKey.appLockTimeout) }
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
    }

    func updateAppLockEnabled(_ newValue: Bool) async {
        let previous = _isAppLockEnabled
        withMutation(keyPath: \.isAppLockEnabled) {
            _isAppLockEnabled = newValue
        }
        keychainError = nil
        do {
            try await keychainWriter.saveAppLockEnabled(newValue)
        } catch {
            withMutation(keyPath: \.isAppLockEnabled) {
                _isAppLockEnabled = previous
            }
            keychainError = error.userFacingMessage(
                fallback: String(localized: "We couldn't save your security settings.")
            )
        }
    }

    /// Disables App Lock only after successful device authentication (SECURITY-3).
    func disableAppLockIfAuthenticated(using biometricService: any BiometricServiceProtocol) async -> Bool {
        guard isAppLockEnabled else { return true }
        do {
            guard try await SensitiveActionAuthenticator.confirm(
                action: .disableAppLock,
                using: biometricService
            ) else {
                return false
            }
            await updateAppLockEnabled(false)
            return !isAppLockEnabled
        } catch {
            keychainError = error.userFacingMessage(
                fallback: String(localized: "We couldn't update your security settings.")
            )
            return false
        }
    }

    func updateAllowPasscodeFallback(_ newValue: Bool) async {
        let previous = _allowPasscodeFallback
        withMutation(keyPath: \.allowPasscodeFallback) {
            _allowPasscodeFallback = newValue
        }
        keychainError = nil
        do {
            try await keychainWriter.savePasscodeFallback(newValue)
        } catch {
            withMutation(keyPath: \.allowPasscodeFallback) {
                _allowPasscodeFallback = previous
            }
            keychainError = error.userFacingMessage(
                fallback: String(localized: "We couldn't save your security settings.")
            )
        }
    }

    @ObservationIgnored private var _userName: String
    var userName: String {
        get {
            access(keyPath: \.userName)
            return _userName
        }
    }

    func updateUserName(_ newValue: String) async {
        let previous = _userName
        withMutation(keyPath: \.userName) {
            _userName = newValue
        }
        keychainError = nil
        do {
            try await keychainWriter.saveUserName(newValue)
        } catch {
            withMutation(keyPath: \.userName) {
                _userName = previous
            }
            keychainError = error.userFacingMessage(
                fallback: String(localized: "We couldn't save your profile name.")
            )
        }
    }

    func resetKeychainBackedPreferencesInMemory() {
        withMutation(keyPath: \.isAppLockEnabled) {
            _isAppLockEnabled = false
        }
        withMutation(keyPath: \.allowPasscodeFallback) {
            _allowPasscodeFallback = true
        }
        withMutation(keyPath: \.userName) {
            _userName = ""
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
        let service = keychainService ?? KeychainService()
        self.keychainService = service
        self.keychainWriter = KeychainSettingsWriter(service: service)

        if let data = KeychainService.syncLoad(forKey: AppUserDefaults.KeychainKey.appLockEnabled) {
            _isAppLockEnabled = data.first == 1
        } else {
            let udValue = UserDefaults.standard.bool(forKey: AppUserDefaults.StandardKey.appLockEnabledLegacy)
            _isAppLockEnabled = udValue
            KeychainService.syncSave(
                Data([udValue ? 1 : 0]),
                forKey: AppUserDefaults.KeychainKey.appLockEnabled
            )
            UserDefaults.standard.removeObject(forKey: AppUserDefaults.StandardKey.appLockEnabledLegacy)
        }

        if let data = KeychainService.syncLoad(forKey: AppUserDefaults.KeychainKey.passcodeFallback) {
            _allowPasscodeFallback = data.first == 1
        } else {
            let udValue = UserDefaults.standard.object(forKey: AppUserDefaults.StandardKey.passcodeFallbackLegacy) as? Bool ?? true
            _allowPasscodeFallback = udValue
            KeychainService.syncSave(
                Data([udValue ? 1 : 0]),
                forKey: AppUserDefaults.KeychainKey.passcodeFallback
            )
            UserDefaults.standard.removeObject(forKey: AppUserDefaults.StandardKey.passcodeFallbackLegacy)
        }

        if let data = KeychainService.syncLoad(forKey: AppUserDefaults.KeychainKey.userName),
           let name = String(data: data, encoding: .utf8) {
            _userName = name
        } else {
            let udValue = UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.userNameLegacy) ?? ""
            _userName = udValue
            if !udValue.isEmpty, let data = udValue.data(using: .utf8) {
                KeychainService.syncSave(data, forKey: AppUserDefaults.KeychainKey.userName)
            }
            UserDefaults.standard.removeObject(forKey: AppUserDefaults.StandardKey.userNameLegacy)
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

private actor KeychainSettingsWriter {
    private let service: any KeychainServiceProtocol

    init(service: any KeychainServiceProtocol) {
        self.service = service
    }

    func saveAppLockEnabled(_ enabled: Bool) async throws {
        try await service.save(
            Data([enabled ? 1 : 0]),
            forKey: AppUserDefaults.KeychainKey.appLockEnabled
        )
    }

    func savePasscodeFallback(_ allowed: Bool) async throws {
        try await service.save(
            Data([allowed ? 1 : 0]),
            forKey: AppUserDefaults.KeychainKey.passcodeFallback
        )
    }

    func saveUserName(_ name: String) async throws {
        if name.isEmpty {
            try await service.delete(forKey: AppUserDefaults.KeychainKey.userName)
        } else if let data = name.data(using: .utf8) {
            try await service.save(data, forKey: AppUserDefaults.KeychainKey.userName)
        }
    }
}
