import SwiftUI

@Observable
@MainActor
final class Router {
    var path = NavigationPath()

    func navigate(to destination: NavigationDestination) {
        path.append(destination)
    }

    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func goToRoot() {
        path = NavigationPath()
    }
}
