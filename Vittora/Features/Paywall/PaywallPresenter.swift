import Foundation
import SwiftUI

extension ConversionMilestone: Identifiable {
    nonisolated var id: String { rawValue }
}

/// Decides when a value-event milestone turns into a paywall.
///
/// The decision itself lives in `ConversionEventResult.shouldPresentPaywall`, which already
/// folds in the first-occurrence check, `MonetizationConfiguration.paywallPresentationCooldownDays`
/// and the `isStoreKitEnabled` kill switch. This type's whole job is to honour that answer and
/// then start the cooldown by telling the tracker the paywall was shown.
///
/// There is deliberately no manual entry point yet: the paywall only opens from a value
/// event. Before isStoreKitEnabled is flipped, Settings needs its own Vittora Pro row with
/// Restore Purchases, because App Review requires restore to be reachable without one of
/// these milestones firing first.
@MainActor
@Observable
final class PaywallPresenter {
    private let tracker: any ConversionEventTracking

    /// Non-nil while the paywall sheet is up. Settable only so `.sheet(item:)` can clear it
    /// on dismiss -- call `present(_:)` to show the paywall, never assign this directly.
    var milestone: ConversionMilestone?

    init(tracker: any ConversionEventTracking) { self.tracker = tracker }

    func present(_ result: ConversionEventResult?) {
        guard let result, result.shouldPresentPaywall else { return }
        milestone = result.milestone
        tracker.markPaywallPresented(for: result.milestone)
    }

    func dismiss() { milestone = nil }
}

private struct PaywallSheetModifier: ViewModifier {
    @Bindable var presenter: PaywallPresenter
    func body(content: Content) -> some View {
        content.sheet(item: $presenter.milestone) { milestone in
            PaywallView(milestone: milestone)
        }
    }
}

extension View {
    /// Hosts the single app-wide paywall sheet. Declared once, at the root.
    func paywallSheet(_ presenter: PaywallPresenter) -> some View {
        modifier(PaywallSheetModifier(presenter: presenter))
    }
}
