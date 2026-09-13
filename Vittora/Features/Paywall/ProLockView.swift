import SwiftUI

/// The one locked-surface screen. Every Pro gate renders this, so the upgrade route is
/// written once instead of per feature -- a lock screen whose button does nothing is
/// worse than no lock at all.
struct ProLockView: View {
    let title: String
    let message: String
    @State private var showPaywall = false

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "lock.fill")
        } description: {
            Text(message)
        } actions: {
            Button(String(localized: "See Vittora Pro")) { showPaywall = true }
                .buttonStyle(.borderedProminent)
                // AA-safe brand green: white on primaryOnSurface (#17604A) is 7.5:1,
                // white on primary (#3FCFA4) is 1.97:1 and would need a DEC-012 exemption.
                .tint(VColors.primaryOnSurface)
                .accessibilityIdentifier("pro-lock-upgrade-button")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VColors.groupedBackground)
        // Presented locally rather than through PaywallPresenter: an explicit upgrade tap
        // must always open the paywall, and must not consume the value-event cooldown.
        .sheet(isPresented: $showPaywall) { PaywallView(milestone: nil) }
    }
}

private struct ProGateModifier: ViewModifier {
    let requiresPro: Bool
    let title: String
    let message: String
    @Environment(\.dependencies) private var dependencies

    /// FeatureGate owns the decision (offline grace, kill switch). `purchaseService.level`
    /// is read as well so @Observable re-evaluates this gate the moment a purchase or
    /// restore lands -- FeatureGate is a plain struct and publishes nothing itself.
    private var isUnlocked: Bool {
        _ = dependencies.purchaseService.level
        return dependencies.featureGate.isProUnlocked
    }

    func body(content: Content) -> some View {
        if requiresPro && !isUnlocked {
            ProLockView(title: title, message: message)
        } else {
            content
        }
    }
}

extension View {
    /// Replaces this view with `ProLockView` when `requiresPro` and the user is not Pro.
    func proGated(_ requiresPro: Bool, title: String, message: String) -> some View {
        modifier(ProGateModifier(requiresPro: requiresPro, title: title, message: message))
    }
}
