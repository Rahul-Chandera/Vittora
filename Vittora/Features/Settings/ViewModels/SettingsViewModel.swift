import Foundation
import SwiftUI
import VittoraCore
#if os(iOS)
import WidgetKit
#endif

@Observable
@MainActor
final class SettingsViewModel {
    private let keychainService: any KeychainServiceProtocol
    private let keychainWriter: KeychainSettingsWriter

    // Non-sensitive preferences remain in UserDefaults
    var selectedCurrencyCode: String {
        get {
            access(keyPath: \.selectedCurrencyCode)
            return UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.currencyCode) ?? CurrencyDefaults.code
        }
        set {
            withMutation(keyPath: \.selectedCurrencyCode) {
                UserDefaults.standard.set(newValue, forKey: AppUserDefaults.StandardKey.currencyCode)
                // Mirror for widget/extension processes (do not move primary storage).
                AppUserDefaults.mirrorCurrencyCodeToAppGroup()
                #if os(iOS)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
            }
        }
    }

    var appearanceMode: AppearanceMode {
        get {
            // access/withMutation so @Observable tracks this UserDefaults-backed
            // property; without them, changing the theme never refreshes the
            // checkmark or the app's preferredColorScheme.
            access(keyPath: \.appearanceMode)
            return AppearanceMode(
                rawValue: UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.appearanceMode) ?? ""
            ) ?? .system
        }
        set {
            withMutation(keyPath: \.appearanceMode) {
                UserDefaults.standard.set(newValue.rawValue, forKey: AppUserDefaults.StandardKey.appearanceMode)
            }
        }
    }

    var accentColor: AccentColor {
        get {
            access(keyPath: \.accentColor)
            return AccentColor(
                rawValue: UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.accentColor) ?? ""
            ) ?? .brandGreen
        }
        set {
            withMutation(keyPath: \.accentColor) {
                UserDefaults.standard.set(newValue.rawValue, forKey: AppUserDefaults.StandardKey.accentColor)
                AppUserDefaults.mirrorAccentColorToAppGroup()
                #if os(iOS)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
            }
        }
    }

    var isNotificationsEnabled: Bool {
        get {
            access(keyPath: \.isNotificationsEnabled)
            return UserDefaults.standard.bool(forKey: AppUserDefaults.StandardKey.notificationsEnabled)
        }
        set {
            withMutation(keyPath: \.isNotificationsEnabled) {
                UserDefaults.standard.set(newValue, forKey: AppUserDefaults.StandardKey.notificationsEnabled)
            }
        }
    }

    var notifyBillsDue: Bool {
        get {
            access(keyPath: \.notifyBillsDue)
            return UserDefaults.standard.object(forKey: AppUserDefaults.StandardKey.notifyBillsDue) as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.notifyBillsDue) {
                UserDefaults.standard.set(newValue, forKey: AppUserDefaults.StandardKey.notifyBillsDue)
            }
        }
    }

    var notifyBudgetAlerts: Bool {
        get {
            access(keyPath: \.notifyBudgetAlerts)
            return UserDefaults.standard.object(forKey: AppUserDefaults.StandardKey.notifyBudgetAlerts) as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.notifyBudgetAlerts) {
                UserDefaults.standard.set(newValue, forKey: AppUserDefaults.StandardKey.notifyBudgetAlerts)
            }
        }
    }

    var notifyGoalMilestones: Bool {
        get {
            access(keyPath: \.notifyGoalMilestones)
            return UserDefaults.standard.object(forKey: AppUserDefaults.StandardKey.notifyGoalMilestones) as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.notifyGoalMilestones) {
                UserDefaults.standard.set(newValue, forKey: AppUserDefaults.StandardKey.notifyGoalMilestones)
            }
        }
    }

    var notifyRecurringTransactions: Bool {
        get {
            access(keyPath: \.notifyRecurringTransactions)
            return UserDefaults.standard.object(forKey: AppUserDefaults.StandardKey.notifyRecurring) as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.notifyRecurringTransactions) {
                UserDefaults.standard.set(newValue, forKey: AppUserDefaults.StandardKey.notifyRecurring)
            }
        }
    }

    var notificationDeliveryTime: Date {
        get {
            access(keyPath: \.notificationDeliveryTime)
            return notificationTime(
                forKey: AppUserDefaults.StandardKey.notificationDeliveryTime,
                defaultMinutes: NotificationSchedulePreferences.defaultDeliveryMinutes
            )
        }
        set {
            withMutation(keyPath: \.notificationDeliveryTime) {
                storeNotificationTime(
                    newValue,
                    forKey: AppUserDefaults.StandardKey.notificationDeliveryTime
                )
            }
        }
    }

    var notificationQuietHoursEnabled: Bool {
        get {
            access(keyPath: \.notificationQuietHoursEnabled)
            return UserDefaults.standard.bool(
                forKey: AppUserDefaults.StandardKey.notificationQuietHoursEnabled
            )
        }
        set {
            withMutation(keyPath: \.notificationQuietHoursEnabled) {
                UserDefaults.standard.set(
                    newValue,
                    forKey: AppUserDefaults.StandardKey.notificationQuietHoursEnabled
                )
            }
        }
    }

    var notificationQuietHoursStart: Date {
        get {
            access(keyPath: \.notificationQuietHoursStart)
            return notificationTime(
                forKey: AppUserDefaults.StandardKey.notificationQuietHoursStart,
                defaultMinutes: NotificationSchedulePreferences.defaultQuietStartMinutes
            )
        }
        set {
            withMutation(keyPath: \.notificationQuietHoursStart) {
                storeNotificationTime(
                    newValue,
                    forKey: AppUserDefaults.StandardKey.notificationQuietHoursStart
                )
            }
        }
    }

    var notificationQuietHoursEnd: Date {
        get {
            access(keyPath: \.notificationQuietHoursEnd)
            return notificationTime(
                forKey: AppUserDefaults.StandardKey.notificationQuietHoursEnd,
                defaultMinutes: NotificationSchedulePreferences.defaultQuietEndMinutes
            )
        }
        set {
            withMutation(keyPath: \.notificationQuietHoursEnd) {
                storeNotificationTime(
                    newValue,
                    forKey: AppUserDefaults.StandardKey.notificationQuietHoursEnd
                )
            }
        }
    }

    var billReminderLeadDays: Int {
        get {
            access(keyPath: \.billReminderLeadDays)
            return NotificationSchedulePreferences.billLeadDays(in: .standard)
        }
        set {
            withMutation(keyPath: \.billReminderLeadDays) {
                UserDefaults.standard.set(
                    newValue,
                    forKey: AppUserDefaults.StandardKey.billReminderLeadDays
                )
            }
        }
    }

    private func notificationTime(forKey key: String, defaultMinutes: Int) -> Date {
        let minutes = UserDefaults.standard.object(forKey: key) as? Int ?? defaultMinutes
        return Calendar.current.date(
            bySettingHour: minutes / 60,
            minute: minutes % 60,
            second: 0,
            of: .now
        ) ?? .now
    }

    private func storeNotificationTime(_ date: Date, forKey key: String) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        UserDefaults.standard.set(
            (components.hour ?? 0) * 60 + (components.minute ?? 0),
            forKey: key
        )
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
            access(keyPath: \.exportSchedule)
            return ExportSchedule(
                rawValue: UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.exportSchedule) ?? ""
            ) ?? .off
        }
        set {
            withMutation(keyPath: \.exportSchedule) {
                UserDefaults.standard.set(newValue.rawValue, forKey: AppUserDefaults.StandardKey.exportSchedule)
            }
        }
    }

    var isCloudSyncEnabled: Bool {
        get {
            access(keyPath: \.isCloudSyncEnabled)
            return UserDefaults.standard.bool(forKey: AppUserDefaults.StandardKey.cloudSyncEnabled)
        }
        set {
            withMutation(keyPath: \.isCloudSyncEnabled) {
                UserDefaults.standard.set(newValue, forKey: AppUserDefaults.StandardKey.cloudSyncEnabled)
            }
        }
    }

    /// Show transactions in system Search / Spotlight (default ON). Amounts are
    /// visible outside App Lock by OS design — turning OFF clears the index.
    var isSpotlightIndexingEnabled: Bool {
        get {
            access(keyPath: \.isSpotlightIndexingEnabled)
            return TransactionSpotlightIndex.isIndexingEnabled()
        }
        set {
            withMutation(keyPath: \.isSpotlightIndexingEnabled) {
                TransactionSpotlightIndex.setIndexingEnabled(newValue)
            }
        }
    }

    var appLockTimeout: AppLockTimeout {
        get {
            access(keyPath: \.appLockTimeout)
            return AppLockTimeout(
                rawValue: UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.appLockTimeout) ?? ""
            ) ?? .fiveMinutes
        }
        set {
            withMutation(keyPath: \.appLockTimeout) {
                UserDefaults.standard.set(newValue.rawValue, forKey: AppUserDefaults.StandardKey.appLockTimeout)
            }
        }
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

    /// Re-reads the display name (keychain) and re-publishes the currency
    /// (UserDefaults) after they were written outside this view model — e.g.
    /// during onboarding — so the live UI reflects them without an app restart.
    func reloadPersistedProfile() {
        let name: String
        if let data = KeychainService.syncLoad(forKey: AppUserDefaults.KeychainKey.userName),
           let decoded = String(data: data, encoding: .utf8) {
            name = decoded
        } else {
            name = ""
        }
        withMutation(keyPath: \.userName) {
            _userName = name
        }
        // selectedCurrencyCode reads UserDefaults live; nudge observers to re-read.
        withMutation(keyPath: \.selectedCurrencyCode) {}
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

        if ProcessInfo.processInfo.arguments.contains("--ui-test-app-lock") {
            _isAppLockEnabled = true
            UserDefaults.standard.set(
                AppLockTimeout.immediately.rawValue,
                forKey: AppUserDefaults.StandardKey.appLockTimeout
            )
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
        case system, light, dark, oledBlack

        var displayName: String {
            switch self {
            case .system: return String(localized: "System")
            case .light:  return String(localized: "Light")
            case .dark:   return String(localized: "Dark")
            case .oledBlack: return String(localized: "OLED Black")
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark, .oledBlack: return .dark
            }
        }
    }

    enum AccentColor: String, CaseIterable, Sendable {
        case brandGreen, blue, purple, orange

        var displayName: String {
            switch self {
            case .brandGreen: return String(localized: "Brand Green")
            case .blue: return String(localized: "Blue")
            case .purple: return String(localized: "Purple")
            case .orange: return String(localized: "Orange")
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
