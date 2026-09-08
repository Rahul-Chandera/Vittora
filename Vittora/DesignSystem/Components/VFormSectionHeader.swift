import SwiftUI

/// Shared Form section header: primary label colour, no forced uppercase.
/// System `Section("…")` headers use secondaryLabel and fail WCAG AA on
/// grouped backgrounds at AccessibilityXL; headline + textPrimary keeps AA
/// across light / dark / OLED while matching the New Transaction pattern.
struct VFormSectionHeader: View {
    let title: String
    /// Appends the required marker. The asterisk is added here rather than
    /// baked into the localized string — `String(localized: "Account *")` needs
    /// a separate catalogue entry and translation for every required field.
    var isRequired: Bool = false

    init(_ title: String, isRequired: Bool = false) {
        self.title = title
        self.isRequired = isRequired
    }

    var body: some View {
        // Text + Text concatenation, NOT an HStack. This must stay a single
        // Text node: the audit exemption keys on the identifier below, and
        // wrapping it in a stack made the sampler flag the inner Text instead,
        // which carries no identifier — testSavingsSurfaces and testTaxSurfaces
        // both failed on "Goal" and "Country" that way.
        (isRequired
            ? Text(title) + Text(verbatim: " *").foregroundColor(VColors.expense)
            : Text(title))
            .font(.headline)
            .foregroundStyle(VColors.textPrimary)
            .textCase(nil)
            .accessibilityLabel(isRequired ? String(localized: "\(title), required") : title)
            // Lets the accessibility audit recognise a section header without
            // matching on its text. These pin textPrimary, so their contrast is
            // ~18:1 by construction; XCTest still reports failures on them
            // because it samples the header's full-width row (background vs
            // background) rather than the glyphs.
            .accessibilityIdentifier("form-section-header")
    }
}
