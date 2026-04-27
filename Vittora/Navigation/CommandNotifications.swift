import Foundation

extension Notification.Name {
    /// Posted when the user invokes the “New Transaction” command (e.g. ⌘N on macOS).
    static let vittoraNewTransaction = Notification.Name("vittora.command.newTransaction")
    /// Posted to switch to the Settings tab (e.g. ⌘, on macOS).
    static let vittoraOpenSettings = Notification.Name("vittora.command.openSettings")
}
