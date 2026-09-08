import SwiftUI

/// Switch that keeps the brand colour on its ON state.
///
/// Toggles were rendering black. Eighteen forms and lists set a container
/// `.tint(VColors.textPrimary)` or `.tint(.primary)` — deliberately, to stop
/// navigation chevrons and picker values inheriting the accent — and `Toggle`
/// inherited that same tint for its switch.
///
/// A ToggleStyle is the right lever rather than 32 per-call-site `.tint`
/// modifiers: styles propagate through the environment and are *not* overridden
/// by an ancestor `.tint`, so declaring this once at the app root covers every
/// switch while leaving those container tints doing their job. The `.tint` here
/// sits inside the style, closer to the switch than any ancestor, so it wins.
struct VSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(configuration)
            .toggleStyle(.switch)
            .tint(VColors.primary)
    }
}

extension View {
    /// Apply once near the app root; every descendant `Toggle` picks it up.
    func vittoraSwitchTint() -> some View {
        toggleStyle(VSwitchToggleStyle())
    }
}
