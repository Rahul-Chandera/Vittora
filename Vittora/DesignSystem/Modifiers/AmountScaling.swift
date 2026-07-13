import SwiftUI

extension View {
    /// Keep a currency amount on a single line, shrinking to fit its container
    /// instead of wrapping. Large values (e.g. ₹3,11,000) otherwise wrap and
    /// break the height alignment of side-by-side summary cards.
    func amountScaling(_ minimumScale: CGFloat = 0.5) -> some View {
        self.lineLimit(1).minimumScaleFactor(minimumScale)
    }
}
