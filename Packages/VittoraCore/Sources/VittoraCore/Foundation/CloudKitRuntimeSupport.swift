import Foundation

public enum CloudKitRuntimeSupport {
    /// iCloud sync is a free baseline feature (DEC-008). Do not gate on subscription tier.
    public nonisolated static let isFreeBaselineFeature = true

    public nonisolated static var isEnabled: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    public nonisolated static var unavailableMessage: String {
        #if targetEnvironment(simulator)
        String(localized: "iCloud sync isn't available in Simulator.")
        #else
        String(localized: "iCloud sync isn't available in this build.")
        #endif
    }
}
