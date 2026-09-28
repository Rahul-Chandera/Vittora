import CloudKit
import SwiftUI

/// Receives household invitations (M3.4.1).
///
/// Tapping a CloudKit share link opens the app with the share's metadata, and
/// the only way to receive it is a platform delegate — SwiftUI has no modifier
/// for it. On iOS it arrives at the SCENE delegate, not the app delegate, once
/// the app uses scenes; a cold launch from the link delivers it in the
/// connection options instead of the callback, so both are handled.
#if os(iOS)
final class VittoraAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = VittoraSceneDelegate.self
        return configuration
    }
}

final class VittoraSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            Task { await HouseholdStore.shared.accept(metadata) }
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { await HouseholdStore.shared.accept(cloudKitShareMetadata) }
    }
}
#elseif os(macOS)
final class VittoraAppDelegate: NSObject, NSApplicationDelegate {
    func application(
        _ application: NSApplication,
        userDidAcceptCloudKitShareWith metadata: CKShare.Metadata
    ) {
        Task { await HouseholdStore.shared.accept(metadata) }
    }
}
#endif
