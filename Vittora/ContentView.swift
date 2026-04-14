import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        if !appState.isOnboardingComplete {
            OnboardingView()
        } else {
            #if os(macOS)
            SidebarNavigation()
            #else
            if horizontalSizeClass == .regular {
                SidebarNavigation() // iPad
            } else {
                AppTabView()        // iPhone
            }
            #endif
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(Router())
}
