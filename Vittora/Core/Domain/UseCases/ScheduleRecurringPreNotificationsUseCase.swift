import Foundation
import VittoraCore

struct ScheduleRecurringPreNotificationsUseCase: Sendable {
    private static let notificationsEnabledKey = AppUserDefaults.StandardKey.notificationsEnabled
    private static let notifyRecurringKey = AppUserDefaults.StandardKey.notifyRecurring
    static let leadDays = 1

    let ruleRepository: any RecurringRuleRepository
    let payeeRepository: any PayeeRepository
    let notificationService: any NotificationServiceProtocol
    let calendar: Calendar
    let nowProvider: @Sendable () -> Date
    nonisolated(unsafe) let userDefaults: UserDefaults

    nonisolated init(
        ruleRepository: any RecurringRuleRepository,
        payeeRepository: any PayeeRepository,
        notificationService: any NotificationServiceProtocol,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = { Date.now },
        userDefaults: UserDefaults = .standard
    ) {
        self.ruleRepository = ruleRepository
        self.payeeRepository = payeeRepository
        self.notificationService = notificationService
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.userDefaults = userDefaults
    }

    func execute() async throws {
        let now = nowProvider()
        let rules = try await ruleRepository.fetchActive()

        for rule in rules {
            let identifier = Self.notificationIdentifier(for: rule.id)
            guard isRecurringRemindersEnabled,
                  rule.templateAccountID != nil,
                  rule.nextDate > now,
                  isWithinEndDate(rule.nextDate, endDate: rule.endDate),
                  let fireDate = PaymentReminderDateCalculator.preNotificationFireDate(
                    occurrence: rule.nextDate,
                    leadDays: Self.leadDays,
                    calendar: calendar,
                    from: now
                  )
            else {
                await notificationService.cancel(identifiers: [identifier])
                continue
            }

            let label = await reminderLabel(for: rule)
            try await notificationService.schedule(
                ScheduledNotificationRequest(
                    identifier: identifier,
                    title: String(localized: "Upcoming Recurring Expense"),
                    body: String(
                        localized: "\(label) is scheduled for tomorrow."
                    ),
                    fireDate: fireDate,
                    category: .recurring,
                    deepLink: VittoraNotificationDeepLink(destination: .recurring)
                )
            )
        }
    }

    static func notificationIdentifier(for ruleID: UUID) -> String {
        "recurring-pre-\(ruleID.uuidString)"
    }

    private func reminderLabel(for rule: RecurringRuleEntity) async -> String {
        if let note = rule.templateNote, !note.isEmpty {
            return note
        }
        if let payeeID = rule.templatePayeeID,
           let payee = try? await payeeRepository.fetchByID(payeeID) {
            return payee.name
        }
        return String(localized: "A recurring expense")
    }

    private func isWithinEndDate(_ occurrence: Date, endDate: Date?) -> Bool {
        guard let endDate else { return true }
        return occurrence <= endDate
    }

    private var isRecurringRemindersEnabled: Bool {
        userDefaults.bool(forKey: Self.notificationsEnabledKey)
            && (userDefaults.object(forKey: Self.notifyRecurringKey) as? Bool ?? true)
    }
}
