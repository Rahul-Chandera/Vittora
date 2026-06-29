import Foundation
import VittoraCore
@testable import Vittora

@MainActor
final class MockNotificationService: NotificationServiceProtocol {
    private(set) var registerCategoriesCallCount = 0
    private(set) var requestAuthorizationCallCount = 0
    private(set) var scheduledRequests: [ScheduledNotificationRequest] = []
    private(set) var cancelledIdentifiers: [[String]] = []
    private(set) var cancelAllPendingCallCount = 0

    var authorizationStatusValue: NotificationAuthorizationStatus = .notDetermined
    var requestAuthorizationResult = true

    func registerCategories() async {
        registerCategoriesCallCount += 1
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        authorizationStatusValue
    }

    func requestAuthorization() async throws -> Bool {
        requestAuthorizationCallCount += 1
        return requestAuthorizationResult
    }

    func schedule(_ request: ScheduledNotificationRequest) async throws {
        scheduledRequests.append(request)
    }

    func cancel(identifiers: [String]) async {
        cancelledIdentifiers.append(identifiers)
    }

    func cancelAllPending() async {
        cancelAllPendingCallCount += 1
    }

    func pendingRequests() async -> [ScheduledNotificationRequest] {
        scheduledRequests
    }

    func setDeepLinkHandler(_ handler: (@MainActor (VittoraNotificationDeepLink) -> Void)?) {}
}

struct StubBudgetFetcher: ActiveBudgetFetching {
    var budgets: [BudgetEntity]

    func fetchActiveBudgetsWithSpent() async throws -> [BudgetEntity] {
        budgets
    }
}

final class InMemoryBudgetThresholdAlertStore: BudgetThresholdAlertStoring, @unchecked Sendable {
    private var storage: [String: Set<BudgetThresholdLevel>] = [:]
    private let lock = NSLock()

    func firedLevels(forPeriodKey key: String) -> Set<BudgetThresholdLevel> {
        lock.lock()
        defer { lock.unlock() }
        return storage[key, default: []]
    }

    func markFired(_ level: BudgetThresholdLevel, forPeriodKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        var levels = storage[key, default: []]
        levels.insert(level)
        storage[key] = levels
    }
}
