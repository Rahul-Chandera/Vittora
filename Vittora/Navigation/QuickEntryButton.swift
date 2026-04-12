import SwiftUI

struct QuickEntryButton: View {
    @Environment(Router.self) private var router
    var action: () -> Void = {}

    var body: some View {
        Button(action: {
            action()
        }) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color("VPrimary"), in: Circle())
                .shadow(color: Color("VPrimary").opacity(0.3), radius: 8, y: 4)
        }
        .accessibilityLabel(String(localized: "Add Transaction"))
    }
}

#Preview {
    QuickEntryButton()
        .environment(Router())
}
