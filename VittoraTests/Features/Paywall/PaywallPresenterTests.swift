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
        let presenter = PaywallPresenter(tracker: tracker, isProUnlocked: { false })
        presenter.present(nil)
        #expect(presenter.milestone == nil)
    }

    /// Catches a regression where a first-time milestone is ignored and the paywall stays closed.
    @Test("a first-time milestone presents the paywall")
    func firstTimeMilestonePresents() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let tracker = makeTracker(clock: clock)
        let presenter = PaywallPresenter(tracker: tracker, isProUnlocked: { false })
        presenter.present(tracker.record(.firstReport))
        #expect(presenter.milestone == .firstReport)
    }

    /// Catches a regression where the StoreKit kill switch no longer suppresses presentation.
    @Test("the paywall stays dormant while StoreKit is disabled")
    func paywallDormantWhenStoreKitDisabled() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let tracker = makeTracker(clock: clock, storeKitEnabled: false)
        let presenter = PaywallPresenter(tracker: tracker, isProUnlocked: { false })
        presenter.present(tracker.record(.firstReport))
        #expect(presenter.milestone == nil)
    }

    /// Catches a regression where the same milestone re-presents after dismiss.
    @Test("a repeated milestone does not present again")
    func repeatedMilestoneDoesNotPresentAgain() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let tracker = makeTracker(clock: clock)
        let presenter = PaywallPresenter(tracker: tracker, isProUnlocked: { false })
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
        let presenter = PaywallPresenter(tracker: tracker, isProUnlocked: { false })
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
        let presenter = PaywallPresenter(tracker: tracker, isProUnlocked: { false })
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
        let presenter = PaywallPresenter(tracker: tracker, isProUnlocked: { false })
        _ = tracker.record(.firstReport)
        presenter.present(tracker.record(.firstReport)) // second time -> not first-time -> declined
        #expect(presenter.milestone == nil)
        presenter.present(tracker.record(.firstSplit))
        #expect(presenter.milestone == .firstSplit) // the declined attempt must NOT have consumed the cooldown
    }

    /// Catches a regression where deferring presents immediately instead of waiting for the covering sheet.
    @Test("a deferred result does not present until the covering sheet closes")
    func deferredResultDoesNotPresentUntilSheetCloses() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let tracker = makeTracker(clock: clock)
        let presenter = PaywallPresenter(tracker: tracker, isProUnlocked: { false })
        let result = tracker.record(.firstOCRScan)
        presenter.presentWhenSheetCloses(result)
        #expect(presenter.milestone == nil)
        presenter.presentPending()
        #expect(presenter.milestone == .firstOCRScan)
    }

    /// Catches a regression where deferring alone starts the cooldown before the paywall is shown.
    @Test("a deferred result that was never flushed does not consume the cooldown")
    func deferredResultNeverFlushedDoesNotConsumeCooldown() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let tracker = makeTracker(clock: clock)
        let presenter = PaywallPresenter(tracker: tracker, isProUnlocked: { false })
        presenter.presentWhenSheetCloses(tracker.record(.firstOCRScan))
        presenter.present(tracker.record(.firstReport))
        #expect(presenter.milestone == .firstReport)
    }

    /// Catches the regression this was written for: a paying subscriber being shown the
    /// upgrade paywall by an ordinary value event.
    @Test("a Pro user is never shown the value-event paywall")
    func proUserIsNeverShownThePaywall() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let tracker = makeTracker(clock: clock)
        let presenter = PaywallPresenter(tracker: tracker, isProUnlocked: { true })
        presenter.present(tracker.record(.firstReport))
        #expect(presenter.milestone == nil)
    }

    /// Catches a regression where suppressing the paywall for a Pro user still burns the
    /// cooldown, so a later downgrade to free sees no paywall for a week.
    @Test("suppressing the paywall for a Pro user does not consume the cooldown")
    func suppressedProPresentationDoesNotConsumeCooldown() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let tracker = makeTracker(clock: clock)
        let proPresenter = PaywallPresenter(tracker: tracker, isProUnlocked: { true })
        proPresenter.present(tracker.record(.firstReport))
        #expect(proPresenter.milestone == nil)
        let freePresenter = PaywallPresenter(tracker: tracker, isProUnlocked: { false })
        freePresenter.present(tracker.record(.firstSplit))
        #expect(freePresenter.milestone == .firstSplit)
    }
}
