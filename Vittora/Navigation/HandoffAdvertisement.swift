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

    @ViewBuilder
    func body(content: Content) -> some View {
        // Avoid wrapping in Group — an extra container has made Dynamic Type /
        // clipping audits sample transitional layout on the transaction form.
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
