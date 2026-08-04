import SwiftUI

/// Shared Form section header: primary label colour, no forced uppercase.
/// System `Section("…")` headers use secondaryLabel and fail WCAG AA on
/// grouped backgrounds at AccessibilityXL; headline + textPrimary keeps AA
/// across light / dark / OLED while matching the New Transaction pattern.
struct VFormSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(VColors.textPrimary)
            .textCase(nil)
            // Lets the accessibility audit recognise a section header without
            // matching on its text. These pin textPrimary, so their contrast is
            // ~18:1 by construction; XCTest still reports failures on them
            // because it samples the header's full-width row (background vs
            // background) rather than the glyphs.
            .accessibilityIdentifier("form-section-header")
    }
}
