import Foundation
import Testing
@testable import Vittora

@Suite("Entitlement Policy Tests")
struct EntitlementPolicyTests {
    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
    private let expiry = Date(timeIntervalSince1970: 1_700_086_400)

    @Test("nil snapshot resolves to free")
    func nilSnapshot() {
        #expect(EntitlementPolicy.resolve(nil, now: fixedNow) == .free)
    }

    @Test("free snapshot resolves to free")
    func freeSnapshot() {
        let snapshot = EntitlementSnapshot(
            level: .free,
            productID: nil,
            expirationDate: nil,
            isInBillingRetry: false,
            recordedAt: fixedNow
        )
        #expect(EntitlementPolicy.resolve(snapshot, now: fixedNow) == .free)
    }

    @Test("lifetime pro snapshot stays pro far in the future")
    func lifetimeNeverExpires() {
        let snapshot = EntitlementSnapshot(
            level: .pro,
            productID: ProProduct.lifetime.rawValue,
            expirationDate: nil,
            isInBillingRetry: false,
            recordedAt: fixedNow
        )
        let farFuture = Date(timeIntervalSince1970: 1_700_000_000 + 100 * 365 * 86_400)
        #expect(EntitlementPolicy.resolve(snapshot, now: farFuture) == .pro)
    }

    @Test("pro one hour before expiry stays pro")
    func oneHourBeforeExpiry() {
        let snapshot = EntitlementSnapshot(
            level: .pro,
            productID: ProProduct.monthly.rawValue,
            expirationDate: expiry,
            isInBillingRetry: false,
            recordedAt: fixedNow
        )
        let now = expiry.addingTimeInterval(-3_600)
        #expect(EntitlementPolicy.resolve(snapshot, now: now) == .pro)
    }

    @Test("pro one day after expiry stays pro inside grace")
    func oneDayAfterExpiryInsideGrace() {
        let snapshot = EntitlementSnapshot(
            level: .pro,
            productID: ProProduct.monthly.rawValue,
            expirationDate: expiry,
            isInBillingRetry: false,
            recordedAt: fixedNow
        )
        let now = expiry.addingTimeInterval(86_400)
        #expect(EntitlementPolicy.resolve(snapshot, now: now) == .pro)
    }

    @Test("pro exactly at expiry plus 16 days is free")
    func exactlyAtGraceBoundary() {
        let snapshot = EntitlementSnapshot(
            level: .pro,
            productID: ProProduct.monthly.rawValue,
            expirationDate: expiry,
            isInBillingRetry: false,
            recordedAt: fixedNow
        )
        let now = expiry.addingTimeInterval(TimeInterval(EntitlementPolicy.offlineGraceDays * 86_400))
        #expect(EntitlementPolicy.resolve(snapshot, now: now) == .free)
    }

    @Test("pro 17 days after expiry is free")
    func seventeenDaysAfterExpiry() {
        let snapshot = EntitlementSnapshot(
            level: .pro,
            productID: ProProduct.monthly.rawValue,
            expirationDate: expiry,
            isInBillingRetry: false,
            recordedAt: fixedNow
        )
        let now = expiry.addingTimeInterval(TimeInterval(17 * 86_400))
        #expect(EntitlementPolicy.resolve(snapshot, now: now) == .free)
    }

    @Test("EntitlementCache round-trips and clears")
    func cacheRoundTrip() {
        let suiteName = "test.entitlement.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create test defaults suite \(suiteName)")
            return
        }
        let cache = EntitlementCache(defaults: defaults)
        let snapshot = EntitlementSnapshot(
            level: .pro,
            productID: ProProduct.annual.rawValue,
            expirationDate: expiry,
            isInBillingRetry: false,
            recordedAt: fixedNow
        )

        cache.save(snapshot)
        #expect(cache.load() == snapshot)

        cache.clear()
        #expect(cache.load() == nil)
    }
}
