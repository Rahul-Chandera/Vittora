import Foundation
import VittoraCore

/// Global app commands routed through `AppState` instead of `NotificationCenter`.
enum AppCommand: Equatable, Sendable {
    case presentNewTransaction
    case openSettings
}

struct AppCommandRequest: Equatable, Sendable {
    let command: AppCommand
    let id: UUID
}
