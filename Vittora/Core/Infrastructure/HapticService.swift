import SwiftUI

// MARK: - Haptic Feedback Service

/// Centralized haptic feedback for consistent tactile responses across the app.
/// All methods are no-ops on macOS and on devices without haptic engines.
@MainActor
final class HapticService {

    // MARK: - Singleton

    static let shared = HapticService()
    private init() {}

    // MARK: - Impact Feedback

    /// Light tap — tab selection, minor state changes.
    func light() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    /// Medium tap — row selection, drag actions.
    func medium() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }

    /// Heavy tap — destructive gesture, significant action.
    func heavy() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        #endif
    }

    // MARK: - Notification Feedback

    /// Success outcome — save completed, sync done, goal achieved.
    func success() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    /// Warning outcome — budget limit reached, low balance.
    func warning() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }

    /// Error outcome — validation failed, network error.
    func error() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
    }

    // MARK: - Selection Feedback

    /// Selection change — picker, segmented control, date change.
    func selection() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
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
        case .light:     HapticService.shared.light()
        case .medium:    HapticService.shared.medium()
        case .heavy:     HapticService.shared.heavy()
        case .success:   HapticService.shared.success()
        case .warning:   HapticService.shared.warning()
        case .error:     HapticService.shared.error()
        case .selection: HapticService.shared.selection()
        }
    }
}
