import Foundation

/// Single entry point for "may this user use a Pro surface right now?".
///
/// Every gate call site routes through `FeatureGate` so the 16-day offline grace inside
/// `EntitlementPolicy.resolve` (DEC-014) is applied once rather than re-implemented per screen.
/// OCR remains a free-tier quota (DEC-014), not a binary lock. DEC-015 is the tax-feature
/// split (profile form and CSV export stay free; computed tax outputs are gated).
///
/// The `storeKitEnabled` short-circuit keeps the gate dormant while
/// `MonetizationConfiguration.isStoreKitEnabled` is false — nothing is gated until monetization
/// is switched on.
nonisolated struct FeatureGate: Sendable {
    private let levelProvider: @Sendable () -> EntitlementLevel
    private let ocrScansUsedThisMonth: @Sendable () -> Int
    private let storeKitEnabled: Bool

    init(
        levelProvider: @escaping @Sendable () -> EntitlementLevel,
        ocrScansUsedThisMonth: @escaping @Sendable () -> Int,
        storeKitEnabled: Bool = MonetizationConfiguration.isStoreKitEnabled
    ) {
        self.levelProvider = levelProvider
        self.ocrScansUsedThisMonth = ocrScansUsedThisMonth
        self.storeKitEnabled = storeKitEnabled
    }

    init(
        store: EntitlementStore,
        tracker: any ConversionEventTracking,
        storeKitEnabled: Bool = MonetizationConfiguration.isStoreKitEnabled
    ) {
        self.init(
            levelProvider: { store.cachedLevel() },
            ocrScansUsedThisMonth: { tracker.ocrScansThisMonth() },
            storeKitEnabled: storeKitEnabled
        )
    }

    /// True when every Pro surface is available.
    var isProUnlocked: Bool {
        if !storeKitEnabled { return true }
        return levelProvider() == .pro
    }

    /// Receipt OCR is a quota, not a binary lock: free users keep
    /// `FreeTierLimits.maxOCRScansPerMonth` scans per month.
    var canScanReceipt: Bool {
        if isProUnlocked { return true }
        return ocrScansUsedThisMonth() < FreeTierLimits.maxOCRScansPerMonth
    }
}
