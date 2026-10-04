import Foundation
import VittoraCore

/// Reminds the user a tracked investment is about to mature (M2.4.5).
///
/// Reconciles rather than appends: every run cancels the reminder for any record that no
/// longer qualifies — reminder switched off, maturity date cleared, notifications disabled,
/// date already passed — so editing a record cannot leave a stale notification behind.
struct ScheduleInvestmentMaturityRemindersUseCase: Sendable {
    /// Far enough ahead to act on. An ELSS unit can be redeemed the day the lock-in ends,
    /// but a PPF maturity usually needs paperwork started before it arrives.
    nonisolated static let leadDays = 14

    let investmentRepository: any InvestmentRepository
    let notificationService: any NotificationServiceProtocol
    let calendar: Calendar
    let nowProvider: @Sendable () -> Date
    nonisolated(unsafe) let userDefaults: UserDefaults

    nonisolated init(
        investmentRepository: any InvestmentRepository,
        notificationService: any NotificationServiceProtocol,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = { Date.now },
        userDefaults: UserDefaults = .standard
    ) {
        self.investmentRepository = investmentRepository
        self.notificationService = notificationService
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.userDefaults = userDefaults
    }

    func execute() async throws {
        let now = nowProvider()
        let investments = try await investmentRepository.fetchAll()

        for investment in investments {
            let identifier = Self.notificationIdentifier(for: investment.id)
            guard isEnabled,
                  investment.remindsOnMaturity,
                  let maturityDate = investment.maturityDate,
                  let fireDate = Self.fireDate(
                    maturityDate: maturityDate,
                    calendar: calendar,
                    from: now
                  )
            else {
                await notificationService.cancel(identifiers: [identifier])
                continue
            }

            try await notificationService.schedule(
                ScheduledNotificationRequest(
                    identifier: identifier,
                    title: String(localized: "Investment Maturing Soon"),
                    body: String(localized: "\(investment.name) matures in \(Self.leadDays) days."),
                    fireDate: fireDate,
                    category: .investmentMaturity,
                    deepLink: VittoraNotificationDeepLink(
                        destination: .investments,
                        entityID: investment.id
                    )
                )
            )
        }
    }

    /// Nil when the reminder would fire in the past — a maturity inside the lead window, or
    /// one that has already happened, is not worth a notification the user cannot act on.
    nonisolated static func fireDate(
        maturityDate: Date,
        calendar: Calendar,
        from now: Date
    ) -> Date? {
        guard let candidate = calendar.date(byAdding: .day, value: -leadDays, to: maturityDate) else {
            return nil
        }
        return candidate > now ? candidate : nil
    }

    nonisolated static func notificationIdentifier(for investmentID: UUID) -> String {
        "investment-maturity-\(investmentID.uuidString)"
    }

    private var isEnabled: Bool {
        guard userDefaults.object(forKey: AppUserDefaults.StandardKey.notificationsEnabled) == nil
                || userDefaults.bool(forKey: AppUserDefaults.StandardKey.notificationsEnabled)
        else { return false }
        // Absent means on, matching how the other reminder toggles read their key: a user
        // who has never opened notification settings still gets reminders.
        guard userDefaults.object(forKey: AppUserDefaults.StandardKey.notifyInvestmentMaturity) == nil
                || userDefaults.bool(forKey: AppUserDefaults.StandardKey.notifyInvestmentMaturity)
        else { return false }
        return true
    }
}
