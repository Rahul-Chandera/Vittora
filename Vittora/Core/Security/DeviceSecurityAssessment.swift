import Foundation

/// Informational assessment only (SEC-17). Do not block users — Apple discourages hard blocks.
enum DeviceSecurityAssessment: Sendable {
    /// Heuristic signals that may indicate a jailbroken or modified environment.
    static var isLikelyCompromisedEnvironment: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let suspiciousPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/private/var/tmp/cydia.log"
        ]
        for path in suspiciousPaths where FileManager.default.fileExists(atPath: path) {
            return true
        }
        return false
        #endif
    }
}
