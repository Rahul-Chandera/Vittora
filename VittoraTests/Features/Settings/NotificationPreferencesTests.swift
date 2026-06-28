import Foundation
import Testing
@testable import Vittora

@MainActor
@Suite("ApplyNotificationPreferencesUseCase Tests")
struct ApplyNotificationPreferencesUseCaseTests {
    private final class RefreshCounter: @unchecked Sendable {
        var count = 0
    }

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "ApplyNotificationPreferencesTests.\(UUID().uuidString)") ?? .standard
    }

    @Test("enable requests authorization and persists granted intent")
    func enableRequestsAuthorizationAndRefreshes() async throws {
        let notifications = MockNotificationService()
        notifications.requestAuthorizationResult = true
        let defaults = isolatedDefaults()
        let refreshCounter = RefreshCounter()
        let useCase = ApplyNotificationPreferencesUseCase(
            notificationService: notifications,
            refreshAllSchedules: { refreshCounter.count += 1 },
            userDefaults: defaults
        )

        let granted = try await useCase.enableNotifications()

        #expect(granted == true)
        #expect(notifications.requestAuthorizationCallCount == 1)
        #expect(defaults.bool(forKey: ApplyNotificationPreferencesUseCase.notificationsEnabledKey))
        #expect(refreshCounter.count == 1)
    }

    @Test("enable clears schedules when authorization is denied")
    func enableDeniedClearsSchedules() async throws {
        let notifications = MockNotificationService()
        notifications.requestAuthorizationResult = false
        let defaults = isolatedDefaults()
        let refreshCounter = RefreshCounter()
        let useCase = ApplyNotificationPreferencesUseCase(
            notificationService: notifications,
            refreshAllSchedules: { refreshCounter.count += 1 },
            userDefaults: defaults
        )

        let granted = try await useCase.enableNotifications()

        #expect(granted == false)
        #expect(defaults.bool(forKey: ApplyNotificationPreferencesUseCase.notificationsEnabledKey) == false)
        #expect(notifications.cancelAllPendingCallCount == 1)
        #expect(refreshCounter.count == 0)
    }

    @Test("disable cancels pending notifications")
    func disableCancelsPending() async {
        let notifications = MockNotificationService()
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: ApplyNotificationPreferencesUseCase.notificationsEnabledKey)
        let useCase = ApplyNotificationPreferencesUseCase(
            notificationService: notifications,
            refreshAllSchedules: {},
            userDefaults: defaults
        )

        await useCase.disableNotifications()

        #expect(defaults.bool(forKey: ApplyNotificationPreferencesUseCase.notificationsEnabledKey) == false)
        #expect(notifications.cancelAllPendingCallCount == 1)
    }

    @Test("sub-toggle change refreshes schedules when master is enabled")
    func subToggleRefreshWhenEnabled() async {
        let notifications = MockNotificationService()
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: ApplyNotificationPreferencesUseCase.notificationsEnabledKey)
        let refreshCounter = RefreshCounter()
        let useCase = ApplyNotificationPreferencesUseCase(
            notificationService: notifications,
            refreshAllSchedules: { refreshCounter.count += 1 },
            userDefaults: defaults
        )

        await useCase.applySubToggleChange()

        #expect(refreshCounter.count == 1)
    }

    @Test("sub-toggle change is ignored when master is disabled")
    func subToggleIgnoredWhenDisabled() async {
        let notifications = MockNotificationService()
        let defaults = isolatedDefaults()
        let refreshCounter = RefreshCounter()
        let useCase = ApplyNotificationPreferencesUseCase(
            notificationService: notifications,
            refreshAllSchedules: { refreshCounter.count += 1 },
            userDefaults: defaults
        )

        await useCase.applySubToggleChange()

        #expect(refreshCounter.count == 0)
    }

    @Test("disabling budget alerts cancels budget schedules on refresh")
    func disablingBudgetAlertsCancelsBudgetSchedules() async throws {
        let notifications = MockNotificationService()
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: "vittora.notificationsEnabled")
        defaults.set(false, forKey: "vittora.notifyBudgetAlerts")

        let budgetFetcher = StubBudgetFetcher(budgets: [
            BudgetEntity(amount: 1000, spent: 600, period: .monthly),
        ])
        let alertStore = InMemoryBudgetThresholdAlertStore()
        let budgetUseCase = EvaluateBudgetThresholdAlertsUseCase(
            budgetFetcher: budgetFetcher,
            alertStore: alertStore,
            notificationService: notifications,
            userDefaults: defaults
        )

        let preferencesUseCase = ApplyNotificationPreferencesUseCase(
            notificationService: notifications,
            refreshAllSchedules: {
                try? await budgetUseCase.execute()
            },
            userDefaults: defaults
        )

        await preferencesUseCase.applySubToggleChange()

        #expect(notifications.scheduledRequests.isEmpty)
    }
}
