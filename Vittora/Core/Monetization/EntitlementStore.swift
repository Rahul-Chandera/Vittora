import Foundation
import StoreKit

/// Reads the user's Pro entitlement from StoreKit 2 and caches it for offline launches.
/// F2 (paywall) and F3 (gating) build on this; purchase and restore flows are not here yet.
actor EntitlementStore {
    // ponytail: no Transaction.updates listener, purchase, or restore — those land in F2/F4.
    private nonisolated let cache: EntitlementCache
    private nonisolated let now: @Sendable () -> Date

    init(
        cache: EntitlementCache = EntitlementCache(),
        now: @escaping @Sendable () -> Date = { Date.now }
    ) {
        self.cache = cache
        self.now = now
    }

    /// Cached answer only — no network, safe to call on every gate check.
    nonisolated func cachedLevel() -> EntitlementLevel {
        EntitlementPolicy.resolve(cache.load(), now: now())
    }

    /// Reads `Transaction.currentEntitlements`, updates the cache, returns the new level.
    @discardableResult
    func refresh() async -> EntitlementLevel {
        let recordedAt = now()
        var best: EntitlementSnapshot?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard ProProduct.allIdentifiers.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }

            // ponytail: isInBillingRetry stays false; grace-period detection lands with F3.
            let candidate = EntitlementSnapshot(
                level: .pro,
                productID: transaction.productID,
                expirationDate: transaction.expirationDate,
                isInBillingRetry: false,
                recordedAt: recordedAt
            )

            guard let candidateExpiry = candidate.expirationDate else {
                // Lifetime never expires and outranks any subscription.
                best = candidate
                break
            }
            // Otherwise keep the entitlement that runs longest. `best` is only ever a
            // subscription here; a lifetime one would have broken out of the loop.
            if let currentExpiry = best?.expirationDate, candidateExpiry <= currentExpiry {
                continue
            }
            best = candidate
        }

        if let best {
            cache.save(best)
            return EntitlementPolicy.resolve(best, now: recordedAt)
        }

        // No verified Pro entitlement on device. `currentEntitlements` reads the local signed
        // transaction cache, so this is normally authoritative — but it is also what a device
        // that has been offline across a renewal boundary reports, because StoreKit drops the
        // lapsed transaction before it can see the renewal. We therefore leave the cached
        // snapshot in place and let `EntitlementPolicy` decide: it keeps Pro alive for
        // `offlineGraceDays` past the recorded expiry, then falls back to free on its own.
        // ponytail: the cost is that a voluntary canceller keeps Pro for the same window.
        // Narrowing that needs `Product.SubscriptionInfo.Status` (billing-retry vs expired),
        // which is an extra async round trip — it lands with F3.
        return EntitlementPolicy.resolve(cache.load(), now: recordedAt)
    }
}
