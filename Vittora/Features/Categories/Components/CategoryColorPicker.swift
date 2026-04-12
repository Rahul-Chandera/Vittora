import SwiftUI

struct CategoryColorPicker: View {
    @Binding var selectedColorHex: String

    private let presetColors: [(name: String, hex: String)] = [
        ("Blue", "#007AFF"),
        ("Green", "#34C759"),
        ("Red", "#FF3B30"),
        ("Orange", "#FF9500"),
        ("Yellow", "#FFCC00"),
        ("Purple", "#AF52DE"),
        ("Pink", "#FF2D55"),
        ("Teal", "#5AC8FA"),
        ("Indigo", "#5856D6"),
        ("Mint", "#00C7BE"),
        ("Brown", "#A2845E"),
        ("Gray", "#8E8E93"),
        ("Coral", "#FF6B6B"),
        ("Lime", "#32CD32"),
        ("Navy", "#2C3E82"),
        ("Amber", "#FFBF00")
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: VSpacing.sm), count: 5)

    private func colorFor(_ hex: String) -> Color {
        Color(hex: hex) ?? .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            Text("Preset Colors")
                .font(VTypography.caption1)
                .foregroundColor(VColors.textSecondary)
                .padding(.horizontal, VSpacing.md)

            LazyVGrid(columns: columns, spacing: VSpacing.sm) {
                ForEach(presetColors, id: \.hex) { colorItem in
                    Button {
                        selectedColorHex = colorItem.hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(colorFor(colorItem.hex))
                                .frame(width: 44, height: 44)
                            if selectedColorHex == colorItem.hex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(colorItem.name)
                }
            }
            .padding(.horizontal, VSpacing.md)

            Divider()
                .padding(.vertical, VSpacing.xs)

            // Preview
            HStack(spacing: VSpacing.md) {
                ZStack {
                    Circle()
                        .fill(colorFor(selectedColorHex))
                        .opacity(0.15)
                        .frame(width: 48, height: 48)
                    Image(systemName: "tag.fill")
                        .font(.system(size: 20))
                        .foregroundColor(colorFor(selectedColorHex))
                }
                VStack(alignment: .leading) {
                    Text("Preview")
                        .font(VTypography.caption1)
                        .foregroundColor(VColors.textSecondary)
                    Text(selectedColorHex.uppercased())
                        .font(VTypography.bodyBold)
                        .foregroundColor(VColors.textPrimary)
                }
            }
            .padding(.horizontal, VSpacing.md)
        }
        .navigationTitle("Choose Color")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack {
        CategoryColorPicker(selectedColorHex: .constant("#007AFF"))
    }
}
