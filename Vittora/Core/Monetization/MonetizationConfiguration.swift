import Foundation

/// F0 launch-model flags. StoreKit and paywalls are deferred until post-PMF fast-follow.
enum MonetizationConfiguration {
    /// When `false`, conversion milestones are recorded for instrumentation only.
    static let isStoreKitEnabled = false

    /// Minimum days between paywall presentations when StoreKit is enabled.
    static let paywallPresentationCooldownDays = 7
}
