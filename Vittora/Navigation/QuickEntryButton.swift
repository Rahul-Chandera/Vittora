import SwiftUI
import VittoraCore

struct QuickEntryButton: View {
    var action: () -> Void = {}

    var body: some View {
        Button(action: {
            action()
        }) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(VColors.onPrimary)
                .frame(width: 56, height: 56)
                .background(VColors.primary, in: Circle())
                .shadow(color: VColors.primary.opacity(0.3), radius: 8, y: 4)
        }
        // .plain: the label is fully custom; without it macOS draws the
        // standard AppKit bezel behind the circle.
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Add Transaction"))
        .accessibilityIdentifier("quick-entry-floating-button")
    }
}

#Preview {
    QuickEntryButton()
}
