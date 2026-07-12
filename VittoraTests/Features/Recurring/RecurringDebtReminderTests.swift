import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("PaymentReminderDateCalculator Tests")
struct PaymentReminderDateCalculatorTests {
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
        components.timeZone = calendar.timeZone
        return calendar.date(from: components) ?? .now
    }

    @Test("preNotificationFireDate schedules lead days before occurrence")
    func schedulesLeadDaysBeforeOccurrence() throws {
        let reference = date(year: 2026, month: 6, day: 1)
        let occurrence = date(year: 2026, month: 6, day: 15)
        let fire = PaymentReminderDateCalculator.preNotificationFireDate(
            occurrence: occurrence,
            leadDays: 1,
            calendar: calendar,
            from: reference
        )
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: try #require(fire))
        #expect(components.year == 2026)
        #expect(components.month == 6)
        #expect(components.day == 14)
        #expect(components.hour == PaymentReminderDateCalculator.defaultReminderHour)
    }
}

@MainActor
@Suite("ScheduleRecurringPreNotificationsUseCase Tests")
struct ScheduleRecurringPreNotificationsUseCaseTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func makeEnabledDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "ScheduleRecurringPreNotificationsTests.\(UUID().uuidString)") ?? .standard
        defaults.set(true, forKey: "vittora.notificationsEnabled")
        defaults.set(true, forKey: "vittora.notifyRecurring")
        return defaults
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.timeZone = calendar.timeZone
        return calendar.date(from: components) ?? .now
    }

    @Test("schedules pre-notification for active future rule")
    func schedulesPreNotification() async throws {
        let ruleRepo = MockRecurringRuleRepository()
        let payeeRepo = MockPayeeRepository()
        let notifications = MockNotificationService()
        let defaults = makeEnabledDefaults()
        let reference = date(year: 2026, month: 6, day: 1)
        let nextDate = date(year: 2026, month: 6, day: 15)
        let rule = RecurringRuleEntity(
            frequency: .monthly,
            nextDate: nextDate,
            templateAmount: 20,
            templateNote: "Streaming",
            templateAccountID: UUID()
        )
        await ruleRepo.seed(rule)

        let useCase = ScheduleRecurringPreNotificationsUseCase(
            ruleRepository: ruleRepo,
            payeeRepository: payeeRepo,
            notificationService: notifications,
            calendar: calendar,
            nowProvider: { reference },
            userDefaults: defaults
        )

        try await useCase.execute()

        #expect(notifications.scheduledRequests.count == 1)
        #expect(notifications.scheduledRequests[0].category == .recurring)
        #expect(notifications.scheduledRequests[0].body.contains("Streaming"))
    }

    @Test("cancels when recurring reminders are disabled")
    func cancelsWhenDisabled() async throws {
        let ruleRepo = MockRecurringRuleRepository()
        let payeeRepo = MockPayeeRepository()
        let notifications = MockNotificationService()
        let defaults = UserDefaults(suiteName: "ScheduleRecurringPreNotificationsTests.disabled.\(UUID())") ?? .standard
        defaults.set(false, forKey: "vittora.notificationsEnabled")
        let rule = RecurringRuleEntity(
            frequency: .monthly,
            nextDate: date(year: 2026, month: 6, day: 15),
            templateAmount: 20,
            templateAccountID: UUID()
        )
        await ruleRepo.seed(rule)

        let useCase = ScheduleRecurringPreNotificationsUseCase(
            ruleRepository: ruleRepo,
            payeeRepository: payeeRepo,
            notificationService: notifications,
            userDefaults: defaults
        )

        try await useCase.execute()

        #expect(notifications.scheduledRequests.isEmpty)
        #expect(notifications.cancelledIdentifiers.count == 1)
    }
}

@MainActor
@Suite("ScheduleSelfDebtDueRemindersUseCase Tests")
struct ScheduleSelfDebtDueRemindersUseCaseTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private func makeEnabledDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "ScheduleSelfDebtDueRemindersTests.\(UUID().uuidString)") ?? .standard
        defaults.set(true, forKey: "vittora.notificationsEnabled")
        defaults.set(true, forKey: "vittora.notifyBillsDue")
        return defaults
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.timeZone = calendar.timeZone
        return calendar.date(from: components) ?? .now
    }

    @Test("schedules reminder for borrowed debt with due date")
    func schedulesBorrowedDebtReminder() async throws {
        let debtID = UUID()
        let payeeID = UUID()
        let debtRepo = MockDebtRepository()
        let payeeRepo = MockPayeeRepository()
        await payeeRepo.seed(PayeeEntity(id: payeeID, name: "Alex"))
        await debtRepo.seed(
            DebtEntry(
                id: debtID,
                payeeID: payeeID,
                amount: 500,
                direction: .borrowed,
                dueDate: date(year: 2026, month: 6, day: 20)
            )
        )
        let notifications = MockNotificationService()
        let defaults = makeEnabledDefaults()
        let reference = date(year: 2026, month: 6, day: 1)

        let useCase = ScheduleSelfDebtDueRemindersUseCase(
            debtRepository: debtRepo,
            payeeRepository: payeeRepo,
            notificationService: notifications,
            calendar: calendar,
            nowProvider: { reference },
            userDefaults: defaults
        )

        try await useCase.execute()

        #expect(notifications.scheduledRequests.count == 1)
        #expect(notifications.scheduledRequests[0].category == .debt)
        #expect(notifications.scheduledRequests[0].deepLink.entityID == debtID)
        #expect(notifications.scheduledRequests[0].body.contains("Alex"))
    }

    @Test("skips lent debts and debts without due dates")
    func skipsNonSelfDebts() async throws {
        let debtRepo = MockDebtRepository()
        let payeeRepo = MockPayeeRepository()
        await debtRepo.seed(
            DebtEntry(
                payeeID: UUID(),
                amount: 100,
                direction: .lent,
                dueDate: date(year: 2026, month: 6, day: 20)
            )
        )
        await debtRepo.seed(
            DebtEntry(
                payeeID: UUID(),
                amount: 100,
                direction: .borrowed
            )
        )
        let notifications = MockNotificationService()
        let defaults = makeEnabledDefaults()

        let useCase = ScheduleSelfDebtDueRemindersUseCase(
            debtRepository: debtRepo,
            payeeRepository: payeeRepo,
            notificationService: notifications,
            userDefaults: defaults
        )

        try await useCase.execute()

        #expect(notifications.scheduledRequests.isEmpty)
    }
}

@Suite("DebtContactReminderDraft Tests")
struct DebtContactReminderDraftTests {
    @Test("builds localized reminder message with due date")
    func buildsMessageWithDueDate() {
        let message = DebtContactReminderDraft.message(
            payeeName: "Sam",
            remainingAmount: Decimal(250),
            dueDate: Date(timeIntervalSince1970: 1_767_225_600),
            currencyCode: "USD"
        )
        #expect(message.contains("Sam"))
        #expect(message.contains("250"))
    }
}
