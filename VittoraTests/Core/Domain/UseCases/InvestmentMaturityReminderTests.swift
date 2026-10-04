import Foundation
import Testing
import VittoraCore
@testable import Vittora

@MainActor
final class MockInvestmentRepository: InvestmentRepository {
    var investments: [Investment] = []
    func fetchAll() async throws -> [Investment] { investments }
    func save(_ investment: Investment) async throws {
        investments.removeAll { $0.id == investment.id }
        investments.append(investment)
    }
    func delete(id: UUID) async throws { investments.removeAll { $0.id == id } }
}

/// M2.4.5. The reminder reconciles on every run rather than appending, so the cancellation
/// paths matter as much as the scheduling one — a record whose reminder is switched off
/// must not keep firing.
@MainActor
@Suite("Investment Maturity Reminder Tests")
struct InvestmentMaturityReminderTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))
            ?? Date(timeIntervalSince1970: 0)
    }

    private func makeUseCase(
        investments: [Investment],
        now: Date,
        defaults: UserDefaults
    ) -> (ScheduleInvestmentMaturityRemindersUseCase, MockNotificationService) {
        let repository = MockInvestmentRepository()
        repository.investments = investments
        let service = MockNotificationService()
        let useCase = ScheduleInvestmentMaturityRemindersUseCase(
            investmentRepository: repository,
            notificationService: service,
            calendar: calendar,
            nowProvider: { now },
            userDefaults: defaults
        )
        return (useCase, service)
    }

    private func freshDefaults() -> UserDefaults {
        let suite = UserDefaults(suiteName: "investment-reminder-\(UUID().uuidString)")
        return suite ?? .standard
    }

    private func investment(
        name: String = "ELSS",
        maturity: Date?,
        reminds: Bool = true
    ) -> Investment {
        Investment(
            name: name,
            amount: 50_000,
            sectionKey: "80C",
            maturityDate: maturity,
            remindsOnMaturity: reminds
        )
    }

    @Test("a future maturity schedules a reminder ahead of the date")
    func futureMaturitySchedules() async throws {
        let now = date(2026, 1, 1)
        let maturity = date(2026, 6, 1)
        let (useCase, service) = makeUseCase(
            investments: [investment(maturity: maturity)],
            now: now,
            defaults: freshDefaults()
        )

        try await useCase.execute()

        #expect(service.scheduledRequests.count == 1)
        let request = try #require(service.scheduledRequests.first)
        #expect(request.category == .investmentMaturity)
        let expected = calendar.date(
            byAdding: .day,
            value: -ScheduleInvestmentMaturityRemindersUseCase.leadDays,
            to: maturity
        )
        #expect(request.fireDate == expected)
    }

    /// A reminder the user cannot act on is worse than none: it fires about something that
    /// already happened.
    @Test("a maturity already in the past schedules nothing and cancels")
    func pastMaturityCancels() async throws {
        let (useCase, service) = makeUseCase(
            investments: [investment(maturity: date(2025, 1, 1))],
            now: date(2026, 1, 1),
            defaults: freshDefaults()
        )

        try await useCase.execute()

        #expect(service.scheduledRequests.isEmpty)
        #expect(service.cancelledIdentifiers.isEmpty == false)
    }

    @Test("a maturity inside the lead window schedules nothing")
    func maturityInsideLeadWindowSchedulesNothing() async throws {
        let (useCase, service) = makeUseCase(
            investments: [investment(maturity: date(2026, 1, 10))],
            now: date(2026, 1, 1),
            defaults: freshDefaults()
        )

        try await useCase.execute()
        #expect(service.scheduledRequests.isEmpty)
    }

    @Test("an age-linked record with no maturity date is skipped, not crashed on")
    func ageLinkedRecordIsSkipped() async throws {
        let (useCase, service) = makeUseCase(
            investments: [investment(name: "NPS Tier-I", maturity: nil)],
            now: date(2026, 1, 1),
            defaults: freshDefaults()
        )

        try await useCase.execute()
        #expect(service.scheduledRequests.isEmpty)
        #expect(service.cancelledIdentifiers.isEmpty == false)
    }

    @Test("switching the reminder off cancels instead of leaving it pending")
    func reminderOffCancels() async throws {
        let (useCase, service) = makeUseCase(
            investments: [investment(maturity: date(2026, 6, 1), reminds: false)],
            now: date(2026, 1, 1),
            defaults: freshDefaults()
        )

        try await useCase.execute()

        #expect(service.scheduledRequests.isEmpty)
        #expect(service.cancelledIdentifiers.flatMap { $0 }.count == 1)
    }

    @Test("the category toggle switches every maturity reminder off")
    func categoryToggleSuppressesAll() async throws {
        let defaults = freshDefaults()
        defaults.set(false, forKey: AppUserDefaults.StandardKey.notifyInvestmentMaturity)
        let (useCase, service) = makeUseCase(
            investments: [investment(maturity: date(2026, 6, 1))],
            now: date(2026, 1, 1),
            defaults: defaults
        )

        try await useCase.execute()
        #expect(service.scheduledRequests.isEmpty)
    }

    @Test("the identifier is stable, so rerunning replaces rather than duplicates")
    func identifierIsStable() {
        let id = UUID()
        #expect(
            ScheduleInvestmentMaturityRemindersUseCase.notificationIdentifier(for: id)
                == ScheduleInvestmentMaturityRemindersUseCase.notificationIdentifier(for: id)
        )
    }

    @Test("days to maturity counts whole days and goes negative after the date")
    func daysToMaturityIsDayGranular() {
        let record = investment(maturity: date(2026, 1, 11))
        #expect(record.daysToMaturity(from: date(2026, 1, 1)) == 10)
        #expect(record.daysToMaturity(from: date(2026, 1, 11)) == 0)
        #expect(record.hasMatured(asOf: date(2026, 1, 11)))
        #expect(record.hasMatured(asOf: date(2026, 1, 1)) == false)
        #expect(investment(maturity: nil).daysToMaturity() == nil)
        #expect(investment(maturity: nil).hasMatured() == false)
    }
}
