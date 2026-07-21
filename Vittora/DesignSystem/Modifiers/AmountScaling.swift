import SwiftUI

extension View {
    /// Keep a currency amount on a single line at standard sizes, shrinking to fit.
    /// At accessibility Dynamic Type sizes, allow wrapping instead of shrinking
    /// (prefer readable type over compressed glyphs).
    func amountScaling(_ minimumScale: CGFloat = 0.5) -> some View {
        self.adaptiveLineLimit(1).adaptiveMinimumScaleFactor(minimumScale)
    }
}
