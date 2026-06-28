import Foundation

/// Applies notification preference changes from Settings (UX-4 / C6).
struct ApplyNotificationPreferencesUseCase: Sendable {
    nonisolated static let notificationsEnabledKey = AppUserDefaults.StandardKey.notificationsEnabled

    nonisolated(unsafe) let notificationService: any NotificationServiceProtocol
    nonisolated(unsafe) let refreshAllSchedules: @Sendable () async -> Void
    nonisolated(unsafe) let userDefaults: UserDefaults

    nonisolated init(
        notificationService: any NotificationServiceProtocol,
        refreshAllSchedules: @escaping @Sendable () async -> Void,
        userDefaults: UserDefaults = .standard
    ) {
        self.notificationService = notificationService
        self.refreshAllSchedules = refreshAllSchedules
        self.userDefaults = userDefaults
    }

    /// Requests OS authorization, persists master intent, and refreshes or clears schedules.
    @discardableResult
    func enableNotifications() async throws -> Bool {
        let granted = try await notificationService.requestAuthorization()
        userDefaults.set(granted, forKey: Self.notificationsEnabledKey)
        if granted {
            await refreshAllSchedules()
        } else {
            await notificationService.cancelAllPending()
        }
        return granted
    }

    func disableNotifications() async {
        userDefaults.set(false, forKey: Self.notificationsEnabledKey)
        await notificationService.cancelAllPending()
    }

    func applySubToggleChange() async {
        guard userDefaults.bool(forKey: Self.notificationsEnabledKey) else { return }
        await refreshAllSchedules()
    }
}
