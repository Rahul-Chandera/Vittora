import SwiftUI

/// A styled search input with magnifying glass icon and clear button.
/// Supports placeholder text and focus state styling.
struct VSearchBar: View {
    @Binding var text: String
    let placeholder: String
    let onSearchChange: ((String) -> Void)?

    @FocusState private var isFocused: Bool

    init(
        text: Binding<String>,
        placeholder: String = "Search",
        onSearchChange: ((String) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSearchChange = onSearchChange
    }

    var body: some View {
        HStack(spacing: VSpacing.sm) {
            Image(systemName: VIcons.Actions.search)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(VColors.textTertiary)

            TextField(placeholder, text: $text)
                .font(VTypography.body)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled(true)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    onSearchChange?(newValue)
                }

            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onSearchChange?("")
                }) {
                    Image(systemName: VIcons.Actions.close)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(VColors.textSecondary)
                }
                .transition(.opacity)
            }
        }
        .padding(VSpacing.md)
        .background(VColors.tertiaryBackground)
        .cornerRadius(VSpacing.cornerRadiusMD)
        .overlay(
            RoundedRectangle(cornerRadius: VSpacing.cornerRadiusMD)
                .stroke(
                    VColors.primary.opacity(isFocused ? 0.5 : 0),
                    lineWidth: 2
                )
        )
    }
}

// MARK: - Preview
#Preview {
    @State var searchText = ""

    return VStack(spacing: VSpacing.lg) {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text("Default Search Bar")
                    .font(VTypography.title3)
                    .foregroundColor(VColors.textPrimary)

                VSearchBar(text: $searchText)
            }
        }

        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text("With Placeholder")
                    .font(VTypography.title3)
                    .foregroundColor(VColors.textPrimary)

                VSearchBar(
                    text: $searchText,
                    placeholder: "Find transaction..."
                )
            }
        }

        Spacer()
    }
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}
