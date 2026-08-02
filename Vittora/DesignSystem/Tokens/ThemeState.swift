import Foundation
import Observation
import VittoraCore

/// Observable mirror of the appearance settings that `VColors` reads.
///
/// `VColors` used to read `UserDefaults` directly from a static property. That
/// value is correct, but it sits outside SwiftUI's observation graph: changing
/// the accent persisted and re-rendered the Appearance screen's own preview,
/// while every other view kept its old colour until the app was relaunched.
/// From the outside that looks like "Apply did nothing".
///
/// Reading an `@Observable` property inside a view's body registers a
/// dependency, so routing the lookup through here makes every view that draws
/// `VColors.primary` update the moment the accent changes.
@Observable
final class ThemeState {
    static let shared = ThemeState()

    var accent: SettingsViewModel.AccentColor
    var isOLEDBlack: Bool

    private init() {
        accent = SettingsViewModel.AccentColor(
            rawValue: UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.accentColor) ?? ""
        ) ?? .brandGreen
        isOLEDBlack = UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.appearanceMode)
            == SettingsViewModel.AppearanceMode.oledBlack.rawValue
    }

    /// Re-reads persisted values. Call after anything writes the defaults
    /// directly — UI-test launch arguments do exactly that.
    func reloadFromDefaults() {
        accent = SettingsViewModel.AccentColor(
            rawValue: UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.accentColor) ?? ""
        ) ?? .brandGreen
        isOLEDBlack = UserDefaults.standard.string(forKey: AppUserDefaults.StandardKey.appearanceMode)
            == SettingsViewModel.AppearanceMode.oledBlack.rawValue
    }
}
