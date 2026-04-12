import SwiftUI

/// A reusable card styling modifier providing consistent card appearance across the app.
struct CardModifier: ViewModifier {
    let padding: CGFloat
    let cornerRadius: CGFloat
    let shadow: VSpacing.Shadow
    let backgroundColor: Color

    init(
        padding: CGFloat = VSpacing.cardPadding,
        cornerRadius: CGFloat = VSpacing.cornerRadiusCard,
        shadow: VSpacing.Shadow = .subtle,
        backgroundColor: Color = VColors.secondaryBackground
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.backgroundColor = backgroundColor
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(
                color: shadow.color.opacity(shadow.opacity),
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
    }
}

extension View {
    /// Apply card styling with customizable padding, corner radius, and shadow.
    func vCard(
        padding: CGFloat = VSpacing.cardPadding,
        cornerRadius: CGFloat = VSpacing.cornerRadiusCard,
        shadow: VSpacing.Shadow = .subtle,
        backgroundColor: Color = VColors.secondaryBackground
    ) -> some View {
        modifier(CardModifier(
            padding: padding,
            cornerRadius: cornerRadius,
            shadow: shadow,
            backgroundColor: backgroundColor
        ))
    }
}
