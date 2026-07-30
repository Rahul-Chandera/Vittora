import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("CreditCardDueDateCalculator Tests")
struct CreditCardDueDateCalculatorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = 0
        components.second = 0
        components.timeZone = calendar.timeZone
        return calendar.date(from: components) ?? .now
    }

    @Test("dueDate clamps day 31 to shorter months")
    func dueDateClampsToMonthLength() throws {
        let febDue = CreditCardDueDateCalculator.dueDate(
            dayOfMonth: 31,
            monthAnchor: date(year: 2026, month: 2, day: 10),
            calendar: calendar
        )
        let components = calendar.dateComponents([.day], from: try #require(febDue))
        #expect(components.day == 28)
    }

    @Test("nextReminderDate uses this month when reminder is still ahead")
    func nextReminderUsesCurrentMonth() throws {
        let reference = date(year: 2026, month: 6, day: 5)
        let reminder = CreditCardDueDateCalculator.nextReminderDate(
            dayOfMonth: 15,
            calendar: calendar,
            from: reference
        )
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: try #require(reminder))
        #expect(components.year == 2026)
        #expect(components.month == 6)
        #expect(components.day == 12)
        #expect(components.hour == CreditCardDueDateCalculator.defaultReminderHour)
    }

    @Test("nextReminderDate rolls to next month when current reminder passed")
    func nextReminderRollsForward() throws {
        let reference = date(year: 2026, month: 6, day: 10)
        let reminder = CreditCardDueDateCalculator.nextReminderDate(
            dayOfMonth: 5,
            calendar: calendar,
            from: reference
        )
        let components = calendar.dateComponents([.year, .month, .day], from: try #require(reminder))
        #expect(components.year == 2026)
        #expect(components.month == 7)
        #expect(components.day == 2)
    }
}

@MainActor
@Suite("ScheduleCreditCardDueRemindersUseCase Tests")
struct ScheduleCreditCardDueRemindersUseCaseTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour
            )
        ) ?? .now
    }

    private func makeEnabledDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "ScheduleCreditCardDueRemindersTests.\(UUID().uuidString)") ?? .standard
        defaults.set(true, forKey: "vittora.notificationsEnabled")
        defaults.set(true, forKey: "vittora.notifyBillsDue")
        return defaults
    }

    @Test("default settings preserve the existing three-day 09:00 bill reminder")
    func schedulesReminder() async throws {
        let accountID = UUID()
        let repo = MockAccountRepository()
        await repo.seed(
            AccountEntity(
                id: accountID,
                name: "Visa",
                type: .creditCard,
                dueDayOfMonth: 20
            )
        )
        let notifications = MockNotificationService()
        let defaults = makeEnabledDefaults()
        var calendar = calendar
        let reference = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 1,
            hour: 12
        )) ?? .now

        let useCase = ScheduleCreditCardDueRemindersUseCase(
            accountRepository: repo,
            notificationService: notifications,
            calendar: calendar,
            nowProvider: { reference },
            userDefaults: defaults
        )

        try await useCase.execute()

        #expect(notifications.scheduledRequests.count == 1)
        #expect(notifications.scheduledRequests[0].category == .billDue)
        #expect(notifications.scheduledRequests[0].deepLink.destination == .accountDetail)
        #expect(notifications.scheduledRequests[0].deepLink.entityID == accountID)
        let fireComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: notifications.scheduledRequests[0].fireDate
        )
        #expect(fireComponents.year == 2026)
        #expect(fireComponents.month == 6)
        #expect(fireComponents.day == 17)
        #expect(fireComponents.hour == 9)
        #expect(fireComponents.minute == 0)
    }

    @Test("cancels reminder when due day is not set")
    func cancelsWhenDueDayMissing() async throws {
        let accountID = UUID()
        let repo = MockAccountRepository()
        await repo.seed(AccountEntity(id: accountID, name: "Visa", type: .creditCard))
        let notifications = MockNotificationService()
        let defaults = makeEnabledDefaults()

        let useCase = ScheduleCreditCardDueRemindersUseCase(
            accountRepository: repo,
            notificationService: notifications,
            userDefaults: defaults
        )

        try await useCase.execute()

        #expect(notifications.scheduledRequests.isEmpty)
        #expect(notifications.cancelledIdentifiers.count == 1)
        #expect(
            notifications.cancelledIdentifiers[0] == [
                ScheduleCreditCardDueRemindersUseCase.notificationIdentifier(for: accountID),
            ]
        )
    }

    @Test("configured bill lead time is wired into the scheduled request")
    func configuredLeadTime() async throws {
        let repo = MockAccountRepository()
        await repo.seed(AccountEntity(name: "Visa", type: .creditCard, dueDayOfMonth: 20))
        let notifications = MockNotificationService()
        let defaults = makeEnabledDefaults()
        defaults.set(1, forKey: AppUserDefaults.StandardKey.billReminderLeadDays)
        let reference = date(year: 2026, month: 6, day: 1)
        let useCase = ScheduleCreditCardDueRemindersUseCase(
            accountRepository: repo,
            notificationService: notifications,
            calendar: calendar,
            nowProvider: { reference },
            userDefaults: defaults
        )

        try await useCase.execute()

        let request = try #require(notifications.scheduledRequests.first)
        #expect(calendar.component(.day, from: request.fireDate) == 19)
        #expect(request.body.contains("1"))
    }

    @Test("skips scheduling when bill reminders are disabled")
    func skipsWhenDisabled() async throws {
        let repo = MockAccountRepository()
        await repo.seed(AccountEntity(name: "Visa", type: .creditCard, dueDayOfMonth: 10))
        let notifications = MockNotificationService()
        let defaults = UserDefaults(suiteName: "ScheduleCreditCardDueRemindersTests.disabled.\(UUID())") ?? .standard
        defaults.set(false, forKey: "vittora.notificationsEnabled")

        let useCase = ScheduleCreditCardDueRemindersUseCase(
            accountRepository: repo,
            notificationService: notifications,
            userDefaults: defaults
        )

        try await useCase.execute()

        #expect(notifications.scheduledRequests.isEmpty)
    }
}
