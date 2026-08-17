import SwiftUI

/// A field label carrying the required marker.
///
/// The asterisk is appended in the view rather than baked into the localized
/// string. `RecurringFormView` had `String(localized: "Account *")`, which
/// forces a separate catalogue entry — and a separate translation — for every
/// required field, all differing from the optional version by one character.
///
/// The marker is `accessibilityHidden`; VoiceOver gets "required" through the
/// label instead, so it is announced as a word rather than read as punctuation.
struct VRequiredFieldLabel: View {
    let title: String
    var isRequired: Bool = true

    init(_ title: String, isRequired: Bool = true) {
        self.title = title
        self.isRequired = isRequired
    }

    var body: some View {
        // One Text node via concatenation — see VFormSectionHeader for why an
        // HStack here breaks the audit's identifier-based exemption.
        (isRequired
            ? Text(title) + Text(verbatim: " *").foregroundColor(VColors.expense)
            : Text(title))
        .accessibilityLabel(
            isRequired
                ? String(localized: "\(title), required")
                : title
        )
    }
}

#Preview {
    Form {
        Section {
            VRequiredFieldLabel("Amount")
            VRequiredFieldLabel("Note", isRequired: false)
        }
    }
}
