import SwiftUI
import VittoraCore

extension View {
    /// Advertises a Handoff activity for the current screen (eligibleForSearch=false).
    func advertisesHandoff(
        _ route: HandoffDeepLink.Route?,
        isActive: Bool = true
    ) -> some View {
        modifier(HandoffAdvertisementModifier(route: route, isActive: isActive))
    }
}

private struct HandoffAdvertisementModifier: ViewModifier {
    let route: HandoffDeepLink.Route?
    let isActive: Bool
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        Group {
            if let route, appState.shouldAdvertiseHandoff(isActive: isActive) {
                content
                    .userActivity(AppHandoff.activityType(for: route), isActive: true) { activity in
                        AppHandoff.configure(activity, route: route)
                    }
            } else {
                content
            }
        }
    }
}
