import Foundation
import Testing
@testable import Vittora

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
}
