import Foundation
import VittoraCore

/// F0 launch-model flags. StoreKit, the paywall and every Pro gate are live as of 1.7.0.
enum MonetizationConfiguration {
    /// When `false`, conversion milestones are recorded for instrumentation only and every
    /// Pro surface stays unlocked. Kept as a kill switch: flipping it back disarms the
    /// paywall and every gate in one place.
    nonisolated static let isStoreKitEnabled = true

    /// Minimum days between paywall presentations when StoreKit is enabled.
    nonisolated static let paywallPresentationCooldownDays = 7
}
