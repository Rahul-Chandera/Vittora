import SwiftUI

struct PlaceholderView: View {
    let tab: AppState.AppTab

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(tab.title)
                .font(.title)
                .fontWeight(.bold)

            Text(String(localized: "Coming soon"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(tab.title)
    }
}
