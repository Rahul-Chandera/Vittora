import Foundation

/// Which watch screen to show at launch.
///
/// Exists for the App Store gallery script. `simctl` can screenshot a watch
/// simulator but cannot tap or open a URL on one, so without this the only
/// capturable screen is whatever the app happens to launch into — which is why
/// the watch gallery was three copies of the same dashboard.
///
/// Parsed from `--ui-test-watch-screen=<raw>`; absent or unrecognised means
/// `.dashboard`, so normal launches are unaffected.
enum WatchInitialScreen: String {
    case dashboard
    case quickExpense = "quick-expense"
    case recent
    case voice

    /// Text to pre-fill the voice screen with, standing in for dictation the
    /// simulator can't do: `--ui-test-watch-voice=500 for groceries`.
    static var voiceTextFromLaunchArguments: String {
        let prefix = "--ui-test-watch-voice="
        return ProcessInfo.processInfo.arguments.first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) } ?? ""
    }

    static var fromLaunchArguments: WatchInitialScreen {
        let prefix = "--ui-test-watch-screen="
        guard let raw = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }),
              let screen = WatchInitialScreen(rawValue: String(raw.dropFirst(prefix.count)))
        else { return .dashboard }
        return screen
    }
}
