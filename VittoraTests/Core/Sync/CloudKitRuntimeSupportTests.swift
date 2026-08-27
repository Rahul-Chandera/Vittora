import Foundation
import Testing
import VittoraCore

/// Gating CloudKit on the iCloud entitlement.
///
/// `CKContainer.default()` raises an Objective-C exception when the running
/// binary has no iCloud container entitlement. Swift cannot catch that, so the
/// process aborts with SIGABRT before its first frame — the app does not show
/// an error, it dies. `make build-macos` passes `CODE_SIGNING_ALLOWED=NO`, so
/// the macOS artifact CI produces crashed on every launch: it compiled, and
/// could not be run.
///
/// This is a sync change, which the house rules require tests for. The decision
/// is tested through the injectable overload rather than the property, because
/// the property reads the *test binary's* entitlements and would assert on
/// whatever signing the test host happens to have.
@Suite("CloudKit runtime gating")
struct CloudKitRuntimeSupportTests {

    @Test("no entitlement means CloudKit stays off, so CKContainer is never touched")
    func unsignedBuildIsDisabled() {
        #expect(CloudKitRuntimeSupport.isEnabled(isSimulator: false, hasICloudEntitlement: false) == false)
    }

    @Test("a real device with the entitlement enables CloudKit")
    func signedDeviceIsEnabled() {
        #expect(CloudKitRuntimeSupport.isEnabled(isSimulator: false, hasICloudEntitlement: true) == true)
    }

    @Test("the simulator stays off even when the entitlement is present")
    func simulatorIsAlwaysDisabled() {
        // Pre-existing behaviour, pinned so the new entitlement check cannot
        // accidentally re-enable CloudKit in Simulator.
        #expect(CloudKitRuntimeSupport.isEnabled(isSimulator: true, hasICloudEntitlement: true) == false)
        #expect(CloudKitRuntimeSupport.isEnabled(isSimulator: true, hasICloudEntitlement: false) == false)
    }

    @Test("an unavailable build explains itself rather than failing silently")
    func unavailableMessageIsUserFacing() {
        #expect(!CloudKitRuntimeSupport.unavailableMessage.isEmpty)
    }

    @Test("iCloud sync is not gated behind a paid tier")
    func syncStaysFree() {
        // DEC-008. Pinned here because this enum is now the place where sync
        // availability is decided, and a tier check would be easy to add.
        #expect(CloudKitRuntimeSupport.isFreeBaselineFeature)
    }
}
