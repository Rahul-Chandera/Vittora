import Foundation
import UserNotifications
import Testing
import VittoraCore
@testable import Vittora

@Suite("NotificationService Tests", .serialized)
@MainActor
struct NotificationServiceTests {
    private func makeService() -> (NotificationService, MockUserNotificationCenter) {
        let center = MockUserNotificationCenter()
        let service = NotificationService(center: center)
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
}
