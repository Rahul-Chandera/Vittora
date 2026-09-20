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

    /// The marker is a styled run rather than a second Text: Text's `+` is
    /// deprecated, and string interpolation would invent a catalogue key.
    static func attributedTitle(_ title: String, isRequired: Bool) -> AttributedString {
        var result = AttributedString(title)
        guard isRequired else { return result }
        var marker = AttributedString(" *")
        marker.foregroundColor = VColors.expense
        result.append(marker)
        return result
    }

    var body: some View {
        // One AttributedString, NOT an HStack and no longer Text + Text (the
        // operator is deprecated in iOS 26). This must stay a single Text node:
        // the audit exemption keys on the identifier below, and wrapping it in
        // a stack made the sampler flag the inner Text instead, which carries
        // no identifier — testSavingsSurfaces and testTaxSurfaces both failed
        // on "Goal" and "Country" that way.
        Text(Self.attributedTitle(title, isRequired: isRequired))
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
