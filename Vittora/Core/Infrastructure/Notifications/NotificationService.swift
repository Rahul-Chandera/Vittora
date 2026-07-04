import Foundation
import UserNotifications
import VittoraCore

/// Test seam over `UNUserNotificationCenter` (FUNCTIONAL-1 / C1).
@MainActor
protocol UserNotificationCenterProtocol: AnyObject {
    var delegate: UNUserNotificationCenterDelegate? { get set }
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
}

extension UNUserNotificationCenter: UserNotificationCenterProtocol {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
}

protocol NotificationServiceProtocol: Sendable {
    func registerCategories() async
    func authorizationStatus() async -> NotificationAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func schedule(_ request: ScheduledNotificationRequest) async throws
    func cancel(identifiers: [String]) async
    func cancelAllPending() async
    func pendingRequests() async -> [ScheduledNotificationRequest]
    func setDeepLinkHandler(_ handler: (@MainActor (VittoraNotificationDeepLink) -> Void)?)
}

@MainActor
final class NotificationService: NotificationServiceProtocol, Sendable {
    private let center: any UserNotificationCenterProtocol
    private let delegateProxy: NotificationCenterDelegateProxy
    private var deepLinkHandler: (@MainActor (VittoraNotificationDeepLink) -> Void)?

    init(center: any UserNotificationCenterProtocol) {
        self.center = center
        self.delegateProxy = NotificationCenterDelegateProxy()
        center.delegate = delegateProxy
        delegateProxy.onDeepLink = { [weak self] deepLink in
            self?.deepLinkHandler?(deepLink)
        }
    }

    convenience init() {
        self.init(center: UNUserNotificationCenter.current())
    }

    func setDeepLinkHandler(_ handler: (@MainActor (VittoraNotificationDeepLink) -> Void)?) {
        deepLinkHandler = handler
    }

    func registerCategories() async {
        let categories = Set(
            VittoraNotificationCategory.allCases.map { kind in
                UNNotificationCategory(
                    identifier: kind.rawValue,
                    actions: [],
                    intentIdentifiers: [],
                    options: []
                )
            }
        )
        center.setNotificationCategories(categories)
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        NotificationAuthorizationStatus(authorizationStatus: await center.authorizationStatus())
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func schedule(_ request: ScheduledNotificationRequest) async throws {
        try await center.add(request.makeUNRequest())
    }

    func cancel(identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func cancelAllPending() async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier))
    }

    func pendingRequests() async -> [ScheduledNotificationRequest] {
        await center.pendingNotificationRequests().compactMap(ScheduledNotificationRequest.init)
    }
}

// MARK: - Delegate proxy

@MainActor
final class NotificationCenterDelegateProxy: NSObject, UNUserNotificationCenterDelegate {
    var onDeepLink: (@MainActor (VittoraNotificationDeepLink) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let deepLink = VittoraNotificationDeepLink(
            userInfo: response.notification.request.content.userInfo
        ) else {
            return
        }
        onDeepLink?(deepLink)
    }

    /// Test hook — forwards a synthetic tap without the system center.
    func simulateNotificationResponse(userInfo: [AnyHashable: Any]) {
        guard let deepLink = VittoraNotificationDeepLink(userInfo: userInfo) else { return }
        onDeepLink?(deepLink)
    }
}
