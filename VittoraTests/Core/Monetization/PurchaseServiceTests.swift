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

private struct StubPurchaseFailure: Error {}

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

    /// Catches a regression where a failed or cancelled StoreKit-view purchase still unlocks Pro.
    @Test("a failed store purchase unlocks nothing")
    func failedStorePurchaseUnlocksNothing() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let (cache, _) = makeCache()
        let store = EntitlementStore(cache: cache, now: { now }, standing: { _ in .unknown })
        let service = PurchaseService(entitlements: store)
        let gate = FeatureGate(store: store, tracker: ZeroScanTracker(), storeKitEnabled: true)

        let granted = await service.completeStorePurchase(.failure(StubPurchaseFailure()))

        #expect(granted == false)
        #expect(service.level == .free)
        #expect(gate.isProUnlocked == false)
    }
}
