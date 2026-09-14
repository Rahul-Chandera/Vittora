import Foundation
import VittoraCore

// The app target builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so these types are
// declared `nonisolated` — entitlement resolution runs from `EntitlementStore`'s actor and from
// gate checks on any thread, never only from the main actor.

nonisolated enum EntitlementLevel: String, Sendable, Codable, Equatable {
    case free
    case pro
}

/// Last entitlement StoreKit reported, persisted so a cold offline launch still knows
/// whether the user is Pro. Contains no purchase token or receipt — identifiers and
/// dates only.
nonisolated struct EntitlementSnapshot: Codable, Sendable, Equatable {
    let level: EntitlementLevel
    /// nil when `level == .free`.
    let productID: String?
    /// nil means the entitlement never expires (lifetime), or the snapshot is a free one.
    let expirationDate: Date?
    /// StoreKit reported the subscription as in billing retry / grace period.
    let isInBillingRetry: Bool
    let recordedAt: Date
}

/// Pure resolution of a cached snapshot into today's access level.
///
/// PROPOSED POLICY — the plan defines no behaviour for a cold offline launch, a device offline
/// across a renewal boundary, or `.inGracePeriod`. This is the proposal, not a signed-off
/// decision; the whole policy is the one constant below plus `resolve`.
nonisolated enum EntitlementPolicy {
    /// Days a cached Pro entitlement stays honoured past its expiry.
    ///
    /// Matches Apple's own 16-day billing grace period for monthly-and-longer subscriptions —
    /// the plan (§8, "App Store Economics") already commits to enabling Grace Period and
    /// Billing Retry, so this makes the offline behaviour agree with the server-side setting.
    /// An offline user whose renewal is succeeding is never wrongly downgraded.
    static let offlineGraceDays = 16

    static func resolve(_ snapshot: EntitlementSnapshot?, now: Date) -> EntitlementLevel {
        guard let snapshot, snapshot.level == .pro else { return .free }
        guard let expirationDate = snapshot.expirationDate else { return .pro }
        let graceEnd = expirationDate.addingTimeInterval(TimeInterval(offlineGraceDays * 86_400))
        return now < graceEnd ? .pro : .free
    }
}

/// Stores the snapshot in the isolated conversion defaults suite (`AppUserDefaults.conversion`),
/// which already holds this app's monetization state and is kept out of broad backups (SEC-08).
nonisolated struct EntitlementCache: Sendable {
    private static let key = "vittora.entitlement.snapshot"

    private nonisolated(unsafe) let defaults: UserDefaults

    init(defaults: UserDefaults = AppUserDefaults.conversion) {
        self.defaults = defaults
    }

    func load() -> EntitlementSnapshot? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(EntitlementSnapshot.self, from: data)
    }

    func save(_ snapshot: EntitlementSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
