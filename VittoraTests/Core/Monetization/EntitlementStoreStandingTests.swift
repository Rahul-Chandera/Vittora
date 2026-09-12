import Foundation
import Testing
@testable import Vittora

/// The cancellation window is the one place where honouring an offline user and cutting
/// off a canceller pull in opposite directions, so each branch is pinned separately.
@Suite("Entitlement Store Standing Tests")
struct EntitlementStoreStandingTests {
    private let expiry = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeCache() throws -> (EntitlementCache, UserDefaults, String) {
        let suiteName = "test.standing.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (EntitlementCache(defaults: defaults), defaults, suiteName)
    }

    private func saveProSnapshot(_ cache: EntitlementCache, productID: String, expiration: Date?) {
        cache.save(
            EntitlementSnapshot(
                level: .pro,
                productID: productID,
                expirationDate: expiration,
                isInBillingRetry: false,
                recordedAt: expiry
            )
        )
    }

    /// Inside the grace window, day 15.
    private var insideGrace: Date { expiry.addingTimeInterval(15 * 86_400) }
    /// Past the 16-day grace window, day 17.
    private var pastGrace: Date { expiry.addingTimeInterval(17 * 86_400) }

    /// Catches a regression where a confirmed canceller keeps Pro for the full offline grace.
    @Test("a lapsed subscription drops to free immediately, inside the grace window")
    func lapsedSubscriptionDropsToFree() async throws {
        let (cache, defaults, suite) = try makeCache()
        defer { defaults.removePersistentDomain(forName: suite) }
        saveProSnapshot(cache, productID: ProProduct.annual.rawValue, expiration: expiry)
        let store = EntitlementStore(cache: cache, now: { self.insideGrace }, standing: { _ in .lapsed })
        #expect(await store.refresh() == .free)
        #expect(cache.load() == nil, "a confirmed lapse must clear the cached snapshot")
    }

    /// Catches a regression where Apple's own billing retry is treated as a cancellation.
    @Test("a subscription in billing retry keeps Pro inside the grace window")
    func retryingSubscriptionKeepsPro() async throws {
        let (cache, defaults, suite) = try makeCache()
        defer { defaults.removePersistentDomain(forName: suite) }
        saveProSnapshot(cache, productID: ProProduct.annual.rawValue, expiration: expiry)
        let store = EntitlementStore(cache: cache, now: { self.insideGrace }, standing: { _ in .retrying })
        #expect(await store.refresh() == .pro)
    }

    /// Catches a regression where an offline device is downgraded on an unanswerable question.
    @Test("an unanswerable status keeps the offline grace")
    func unknownStandingKeepsOfflineGrace() async throws {
        let (cache, defaults, suite) = try makeCache()
        defer { defaults.removePersistentDomain(forName: suite) }
        saveProSnapshot(cache, productID: ProProduct.annual.rawValue, expiration: expiry)
        let store = EntitlementStore(cache: cache, now: { self.insideGrace }, standing: { _ in .unknown })
        #expect(await store.refresh() == .pro)
    }

    /// Catches a regression where the offline grace stops expiring on its own.
    @Test("the offline grace still ends after 16 days")
    func offlineGraceStillExpires() async throws {
        let (cache, defaults, suite) = try makeCache()
        defer { defaults.removePersistentDomain(forName: suite) }
        saveProSnapshot(cache, productID: ProProduct.annual.rawValue, expiration: expiry)
        let store = EntitlementStore(cache: cache, now: { self.pastGrace }, standing: { _ in .unknown })
        #expect(await store.refresh() == .free)
    }

    /// Catches the worst regression available here: revoking a one-time purchase because a
    /// subscription status came back lapsed. Lifetime has no expiry and must never be asked.
    @Test("a lifetime purchase is never revoked by a lapsed subscription status")
    func lifetimeSurvivesLapsedStanding() async throws {
        let (cache, defaults, suite) = try makeCache()
        defer { defaults.removePersistentDomain(forName: suite) }
        saveProSnapshot(cache, productID: ProProduct.lifetime.rawValue, expiration: nil)
        let store = EntitlementStore(cache: cache, now: { self.pastGrace }, standing: { _ in .lapsed })
        #expect(await store.refresh() == .pro)
        #expect(cache.load() != nil)
    }
}
