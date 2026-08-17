import Foundation
#if os(macOS)
import Security
#endif

public enum CloudKitRuntimeSupport {
    /// iCloud sync is a free baseline feature (DEC-008). Do not gate on subscription tier.
    public nonisolated static let isFreeBaselineFeature = true

    /// The decision itself, separated from how the inputs are discovered so it
    /// can be tested without depending on the test binary's own entitlements.
    public nonisolated static func isEnabled(
        isSimulator: Bool,
        hasICloudEntitlement: Bool
    ) -> Bool {
        if isSimulator { return false }
        return hasICloudEntitlement
    }

    public nonisolated static var isEnabled: Bool {
        #if targetEnvironment(simulator)
        isEnabled(isSimulator: true, hasICloudEntitlement: false)
        #else
        isEnabled(isSimulator: false, hasICloudEntitlement: processHasICloudEntitlement)
        #endif
    }

    /// Whether the running binary actually carries the iCloud container entitlement.
    ///
    /// This gate exists because `CKContainer.default()` does NOT fail gracefully
    /// without it: CloudKit raises an Objective-C exception, which Swift cannot
    /// catch, so the process aborts (SIGABRT) before the first frame.
    ///
    /// `make build-macos` passes `CODE_SIGNING_ALLOWED=NO`, so the macOS artifact
    /// CI builds has no entitlements at all and crashed on launch every time —
    /// the target compiled, and could not be run. Signed builds are unaffected,
    /// and so are shipped ones, which always carry the entitlement.
    ///
    /// Only checked on macOS: `SecTaskCopyValueForEntitlement` is macOS-only, and
    /// iOS builds are always signed, so the unsigned case cannot arise there.
    private nonisolated static let processHasICloudEntitlement: Bool = {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                  task,
                  "com.apple.developer.icloud-container-identifiers" as CFString,
                  nil
              )
        else { return false }
        return (value as? [String])?.isEmpty == false
        #else
        return true
        #endif
    }()

    public nonisolated static var unavailableMessage: String {
        #if targetEnvironment(simulator)
        String(localized: "iCloud sync isn't available in Simulator.")
        #else
        String(localized: "iCloud sync isn't available in this build.")
        #endif
    }
}
