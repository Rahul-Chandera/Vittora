import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("Review Prompt Policy Tests")
struct ReviewPromptPolicyTests {
    private final class Clock: @unchecked Sendable {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        func advance(days: Int) { now = now.addingTimeInterval(TimeInterval(days * 86_400)) }
    }

    private func makeDefaults() -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: "test.review.\(UUID().uuidString)") else {
            fatalError("Failed to create test defaults suite")
        }
        return defaults
    }

    private func makePolicy(
        defaults: UserDefaults,
        clock: Clock,
        version: String = "1.9.0"
    ) -> ReviewPromptPolicy {
        ReviewPromptPolicy(defaults: defaults, appVersion: version, nowProvider: { clock.now })
    }

    @Test("Never asks in the first week, however many transactions")
    func waitsAWeekAfterFirstLaunch() {
        let clock = Clock()
        let policy = makePolicy(defaults: makeDefaults(), clock: clock)
        policy.noteLaunch()
        clock.advance(days: 6)
        #expect(!policy.claimPrompt(transactionCount: 500))
        clock.advance(days: 1)
        #expect(policy.claimPrompt(transactionCount: 500))
    }

    @Test("Never asks before ten transactions")
    func needsTenTransactions() {
        let clock = Clock()
        let policy = makePolicy(defaults: makeDefaults(), clock: clock)
        policy.noteLaunch()
        clock.advance(days: 30)
        #expect(!policy.claimPrompt(transactionCount: 9))
        #expect(policy.claimPrompt(transactionCount: 10))
    }

    @Test("Without a recorded first launch it never asks")
    func needsFirstLaunch() {
        let policy = makePolicy(defaults: makeDefaults(), clock: Clock())
        #expect(!policy.claimPrompt(transactionCount: 100))
    }

    @Test("Asks at most once per app version")
    func oncePerVersion() {
        let clock = Clock()
        let policy = makePolicy(defaults: makeDefaults(), clock: clock)
        policy.noteLaunch()
        clock.advance(days: 10)
        #expect(policy.claimPrompt(transactionCount: 20))
        clock.advance(days: 200)
        #expect(!policy.claimPrompt(transactionCount: 40))
    }

    @Test("A new version waits sixty days after the last ask")
    func newVersionRespectsGap() {
        let clock = Clock()
        let defaults = makeDefaults()
        let v1 = makePolicy(defaults: defaults, clock: clock, version: "1.9.0")
        v1.noteLaunch()
        clock.advance(days: 10)
        #expect(v1.claimPrompt(transactionCount: 20))

        let v2 = makePolicy(defaults: defaults, clock: clock, version: "1.9.1")
        clock.advance(days: 59)
        #expect(!v2.claimPrompt(transactionCount: 20))
        clock.advance(days: 1)
        #expect(v2.claimPrompt(transactionCount: 20))
    }

    @Test("A later launch does not reset the first-launch date")
    func firstLaunchIsKept() {
        let clock = Clock()
        let policy = makePolicy(defaults: makeDefaults(), clock: clock)
        policy.noteLaunch()
        clock.advance(days: 8)
        policy.noteLaunch()
        #expect(policy.claimPrompt(transactionCount: 10))
    }

    @Test("UI-test suppression blocks the current version")
    func uiTestSuppression() {
        let clock = Clock()
        let defaults = makeDefaults()
        let policy = makePolicy(defaults: defaults, clock: clock, version: ReviewPromptPolicy.bundleVersion)
        policy.noteLaunch()
        clock.advance(days: 30)
        ReviewPromptPolicy.suppressForUITesting(in: defaults)
        #expect(!policy.claimPrompt(transactionCount: 100))
    }
}
