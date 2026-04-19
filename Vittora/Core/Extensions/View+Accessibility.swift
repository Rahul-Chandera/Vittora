import SwiftUI

// MARK: - Adaptive line limit

private struct AdaptiveLineLimitModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var typeSize
    let limit: Int

    func body(content: Content) -> some View {
        content.lineLimit(typeSize.isAccessibilitySize ? nil : limit)
    }
}

extension View {
    /// Applies `lineLimit` only when the user is not using an accessibility Dynamic Type size.
    /// At accessibility sizes the limit is removed so text can wrap rather than truncate.
    func adaptiveLineLimit(_ limit: Int) -> some View {
        self.modifier(AdaptiveLineLimitModifier(limit: limit))
    }
}
