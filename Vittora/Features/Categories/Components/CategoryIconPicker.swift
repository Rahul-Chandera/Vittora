import SwiftUI

struct CategoryIconPicker: View {
    @Binding var selectedIcon: String
    var selectedColor: Color = VColors.primary

    private let icons: [String] = [
        // Food & Shopping
        "fork.knife", "cart.fill", "bag.fill", "takeoutbag.and.cup.and.straw.fill",
        // Transport
        "car.fill", "bus.fill", "airplane", "tram.fill", "bicycle",
        // Housing
        "house.fill", "bolt.fill", "drop.fill", "flame.fill",
        // Health
        "heart.fill", "cross.case.fill", "figure.walk", "pills.fill",
        // Entertainment
        "film.fill", "music.note", "gamecontroller.fill", "tv.fill",
        // Finance
        "dollarsign.circle.fill", "creditcard.fill", "chart.line.uptrend.xyaxis", "banknote.fill",
        // Education
        "book.fill", "graduationcap.fill", "pencil", "desktopcomputer",
        // Personal
        "person.fill", "gift.fill", "scissors", "paintbrush.fill",
        // Communication
        "phone.fill", "wifi", "envelope.fill",
        // Other
        "star.fill", "tag.fill", "ellipsis.circle.fill", "questionmark.circle.fill"
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: VSpacing.sm), count: 6)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: VSpacing.sm) {
                ForEach(icons, id: \.self) { icon in
                    Button {
                        selectedIcon = icon
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedIcon == icon ? selectedColor : VColors.tertiaryBackground)
                                .frame(width: 48, height: 48)
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .foregroundColor(selectedIcon == icon ? .white : VColors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(VSpacing.md)
        }
        .navigationTitle("Choose Icon")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack {
        CategoryIconPicker(selectedIcon: .constant("fork.knife"))
    }
}
