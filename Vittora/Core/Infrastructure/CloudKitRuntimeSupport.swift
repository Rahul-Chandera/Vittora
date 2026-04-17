import Foundation

enum CloudKitRuntimeSupport {
    static var isEnabled: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    static var unavailableMessage: String {
        #if targetEnvironment(simulator)
        String(localized: "iCloud sync isn't available in Simulator.")
        #else
        String(localized: "iCloud sync isn't available in this build.")
        #endif
    }
}
