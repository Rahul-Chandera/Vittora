import SwiftUI

// MARK: - Adaptive line limit

private struct AdaptiveLineLimitModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var typeSize
    let limit: Int

    func body(content: Content) -> some View {
        content.lineLimit(typeSize.isAccessibilitySize ? nil : limit)
    }
}

private struct AdaptiveMinimumScaleFactorModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var typeSize
    let factor: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if typeSize.isAccessibilitySize {
            content
        } else {
            content.minimumScaleFactor(factor)
        }
    }
}

extension View {
    /// Applies `lineLimit` only when the user is not using an accessibility Dynamic Type size.
    /// At accessibility sizes the limit is removed so text can wrap rather than truncate.
    func adaptiveLineLimit(_ limit: Int) -> some View {
        self.modifier(AdaptiveLineLimitModifier(limit: limit))
    }

    /// Applies text scaling only outside accessibility Dynamic Type sizes.
    /// Accessibility sizes should wrap at their requested size instead of shrinking.
    func adaptiveMinimumScaleFactor(_ factor: CGFloat) -> some View {
        self.modifier(AdaptiveMinimumScaleFactorModifier(factor: factor))
    }
}
