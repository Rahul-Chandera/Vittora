import Foundation

struct ScheduleCreditCardDueRemindersUseCase: Sendable {
    private static let notificationsEnabledKey = AppUserDefaults.StandardKey.notificationsEnabled
    private static let notifyBillsDueKey = AppUserDefaults.StandardKey.notifyBillsDue

    let accountRepository: any AccountRepository
    let notificationService: any NotificationServiceProtocol
    let calendar: Calendar
    let nowProvider: @Sendable () -> Date
    nonisolated(unsafe) let userDefaults: UserDefaults

    nonisolated init(
        accountRepository: any AccountRepository,
        notificationService: any NotificationServiceProtocol,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = { Date.now },
        userDefaults: UserDefaults = .standard
    ) {
        self.accountRepository = accountRepository
        self.notificationService = notificationService
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.userDefaults = userDefaults
    }

    func execute() async throws {
        let accounts = try await accountRepository.fetchActive()
        let creditCards = accounts.filter { $0.type == .creditCard }

        for account in creditCards {
            let identifier = Self.notificationIdentifier(for: account.id)
            guard isBillRemindersEnabled,
                  let dueDay = account.dueDayOfMonth,
                  CreditCardDueDateCalculator.isValidDayOfMonth(dueDay),
                  let fireDate = CreditCardDueDateCalculator.nextReminderDate(
                    dayOfMonth: dueDay,
                    calendar: calendar,
                    from: nowProvider()
                  )
            else {
                await notificationService.cancel(identifiers: [identifier])
                continue
            }

            try await notificationService.schedule(
                ScheduledNotificationRequest(
                    identifier: identifier,
                    title: String(localized: "Payment Due Soon"),
                    body: String(
                        localized: "Your \(account.name) payment is due in \(CreditCardDueDateCalculator.defaultLeadDays) days."
                    ),
                    fireDate: fireDate,
                    category: .billDue,
                    deepLink: VittoraNotificationDeepLink(
                        destination: .accountDetail,
                        entityID: account.id
                    )
                )
            )
        }
    }

    static func notificationIdentifier(for accountID: UUID) -> String {
        "credit-card-due-\(accountID.uuidString)"
    }

    private var isBillRemindersEnabled: Bool {
        userDefaults.bool(forKey: Self.notificationsEnabledKey)
            && (userDefaults.object(forKey: Self.notifyBillsDueKey) as? Bool ?? true)
    }
}
