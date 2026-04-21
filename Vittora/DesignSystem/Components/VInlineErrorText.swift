import SwiftUI

/// Inline validation/error text that is announced as one VoiceOver element.
struct VInlineErrorText: View {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        HStack(alignment: .top, spacing: VSpacing.xs) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(VTypography.caption1)
                .accessibilityHidden(true)

            Text(message)
                .font(VTypography.caption1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(VColors.expense)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Validation error"))
        .accessibilityValue(message)
    }
}
