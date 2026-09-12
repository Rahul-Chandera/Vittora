import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("Paywall Presenter Tests")
@MainActor
struct PaywallPresenterTests {
    /// Mutable clock so a test can step past the cooldown.
    private final class TestClock: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func makeTracker(clock: TestClock, storeKitEnabled: Bool = true) -> UserDefaultsConversionEventTracker {
        let suiteName = "test.paywall.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create test defaults suite")
        }
        return UserDefaultsConversionEventTracker(
            defaults: defaults,
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { clock.now },
            storeKitEnabled: storeKitEnabled
        )
    }

    /// Catches a regression where nil results still open the paywall sheet.
    @Test("a nil result never presents")
    func nilResultNeverPresents() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let tracker = makeTracker(clock: clock)
        let presenter = PaywallPresenter(tracker: tracker)
        presenter.present(nil)
        #expect(presenter.milestone == nil)
    }

    /// Catches a regression where a first-time milestone is ignored and the paywall stays closed.
    @Test("a first-time milestone presents the paywall")
    func firstTimeMilestonePresents() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let tracker = makeTracker(clock: clock)
        let presenter = PaywallPresenter(tracker: tracker)
        presenter.present(tracker.record(.firstReport))
        #expect(presenter.milestone == .firstReport)
    }

    /// Catches a regression where the StoreKit kill switch no longer suppresses presentation.
    @Test("the paywall stays dormant while StoreKit is disabled")
    func paywallDormantWhenStoreKitDisabled() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let tracker = makeTracker(clock: clock, storeKitEnabled: false)
        let presenter = PaywallPresenter(tracker: tracker)
        presenter.present(tracker.record(.firstReport))
        #expect(presenter.milestone == nil)
    }

    /// Catches a regression where the same milestone re-presents after dismiss.
    @Test("a repeated milestone does not present again")
    func repeatedMilestoneDoesNotPresentAgain() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let tracker = makeTracker(clock: clock)
        let presenter = PaywallPresenter(tracker: tracker)
        presenter.present(tracker.record(.firstReport))
        presenter.dismiss()
        presenter.present(tracker.record(.firstReport))
        #expect(presenter.milestone == nil)
    }

    /// Catches a regression where presenting fails to start the cooldown, so a different milestone shows too soon.
    @Test("presenting starts the cooldown, so the next milestone is suppressed")
    func presentingStartsCooldownSuppressingNextMilestone() {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let clock = TestClock(t)
        let tracker = makeTracker(clock: clock)
        let presenter = PaywallPresenter(tracker: tracker)
        presenter.present(tracker.record(.firstReport))
        #expect(presenter.milestone == .firstReport)
        presenter.dismiss()
        clock.now = t.addingTimeInterval(86_400)
        presenter.present(tracker.record(.firstSplit))
        #expect(presenter.milestone == nil) // suppressed: inside paywallPresentationCooldownDays
    }

    /// Catches a regression where the cooldown never expires, blocking later milestones forever.
    @Test("the cooldown expires and a later milestone presents again")
    func cooldownExpiresAndLaterMilestonePresents() {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let clock = TestClock(t)
        let tracker = makeTracker(clock: clock)
        let presenter = PaywallPresenter(tracker: tracker)
        presenter.present(tracker.record(.firstReport))
        #expect(presenter.milestone == .firstReport)
        presenter.dismiss()
        clock.now = t.addingTimeInterval(86_400)
        presenter.present(tracker.record(.firstSplit))
        #expect(presenter.milestone == nil)
        let cooldownOffset = TimeInterval(
            (MonetizationConfiguration.paywallPresentationCooldownDays + 1) * 24 * 60 * 60
        )
        clock.now = t.addingTimeInterval(cooldownOffset)
        presenter.present(tracker.record(.tenthTransaction))
        #expect(presenter.milestone == .tenthTransaction)
    }

    /// Catches a regression where a declined present still consumes the cooldown window.
    @Test("declining to present does not start the cooldown")
    func decliningDoesNotStartCooldown() {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let clock = TestClock(t)
        let tracker = makeTracker(clock: clock)
        let presenter = PaywallPresenter(tracker: tracker)
        _ = tracker.record(.firstReport)
        presenter.present(tracker.record(.firstReport)) // second time -> not first-time -> declined
        #expect(presenter.milestone == nil)
        presenter.present(tracker.record(.firstSplit))
        #expect(presenter.milestone == .firstSplit) // the declined attempt must NOT have consumed the cooldown
    }
}
