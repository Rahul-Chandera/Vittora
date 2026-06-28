import Foundation

struct ScheduleSelfDebtDueRemindersUseCase: Sendable {
    private static let notificationsEnabledKey = AppUserDefaults.StandardKey.notificationsEnabled
    private static let notifyBillsDueKey = AppUserDefaults.StandardKey.notifyBillsDue
    static let leadDays = 3

    let debtRepository: any DebtRepository
    let payeeRepository: any PayeeRepository
    let notificationService: any NotificationServiceProtocol
    let calendar: Calendar
    let nowProvider: @Sendable () -> Date
    nonisolated(unsafe) let userDefaults: UserDefaults

    nonisolated init(
        debtRepository: any DebtRepository,
        payeeRepository: any PayeeRepository,
        notificationService: any NotificationServiceProtocol,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = { Date.now },
        userDefaults: UserDefaults = .standard
    ) {
        self.debtRepository = debtRepository
        self.payeeRepository = payeeRepository
        self.notificationService = notificationService
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.userDefaults = userDefaults
    }

    func execute() async throws {
        let now = nowProvider()
        let debts = try await debtRepository.fetchOutstanding()

        for debt in debts where debt.direction == .borrowed {
            let identifier = Self.notificationIdentifier(for: debt.id)
            guard isSelfDebtRemindersEnabled,
                  let dueDate = debt.dueDate,
                  let fireDate = PaymentReminderDateCalculator.preNotificationFireDate(
                    occurrence: dueDate,
                    leadDays: Self.leadDays,
                    calendar: calendar,
                    from: now
                  )
            else {
                await notificationService.cancel(identifiers: [identifier])
                continue
            }

            let payeeName = await payeeName(for: debt.payeeID)
            try await notificationService.schedule(
                ScheduledNotificationRequest(
                    identifier: identifier,
                    title: String(localized: "Debt Payment Due Soon"),
                    body: String(
                        localized: "You owe \(payeeName) \(Self.leadDays) days before the due date."
                    ),
                    fireDate: fireDate,
                    category: .debt,
                    deepLink: VittoraNotificationDeepLink(
                        destination: .debt,
                        entityID: debt.id
                    )
                )
            )
        }
    }

    static func notificationIdentifier(for debtID: UUID) -> String {
        "self-debt-due-\(debtID.uuidString)"
    }

    private func payeeName(for payeeID: UUID) async -> String {
        if let payee = try? await payeeRepository.fetchByID(payeeID) {
            return payee.name
        }
        return String(localized: "someone")
    }

    private var isSelfDebtRemindersEnabled: Bool {
        userDefaults.bool(forKey: Self.notificationsEnabledKey)
            && (userDefaults.object(forKey: Self.notifyBillsDueKey) as? Bool ?? true)
    }
}
