import Foundation
import SwiftUI
import StoreKit
import VittoraCore

/// Decides whether this is a good moment to ask for an App Store rating.
///
/// Apple's `requestReview` already caps the system prompt at three times a year and may
/// show nothing at all, so this only decides whether to *ask*. The rules follow Apple's
/// guidance: ask after a positive moment, never on first use or straight after an error,
/// at most once per app version, and not again within `minimumDaysBetweenPrompts`.
///
/// The positive moments are saving a transaction once someone has ten or more, and
/// opening Year in Review. Both need a week since first launch, so the person has used
/// the app for real before being asked about it.
final class ReviewPromptPolicy: @unchecked Sendable {
    nonisolated static let minimumTransactions = 10
    nonisolated static let minimumDaysSinceFirstLaunch = 7
    nonisolated static let minimumDaysBetweenPrompts = 60

    private nonisolated(unsafe) let defaults: UserDefaults
    private nonisolated let appVersion: String
    private nonisolated let nowProvider: @Sendable () -> Date
    private nonisolated let lock = NSLock()

    private enum Keys {
        nonisolated static let firstLaunch = "vittora.review.firstLaunch"
        nonisolated static let lastPromptDate = "vittora.review.lastPromptDate"
        nonisolated static let lastPromptVersion = "vittora.review.lastPromptVersion"
    }

    nonisolated init(
        defaults: UserDefaults = AppUserDefaults.conversion,
        appVersion: String = ReviewPromptPolicy.bundleVersion,
        nowProvider: @escaping @Sendable () -> Date = { Date.now }
    ) {
        self.defaults = defaults
        self.appVersion = appVersion
        self.nowProvider = nowProvider
    }

    nonisolated static var bundleVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// Records the first launch the policy sees. Existing users start counting from the
    /// update that introduces this, which only delays their first ask by a week.
    nonisolated func noteLaunch() {
        lock.lock()
        defer { lock.unlock() }
        if defaults.object(forKey: Keys.firstLaunch) == nil {
            defaults.set(nowProvider(), forKey: Keys.firstLaunch)
        }
    }

    /// True when it is a good moment to ask, and records the ask so the next one waits.
    nonisolated func claimPrompt(transactionCount: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let now = nowProvider()
        guard transactionCount >= Self.minimumTransactions,
              let firstLaunch = defaults.object(forKey: Keys.firstLaunch) as? Date,
              now.timeIntervalSince(firstLaunch) >= Self.days(Self.minimumDaysSinceFirstLaunch),
              defaults.string(forKey: Keys.lastPromptVersion) != appVersion
        else { return false }
        if let last = defaults.object(forKey: Keys.lastPromptDate) as? Date,
           now.timeIntervalSince(last) < Self.days(Self.minimumDaysBetweenPrompts) {
            return false
        }
        defaults.set(now, forKey: Keys.lastPromptDate)
        defaults.set(appVersion, forKey: Keys.lastPromptVersion)
        return true
    }

    /// UI tests share the simulator's defaults across runs: mark this version as already
    /// asked so no rating sheet lands on top of whichever test reaches ten transactions.
    nonisolated static func suppressForUITesting(in defaults: UserDefaults = AppUserDefaults.conversion) {
        defaults.set(bundleVersion, forKey: Keys.lastPromptVersion)
    }

    private nonisolated static func days(_ count: Int) -> TimeInterval {
        TimeInterval(count * 24 * 60 * 60)
    }
}

/// Holds the app-wide request to show the rating prompt. The root view owns the
/// `requestReview` action, so a screen that is about to close (the transaction form)
/// can still ask: it bumps `requests`, and the root asks once the sheet has gone.
@MainActor
@Observable
final class ReviewPromptPresenter {
    private(set) var requests = 0
    func request() { requests += 1 }
}

/// Bridges positive moments in the app to the policy and the presenter.
struct ReviewPrompter: Sendable {
    let policy: ReviewPromptPolicy
    let transactionRepository: any TransactionRepository

    /// After a new transaction is saved. Skipped when the paywall is about to open:
    /// one interruption per moment.
    @MainActor
    func afterTransactionSaved(paywallShowing: Bool, presenter: ReviewPromptPresenter) async {
        guard !paywallShowing else { return }
        await askIfDue(presenter)
    }

    @MainActor
    func afterYearInReviewViewed(presenter: ReviewPromptPresenter) async {
        await askIfDue(presenter)
    }

    @MainActor
    private func askIfDue(_ presenter: ReviewPromptPresenter) async {
        guard let count = try? await transactionRepository.fetchTransactionCount(),
              policy.claimPrompt(transactionCount: count) else { return }
        presenter.request()
    }
}

private struct ReviewPromptHost: ViewModifier {
    let presenter: ReviewPromptPresenter
    @Environment(\.requestReview) private var requestReview

    func body(content: Content) -> some View {
        content.onChange(of: presenter.requests) {
            Task {
                // Let a closing sheet finish animating first; a prompt over a moving
                // sheet is easy to dismiss by accident.
                try? await Task.sleep(for: .seconds(1))
                requestReview()
            }
        }
    }
}

extension View {
    /// Hosts the app-wide rating prompt. Declared once, at the root.
    func reviewPromptHost(_ presenter: ReviewPromptPresenter) -> some View {
        modifier(ReviewPromptHost(presenter: presenter))
    }
}
