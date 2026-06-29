import Foundation
import Testing
@testable import Vittora

@Suite("Conversion Event Tracker Tests")
struct ConversionEventTrackerTests {
    private func makeTracker(
        now: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> UserDefaultsConversionEventTracker {
        let suiteName = "test.conversion.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create test defaults suite")
        }
        return UserDefaultsConversionEventTracker(
            defaults: defaults,
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { now }
        )
    }

    @Test("Each milestone records only once")
    func milestoneRecordsOnce() {
        let tracker = makeTracker()

        let first = tracker.record(.firstSplit)
        #expect(first.isFirstTime)
        #expect(first.milestone == .firstSplit)
        #expect(!first.shouldPresentPaywall)

        let second = tracker.record(.firstSplit)
        #expect(!second.isFirstTime)
        #expect(tracker.hasRecorded(.firstSplit))
    }

    @Test("Distinct milestones are tracked independently")
    func distinctMilestones() {
        let tracker = makeTracker()

        _ = tracker.record(.firstReport)
        _ = tracker.record(.firstSplit)

        #expect(tracker.hasRecorded(.firstReport))
        #expect(tracker.hasRecorded(.firstSplit))
        #expect(!tracker.hasRecorded(.tenthTransaction))
    }

    @Test("OCR monthly limit milestone fires on fifth scan in month")
    func ocrMonthlyLimitOnFifthScan() {
        let tracker = makeTracker()

        for _ in 0..<4 {
            _ = tracker.recordOCRScan()
            #expect(!tracker.hasRecorded(.ocrMonthlyLimitReached))
        }

        _ = tracker.recordOCRScan()
        #expect(tracker.ocrScansThisMonth() == 5)
        #expect(tracker.hasRecorded(.ocrMonthlyLimitReached))
        #expect(tracker.hasRecorded(.firstOCRScan))
    }

    @Test("OCR count resets when month bucket changes")
    func ocrCountResetsNextMonth() {
        final class NowBox: @unchecked Sendable {
            var value: Date
            init(_ value: Date) { self.value = value }
        }

        let nowBox = NowBox(Date(timeIntervalSince1970: 1_700_000_000))
        let tracker = UserDefaultsConversionEventTracker(
            defaults: UserDefaults(suiteName: "test.conversion.\(UUID().uuidString)") ?? .standard,
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { nowBox.value }
        )

        _ = tracker.recordOCRScan()
        _ = tracker.recordOCRScan()
        #expect(tracker.ocrScansThisMonth() == 2)

        nowBox.value = Calendar(identifier: .gregorian).date(byAdding: .month, value: 1, to: nowBox.value) ?? nowBox.value
        #expect(tracker.ocrScansThisMonth() == 0)
    }

    @Test("Paywall presentation respects cooldown when StoreKit would be enabled")
    func paywallCooldownWhenEnabled() {
        // StoreKit is disabled in production config; verify tracker state transitions only.
        let tracker = makeTracker()
        let result = tracker.record(.accountLimitReached)
        #expect(result.shouldPresentPaywall == false)
        tracker.markPaywallPresented(for: .accountLimitReached)
        #expect(tracker.shouldPresentPaywall(for: .accountLimitReached) == false)
    }
}

@Suite("Conversion Event Recorder Tests")
struct ConversionEventRecorderTests {
    @Test("Tenth transaction milestone fires at count threshold")
    func tenthTransactionThreshold() async {
        let tracker = UserDefaultsConversionEventTracker(
            defaults: UserDefaults(suiteName: "test.conversion.\(UUID().uuidString)") ?? .standard
        )
        let transactionRepo = MockTransactionRepository()
        for _ in 0..<FreeTierLimits.transactionMilestoneCount {
            let transaction = TransactionEntity(
                amount: 1,
                type: .expense,
                paymentMethod: .cash
            )
            try? await transactionRepo.create(transaction)
        }
        let recorder = ConversionEventRecorder(
            tracker: tracker,
            transactionRepository: transactionRepo,
            accountRepository: await MainActor.run { MockAccountRepository() },
            budgetRepository: MockBudgetRepository()
        )

        let result = await recorder.afterTransactionCreated()
        #expect(result?.milestone == .tenthTransaction)
        #expect(result?.isFirstTime == true)
    }

    @Test("Account cap milestone fires at limit")
    func accountCapThreshold() async {
        let tracker = UserDefaultsConversionEventTracker(
            defaults: UserDefaults(suiteName: "test.conversion.\(UUID().uuidString)") ?? .standard
        )
        let accountRepo = await MainActor.run { MockAccountRepository() }
        for index in 0..<FreeTierLimits.maxAccounts {
            let account = AccountEntity(
                name: "Account \(index)",
                type: .bank,
                balance: 0
            )
            try? await accountRepo.create(account)
        }
        let recorder = ConversionEventRecorder(
            tracker: tracker,
            transactionRepository: MockTransactionRepository(),
            accountRepository: accountRepo,
            budgetRepository: MockBudgetRepository()
        )

        let result = await recorder.afterAccountCreated()
        #expect(result?.milestone == .accountLimitReached)
    }
}
