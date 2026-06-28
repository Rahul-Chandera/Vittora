import Foundation
import UserNotifications

/// Local notification categories registered with the system (FUNCTIONAL-1 / C1).
enum VittoraNotificationCategory: String, CaseIterable, Sendable {
    case budgetAlert = "vittora.budget"
    case billDue = "vittora.bill"
    case recurring = "vittora.recurring"
    case debt = "vittora.debt"
    case goal = "vittora.goal"

    var localizedTitle: String {
        switch self {
        case .budgetAlert:
            String(localized: "Budget Alerts")
        case .billDue:
            String(localized: "Bill Reminders")
        case .recurring:
            String(localized: "Recurring Transactions")
        case .debt:
            String(localized: "Debt Reminders")
        case .goal:
            String(localized: "Savings Goals")
        }
    }
}

/// Navigation target encoded in notification `userInfo` for tap handling.
struct VittoraNotificationDeepLink: Equatable, Sendable {
    enum Destination: String, Codable, Sendable {
        case budgets
        case budgetDetail
        case debt
        case transactions
        case savings
        case recurring
    }

    static let destinationKey = "vittora.destination"
    static let entityIDKey = "vittora.entityID"

    var destination: Destination
    var entityID: UUID?

    init(destination: Destination, entityID: UUID? = nil) {
        self.destination = destination
        self.entityID = entityID
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard let raw = userInfo[Self.destinationKey] as? String,
              let destination = Destination(rawValue: raw)
        else {
            return nil
        }
        self.destination = destination
        if let idString = userInfo[Self.entityIDKey] as? String {
            self.entityID = UUID(uuidString: idString)
        } else {
            self.entityID = nil
        }
    }

    func userInfoValues() -> [String: String] {
        var values = [Self.destinationKey: destination.rawValue]
        if let entityID {
            values[Self.entityIDKey] = entityID.uuidString
        }
        return values
    }
}

/// App-level authorization status (Sendable wrapper around UNAuthorizationStatus).
enum NotificationAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    init(authorizationStatus: UNAuthorizationStatus) {
        switch authorizationStatus {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized: self = .authorized
        case .provisional: self = .provisional
        case .ephemeral: self = .ephemeral
        @unknown default: self = .denied
        }
    }
}

/// Domain request for scheduling a local notification.
struct ScheduledNotificationRequest: Sendable, Equatable, Identifiable {
    let identifier: String
    let title: String
    let body: String
    let fireDate: Date
    let category: VittoraNotificationCategory
    let deepLink: VittoraNotificationDeepLink

    var id: String { identifier }
}

extension ScheduledNotificationRequest {
    func makeUNRequest() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category.rawValue
        for (key, value) in deepLink.userInfoValues() {
            content.userInfo[key] = value
        }

        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    init?(notificationRequest: UNNotificationRequest) {
        let content = notificationRequest.content
        guard let category = VittoraNotificationCategory(rawValue: content.categoryIdentifier),
              let deepLink = VittoraNotificationDeepLink(userInfo: content.userInfo)
        else {
            return nil
        }
        identifier = notificationRequest.identifier
        title = content.title
        body = content.body
        self.category = category
        self.deepLink = deepLink
        if let trigger = notificationRequest.trigger as? UNTimeIntervalNotificationTrigger {
            fireDate = Date.now.addingTimeInterval(trigger.timeInterval)
        } else if let trigger = notificationRequest.trigger as? UNCalendarNotificationTrigger,
                  let next = trigger.nextTriggerDate() {
            fireDate = next
        } else {
            fireDate = .now
        }
    }
}
