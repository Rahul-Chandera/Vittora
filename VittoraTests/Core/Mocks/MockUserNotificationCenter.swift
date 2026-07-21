import Foundation
import UserNotifications
import VittoraCore
@testable import Vittora

@MainActor
final class MockUserNotificationCenter: UserNotificationCenterProtocol {
    weak var delegate: UNUserNotificationCenterDelegate?

    var authorizationStatusValue: UNAuthorizationStatus = .notDetermined
    var requestAuthorizationResult = true
    var shouldThrowOnAdd = false
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [[String]] = []
    private(set) var registeredCategories: Set<UNNotificationCategory> = []

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatusValue
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        if requestAuthorizationResult {
            authorizationStatusValue = .authorized
        } else {
            authorizationStatusValue = .denied
        }
        return requestAuthorizationResult
    }

    func add(_ request: UNNotificationRequest) async throws {
        if shouldThrowOnAdd {
            throw NSError(domain: "MockUserNotificationCenter", code: 1)
        }
        addedRequests.removeAll { $0.identifier == request.identifier }
        addedRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(identifiers)
        addedRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        addedRequests
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        registeredCategories = categories
    }

    func reset() {
        authorizationStatusValue = .notDetermined
        requestAuthorizationResult = true
        shouldThrowOnAdd = false
        addedRequests = []
        removedIdentifiers = []
        registeredCategories = []
    }
}
