import Foundation
import VittoraCore

/// F0 launch-model flags. StoreKit and paywalls are deferred until post-PMF fast-follow.
enum MonetizationConfiguration {
    /// When `false`, conversion milestones are recorded for instrumentation only.
    nonisolated static let isStoreKitEnabled = false

    /// Minimum days between paywall presentations when StoreKit is enabled.
    nonisolated static let paywallPresentationCooldownDays = 7
}
