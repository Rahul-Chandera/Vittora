import Foundation
import Testing
@testable import Vittora

private struct ZeroScanTracker: ConversionEventTracking, Sendable {
    nonisolated func record(_ milestone: ConversionMilestone) -> ConversionEventResult {
        ConversionEventResult(milestone: milestone, isFirstTime: false, shouldPresentPaywall: false)
    }
    nonisolated func shouldPresentPaywall(for milestone: ConversionMilestone) -> Bool { false }
    nonisolated func markPaywallPresented(for milestone: ConversionMilestone) {}
    nonisolated func hasRecorded(_ milestone: ConversionMilestone) -> Bool { false }
    nonisolated func recordOCRScan() -> ConversionEventResult {
        ConversionEventResult(milestone: .firstOCRScan, isFirstTime: false, shouldPresentPaywall: false)
    }
    nonisolated func ocrScansThisMonth() -> Int { 0 }
}

@Suite("Purchase Service Tests")
@MainActor
struct PurchaseServiceTests {
    private func makeCache() -> (EntitlementCache, UserDefaults) {
        let suiteName = "test.purchase.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create test defaults suite")
        }
        return (EntitlementCache(defaults: defaults), defaults)
    }

    /// Catches a regression where the service starts at .free and an offline Pro user sees a paywall on every cold launch until StoreKit answers.
    @Test("a cold launch reports the cached entitlement before StoreKit answers")
    func coldLaunchReportsCachedEntitlement() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (cache, _) = makeCache()
        cache.save(
            EntitlementSnapshot(
                level: .pro,
                productID: ProProduct.annual.rawValue,
                expirationDate: now.addingTimeInterval(30 * 86_400),
                isInBillingRetry: false,
                recordedAt: now
            )
        )
        let service = PurchaseService(entitlements: EntitlementStore(cache: cache, now: { now }))
        #expect(service.level == .pro)
    }

    /// Catches a regression where an empty cache is treated as Pro.
    @Test("an empty cache reports free")
    func emptyCacheReportsFree() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (cache, _) = makeCache()
        let service = PurchaseService(entitlements: EntitlementStore(cache: cache, now: { now }))
        #expect(service.level == .free)
    }

    /// Catches a regression where products appear populated before loadProducts runs.
    @Test("no products are offered until they load")
    func noProductsUntilLoaded() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (cache, _) = makeCache()
        let service = PurchaseService(entitlements: EntitlementStore(cache: cache, now: { now }))
        #expect(service.products.isEmpty)
        #expect(service.product(for: .lifetime) == nil)
        #expect(!service.didFailToLoadProducts)
    }

    /// Catches a regression where restore syncs with the App Store but never refreshes the
    /// published level, leaving a restored user looking free until the next cold launch.
    @Test("refreshing the entitlement republishes the level")
    func refreshEntitlementRepublishesLevel() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (cache, _) = makeCache()
        let store = EntitlementStore(cache: cache, now: { now }, standing: { _ in .unknown })
        let service = PurchaseService(entitlements: store)
        #expect(service.level == .free)
        cache.save(
            EntitlementSnapshot(
                level: .pro,
                productID: ProProduct.lifetime.rawValue,
                expirationDate: nil,
                isInBillingRetry: false,
                recordedAt: now
            )
        )
        await service.refreshEntitlement()
        #expect(service.level == .pro)
    }

    /// Catches a regression where an empty success is still treated as a successful load;
    /// PaywallView keys its degraded state off this flag, so the flag must track what the
    /// user can actually be shown, not merely whether StoreKit threw.
    @Test("a load that serves no products is reported as a failed load")
    func emptyProductLoadIsReportedAsFailure() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (cache, _) = makeCache()
        let service = PurchaseService(entitlements: EntitlementStore(cache: cache, now: { now }))
        await service.loadProducts()
        #expect(service.didFailToLoadProducts == service.products.isEmpty)
    }

    /// Catches the 1.7.0 "paid but still locked" regression: the entitlement changed but the
    /// gate kept answering from a stale source, so a paying user stayed locked out of every Pro
    /// surface. Asserting that refreshEntitlement() ran would have passed against that bug —
    /// this asserts what the gated views actually read.
    @Test("the gate unlocks as soon as the entitlement becomes Pro")
    func gateFollowsEntitlementUpgrade() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (cache, _) = makeCache()
        // Mirrors DependencyContainer: one EntitlementStore behind both the service and the gate.
        let store = EntitlementStore(cache: cache, now: { now }, standing: { _ in .unknown })
        let service = PurchaseService(entitlements: store)
        let gate = FeatureGate(store: store, tracker: ZeroScanTracker(), storeKitEnabled: true)

        #expect(service.level == .free)
        #expect(gate.isProUnlocked == false)

        cache.save(
            EntitlementSnapshot(
                level: .pro,
                productID: ProProduct.annual.rawValue,
                expirationDate: now.addingTimeInterval(365 * 86_400),
                isInBillingRetry: false,
                recordedAt: now
            )
        )
        await service.refreshEntitlement()

        #expect(service.level == .pro)
        #expect(gate.isProUnlocked == true)
    }

    /// The gate must follow the entitlement downward too: a lapsed subscription that StoreKit
    /// confirms is over must relock Pro rather than leaving the last cached answer in place.
    @Test("the gate relocks once a lapsed subscription is confirmed over")
    func gateFollowsEntitlementDowngrade() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (cache, _) = makeCache()
        let store = EntitlementStore(cache: cache, now: { now }, standing: { _ in .lapsed })
        cache.save(
            EntitlementSnapshot(
                level: .pro,
                productID: ProProduct.annual.rawValue,
                expirationDate: now.addingTimeInterval(-86_400),
                isInBillingRetry: false,
                recordedAt: now.addingTimeInterval(-365 * 86_400)
            )
        )
        let service = PurchaseService(entitlements: store)
        let gate = FeatureGate(store: store, tracker: ZeroScanTracker(), storeKitEnabled: true)
        #expect(service.level == .pro)
        #expect(gate.isProUnlocked == true)

        await service.refreshEntitlement()

        #expect(service.level == .free)
        #expect(gate.isProUnlocked == false)
    }

    /// Guideline 3.1.2: the paywall may only advertise the 7-day trial to an account that can
    /// actually get it. Catches a regression where the flag starts true, which would promise a
    /// trial on every cold launch in the window before StoreKit answers — including to a
    /// returning subscriber, and including to App Review, who commonly test with exactly that
    /// account.
    @Test("the trial is not advertised until StoreKit answers")
    func introOfferIsNotAdvertisedBeforeProductsLoad() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (cache, _) = makeCache()
        let service = PurchaseService(entitlements: EntitlementStore(cache: cache, now: { now }))
        #expect(service.isEligibleForIntroOffer == false)
    }

    /// The other half of the same rule: every failure path must land on "no trial". A load that
    /// serves nothing cannot tell us the account is eligible, and guessing yes there is the
    /// expensive direction to be wrong in — an advertised price the account cannot get, versus
    /// a missed conversion.
    @Test("a load that serves no products leaves the trial unadvertised")
    func introOfferIsNotAdvertisedWhenProductsFailToLoad() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (cache, _) = makeCache()
        let service = PurchaseService(entitlements: EntitlementStore(cache: cache, now: { now }))
        await service.loadProducts()
        if service.products.isEmpty {
            #expect(service.isEligibleForIntroOffer == false)
        }
    }

    /// The paywall's "You already have Vittora Pro" copy branches on this. Catches a
    /// regression where an inherited entitlement is described as the user's own, which tells
    /// a family member to cancel a plan they cannot see in their Apple Account settings.
    @Test("an inherited entitlement is reported as family shared, not as a purchase")
    func familySharedEntitlementIsReportedAsShared() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (cache, _) = makeCache()
        cache.save(
            EntitlementSnapshot(
                level: .pro,
                productID: ProProduct.annual.rawValue,
                expirationDate: now.addingTimeInterval(365 * 86_400),
                isInBillingRetry: false,
                recordedAt: now,
                isFamilyShared: true
            )
        )
        let service = PurchaseService(entitlements: EntitlementStore(cache: cache, now: { now }))
        #expect(service.proEntitlementKind == .familyShared)
    }

    /// Family Sharing is checked before the product on purpose: lifetime is Family Shareable
    /// too (DEC-013), so an inherited lifetime must not read as this user's own purchase.
    @Test("an inherited lifetime is shared, not owned")
    func familySharedLifetimeIsReportedAsShared() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (cache, _) = makeCache()
        cache.save(
            EntitlementSnapshot(
                level: .pro,
                productID: ProProduct.lifetime.rawValue,
                expirationDate: nil,
                isInBillingRetry: false,
                recordedAt: now,
                isFamilyShared: true
            )
        )
        let service = PurchaseService(entitlements: EntitlementStore(cache: cache, now: { now }))
        #expect(service.proEntitlementKind == .familyShared)
    }

    /// Catches a regression where a Lifetime owner is told to manage a renewal that does
    /// not exist.
    @Test("an owned lifetime is reported as lifetime")
    func ownedLifetimeIsReportedAsLifetime() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (cache, _) = makeCache()
        cache.save(
            EntitlementSnapshot(
                level: .pro,
                productID: ProProduct.lifetime.rawValue,
                expirationDate: nil,
                isInBillingRetry: false,
                recordedAt: now,
                isFamilyShared: false
            )
        )
        let service = PurchaseService(entitlements: EntitlementStore(cache: cache, now: { now }))
        #expect(service.proEntitlementKind == .lifetime)
    }

    /// A snapshot written by a build that predates the flag decodes with nil, which must read
    /// as "not shared" rather than failing to decode and dropping a paying user to free.
    @Test("a snapshot from before the family-sharing flag reads as an ordinary subscription")
    func snapshotWithoutFamilyFlagReadsAsSubscription() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (cache, _) = makeCache()
        cache.save(
            EntitlementSnapshot(
                level: .pro,
                productID: ProProduct.annual.rawValue,
                expirationDate: now.addingTimeInterval(365 * 86_400),
                isInBillingRetry: false,
                recordedAt: now
            )
        )
        let service = PurchaseService(entitlements: EntitlementStore(cache: cache, now: { now }))
        #expect(service.level == .pro)
        #expect(service.proEntitlementKind == .subscription)
    }

    /// A free user has no entitlement to describe.
    @Test("a free user reports no entitlement kind")
    func freeUserReportsNoEntitlementKind() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (cache, _) = makeCache()
        let service = PurchaseService(entitlements: EntitlementStore(cache: cache, now: { now }))
        #expect(service.proEntitlementKind == .none)
    }

}
