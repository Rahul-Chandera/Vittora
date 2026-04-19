import SwiftUI

// MARK: - Protocol

@MainActor
protocol HapticServiceProtocol {
    func light()
    func medium()
    func heavy()
    func success()
    func warning()
    func error()
    func selection()
}

// MARK: - Haptic Feedback Service

/// Centralized haptic feedback for consistent tactile responses across the app.
/// All methods are no-ops on macOS and on devices without haptic engines.
@MainActor
enum HapticService {

    // MARK: - Impact Feedback

    /// Light tap — tab selection, minor state changes.
    static func light() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    /// Medium tap — row selection, drag actions.
    static func medium() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }

    /// Heavy tap — destructive gesture, significant action.
    static func heavy() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        #endif
    }

    // MARK: - Notification Feedback

    /// Success outcome — save completed, sync done, goal achieved.
    static func success() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    /// Warning outcome — budget limit reached, low balance.
    static func warning() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }

    /// Error outcome — validation failed, network error.
    static func error() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
    }

    // MARK: - Selection Feedback

    /// Selection change — picker, segmented control, date change.
    static func selection() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
}

// MARK: - Live Implementation

@MainActor
final class LiveHapticService: HapticServiceProtocol {
    func light()     { HapticService.light() }
    func medium()    { HapticService.medium() }
    func heavy()     { HapticService.heavy() }
    func success()   { HapticService.success() }
    func warning()   { HapticService.warning() }
    func error()     { HapticService.error() }
    func selection() { HapticService.selection() }
}

// MARK: - View Extension

extension View {
    /// Trigger haptic impact feedback when a value changes.
    func hapticFeedback<T: Equatable>(_ style: HapticStyle, trigger: T) -> some View {
        self.onChange(of: trigger) { _, _ in
            Task { @MainActor in style.fire() }
        }
    }
}

// MARK: - Haptic Style

enum HapticStyle {
    case light, medium, heavy, success, warning, error, selection

    @MainActor
    func fire() {
        switch self {
        case .light:     HapticService.light()
        case .medium:    HapticService.medium()
        case .heavy:     HapticService.heavy()
        case .success:   HapticService.success()
        case .warning:   HapticService.warning()
        case .error:     HapticService.error()
        case .selection: HapticService.selection()
        }
    }
}
