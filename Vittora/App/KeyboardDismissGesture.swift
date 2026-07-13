#if os(iOS)
import UIKit

/// Installs a window-level tap recognizer that dismisses the keyboard when the
/// user taps outside a text input. One global gesture covers every screen —
/// pushed, sheet-presented, and number-pad fields that have no return key —
/// without adding per-form keyboard toolbars.
@MainActor
enum KeyboardDismissGesture {
    private static let recognizerName = "vittora.keyboard-dismiss"

    static func installIfNeeded() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        // At onAppear the window may not be key yet — fall back to the first one.
        guard
            let window = windows.first(where: \.isKeyWindow) ?? windows.first,
            window.gestureRecognizers?.contains(where: { $0.name == recognizerName }) != true
        else { return }

        let tap = UITapGestureRecognizer(
            target: Handler.shared,
            action: #selector(Handler.handleTap)
        )
        tap.name = recognizerName
        tap.cancelsTouchesInView = false
        tap.delegate = Handler.shared
        window.addGestureRecognizer(tap)
    }

    private final class Handler: NSObject, UIGestureRecognizerDelegate {
        static let shared = Handler()

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            recognizer.view?.endEditing(false)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            // Don't dismiss when the tap is on a text input itself, or focus
            // would flicker when moving between fields.
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }
    }
}
#endif
