import Foundation
import UserNotifications
import Testing
import VittoraCore
@testable import Vittora

@Suite("NotificationService Tests", .serialized)
@MainActor
struct NotificationServiceTests {
    private func makeService(
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) -> (NotificationService, MockUserNotificationCenter) {
        let center = MockUserNotificationCenter()
        let service = NotificationService(
            center: center,
            userDefaults: userDefaults,
            calendarProvider: { calendar }
        )
        return (service, center)
    }

    @Test("registerCategories registers all Vittora categories")
    func registerCategories() async {
        let (service, center) = makeService()
        await service.registerCategories()
        #expect(center.registeredCategories.count == VittoraNotificationCategory.allCases.count)
        for kind in VittoraNotificationCategory.allCases {
            #expect(center.registeredCategories.map(\.identifier).contains(kind.rawValue))
        }
    }

    @Test("requestAuthorization returns granted result")
    func requestAuthorizationGranted() async throws {
        let (service, center) = makeService()
        center.requestAuthorizationResult = true
        let granted = try await service.requestAuthorization()
        #expect(granted == true)
        #expect(await service.authorizationStatus() == .authorized)
    }

    @Test("schedule adds notification request with deep link userInfo")
    func scheduleAddsRequest() async throws {
        let (service, center) = makeService()
        let budgetID = UUID()
        let request = ScheduledNotificationRequest(
            identifier: "budget-threshold-50",
            title: "Budget alert",
            body: "You reached 50% of Groceries",
            fireDate: Date.now.addingTimeInterval(3600),
            category: .budgetAlert,
            deepLink: VittoraNotificationDeepLink(destination: .budgetDetail, entityID: budgetID)
        )
        try await service.schedule(request)
        let pending = await service.pendingRequests()
        #expect(pending.count == 1)
        #expect(pending[0].identifier == request.identifier)
        #expect(pending[0].category == .budgetAlert)
        #expect(pending[0].deepLink.destination == .budgetDetail)
        #expect(pending[0].deepLink.entityID == budgetID)
    }

    @Test("cancel removes pending identifiers")
    func cancelRemovesPending() async throws {
        let (service, center) = makeService()
        let request = ScheduledNotificationRequest(
            identifier: "bill-due-1",
            title: "Bill due",
            body: "Credit card payment due tomorrow",
            fireDate: Date.now.addingTimeInterval(60),
            category: .billDue,
            deepLink: VittoraNotificationDeepLink(destination: .transactions)
        )
        try await service.schedule(request)
        await service.cancel(identifiers: ["bill-due-1"])
        #expect(center.removedIdentifiers == [["bill-due-1"]])
        #expect(await service.pendingRequests().isEmpty)
    }

    @Test("deep link handler fires on simulated notification response")
    func deepLinkHandlerFires() {
        let proxy = NotificationCenterDelegateProxy()
        var received: VittoraNotificationDeepLink?
        proxy.onDeepLink = { deepLink in
            received = deepLink
        }
        proxy.simulateNotificationResponse(userInfo: [
            VittoraNotificationDeepLink.destinationKey: "debt",
        ])
        #expect(received?.destination == .debt)
    }

    @Test("deep link parses entity ID from userInfo")
    func deepLinkParsesEntityID() {
        let id = UUID()
        let deepLink = VittoraNotificationDeepLink(userInfo: [
            VittoraNotificationDeepLink.destinationKey: "budgetDetail",
            VittoraNotificationDeepLink.entityIDKey: id.uuidString,
        ])
        #expect(deepLink?.destination == .budgetDetail)
        #expect(deepLink?.entityID == id)
    }

    @Test("default scheduling preserves existing 09:00 delivery")
    func defaultSchedulingRegression() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let defaults = UserDefaults(suiteName: "NotificationServiceTests.defaults.\(UUID())") ?? .standard
        let (service, _) = makeService(userDefaults: defaults, calendar: calendar)
        let futureDay = calendar.date(byAdding: .day, value: 30, to: .now) ?? .now
        let fireDate = calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: futureDay
        ) ?? futureDay

        try await service.schedule(
            ScheduledNotificationRequest(
                identifier: "default-bill",
                title: "Bill",
                body: "Due soon",
                fireDate: fireDate,
                category: .billDue,
                deepLink: VittoraNotificationDeepLink(destination: .transactions)
            )
        )

        let pending = try #require(await service.pendingRequests().first)
        #expect(abs(pending.fireDate.timeIntervalSince(fireDate)) < 2)
    }

    @Test("delivery time uses injected local timezone")
    func deliveryTimeUsesInjectedTimezone() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let defaults = UserDefaults(suiteName: "NotificationServiceTests.timezone.\(UUID())") ?? .standard
        defaults.set(9 * 60, forKey: AppUserDefaults.StandardKey.notificationDeliveryTime)
        let (service, _) = makeService(userDefaults: defaults, calendar: calendar)
        let futureDay = calendar.date(byAdding: .day, value: 30, to: .now) ?? .now
        let original = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: futureDay) ?? futureDay

        try await service.schedule(
            ScheduledNotificationRequest(
                identifier: "timezone-recurring",
                title: "Recurring",
                body: "Upcoming",
                fireDate: original,
                category: .recurring,
                deepLink: VittoraNotificationDeepLink(destination: .recurring)
            )
        )

        let pending = try #require(await service.pendingRequests().first)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: pending.fireDate)
        let expectedDay = calendar.dateComponents([.year, .month, .day], from: original)
        #expect(components.year == expectedDay.year)
        #expect(components.month == expectedDay.month)
        #expect(components.day == expectedDay.day)
        #expect(components.hour == 9)
        #expect(components.minute == 0)
    }

    @Test("repeated quiet-hours deferral leaves exactly one pending request")
    func deferredRequestDoesNotStack() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let defaults = UserDefaults(suiteName: "NotificationServiceTests.duplicate.\(UUID())") ?? .standard
        defaults.set(true, forKey: AppUserDefaults.StandardKey.notificationQuietHoursEnabled)
        defaults.set(22 * 60, forKey: AppUserDefaults.StandardKey.notificationQuietHoursStart)
        defaults.set(7 * 60, forKey: AppUserDefaults.StandardKey.notificationQuietHoursEnd)
        let (service, center) = makeService(userDefaults: defaults, calendar: calendar)
        let futureDay = calendar.date(byAdding: .day, value: 30, to: .now) ?? .now
        let fireDate = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: futureDay) ?? futureDay
        let request = ScheduledNotificationRequest(
            identifier: "deferred-once",
            title: "Budget",
            body: "Threshold reached",
            fireDate: fireDate,
            category: .budgetAlert,
            deepLink: VittoraNotificationDeepLink(destination: .budgets)
        )

        try await service.schedule(request)
        try await service.schedule(request)

        #expect(center.addedRequests.count == 1)
        let pending = try #require(await service.pendingRequests().first)
        let expected = calendar.date(byAdding: .day, value: 1, to: fireDate)
            .flatMap { calendar.date(bySettingHour: 7, minute: 0, second: 0, of: $0) }
        #expect(abs(pending.fireDate.timeIntervalSince(try #require(expected))) < 2)
    }
}
