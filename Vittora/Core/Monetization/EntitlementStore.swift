import Foundation
import StoreKit

/// What StoreKit says about a cached subscription once `Transaction.currentEntitlements`
/// has gone quiet. Injected as a closure so the expiry decision is testable without a
/// StoreKit test session — the decision is ours, the status is Apple's.
nonisolated enum SubscriptionStanding: Sendable, Equatable {
    /// StoreKit confirmed the subscription is over and is not being retried.
    case lapsed
    /// Apple is still retrying billing, or the subscription is in its grace period.
    case retrying
    /// StoreKit could not answer — offline, or the product is not a subscription.
    case unknown
}

/// Reads the user's Pro entitlement from StoreKit 2 and caches it for offline launches.
/// `PurchaseService` owns purchase, restore and the `Transaction.updates` listener and calls
/// `refresh()`; `FeatureGate` reads `cachedLevel()` on every gate check.
actor EntitlementStore {
    private nonisolated let cache: EntitlementCache
    private nonisolated let now: @Sendable () -> Date
    private nonisolated let standing: @Sendable (String) async -> SubscriptionStanding

    init(
        cache: EntitlementCache = EntitlementCache(),
        now: @escaping @Sendable () -> Date = { Date.now },
        standing: @escaping @Sendable (String) async -> SubscriptionStanding = EntitlementStore.liveStanding
    ) {
        self.cache = cache
        self.now = now
        self.standing = standing
    }

    /// Reads the subscription group's status from StoreKit. Any network failure answers
    /// `.unknown`, which keeps the offline grace intact — an offline user is never
    /// downgraded on the strength of a question we could not ask.
    nonisolated static let liveStanding: @Sendable (String) async -> SubscriptionStanding = { productID in
        guard let product = try? await Product.products(for: [productID]).first,
              let subscription = product.subscription,
              let statuses = try? await subscription.status,
              !statuses.isEmpty
        else { return .unknown }

        for status in statuses {
            switch status.state {
            case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
                // Any live status in the group means the user is still entitled.
                return .retrying
            default:
                continue
            }
        }
        return .lapsed
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
            // Deliberately not filtered by `transaction.ownershipType`: DEC-013 makes annual
            // and lifetime Family Shareable, and a family member's entitlement arrives here
            // as `.familyShared`. Filtering to `.purchased` would silently break Family Sharing.
            guard ProProduct.allIdentifiers.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }

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
        // lapsed transaction before it can see the renewal. We therefore do not clear the cache
        // blindly; we ask StoreKit which of the two it is.
        let cached = cache.load()

        // Only subscriptions can lapse. A lifetime snapshot has no expiry, so it is never
        // put to this question — a non-consumable must not be revoked by a subscription status.
        if let cached,
           cached.level == .pro,
           cached.expirationDate != nil,
           let productID = cached.productID,
           await standing(productID) == .lapsed {
            cache.clear()
            return .free
        }

        // `.retrying` (Apple still billing) and `.unknown` (offline, unanswerable) both fall
        // through to EntitlementPolicy, which keeps Pro alive for `offlineGraceDays` past the
        // recorded expiry and then drops to free on its own.
        return EntitlementPolicy.resolve(cached, now: recordedAt)
    }
}
