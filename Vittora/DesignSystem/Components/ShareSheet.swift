import SwiftUI
import VittoraCore

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
#else
/// Presents the macOS share menu directly, with no dialog in front of it.
///
/// The old flow put a sheet up first whose only control was a "Share File"
/// button — one extra click to reach a menu that was going to open anyway.
/// `NSSharingServicePicker` is what that button was wrapping, so this shows it
/// straight away.
///
/// `onFinish` matters as much as the presentation. The callers delete the
/// temporary export the moment their sheet dismisses, so the file has to
/// outlive the picker: the completion fires when a service is chosen OR when
/// the picker is dismissed without choosing, and only then is it safe to
/// clean up.
@MainActor
enum MacSharePresenter {
    /// Kept alive for the lifetime of the picker; AppKit holds the delegate
    /// weakly and it would otherwise deallocate before anything is chosen.
    private static var activeDelegate: PickerDelegate?

    /// Returns false when there is no window to anchor to, so the caller can
    /// fall back rather than silently doing nothing.
    @discardableResult
    static func present(items: [Any], onFinish: @escaping () -> Void) -> Bool {
        guard let anchor = NSApp.keyWindow?.contentView ?? NSApp.windows.first(where: \.isVisible)?.contentView else {
            return false
        }

        let picker = NSSharingServicePicker(items: items)
        let delegate = PickerDelegate {
            activeDelegate = nil
            onFinish()
        }
        activeDelegate = delegate
        picker.delegate = delegate

        let rect = NSRect(x: anchor.bounds.midX, y: anchor.bounds.midY, width: 1, height: 1)
        picker.show(relativeTo: rect, of: anchor, preferredEdge: .minY)
        return true
    }

    private final class PickerDelegate: NSObject, NSSharingServicePickerDelegate {
        private let onFinish: () -> Void
        private var finished = false

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func sharingServicePicker(
            _ picker: NSSharingServicePicker,
            didChoose service: NSSharingService?
        ) {
            // Fires with nil when the menu is dismissed without choosing, which
            // is just as much "done with the file" as picking a service.
            guard !finished else { return }
            finished = true
            onFinish()
        }
    }
}

struct ShareSheet: View {
    let items: [Any]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let url = items.first as? URL {
            shareBody(label: String(localized: "File ready to share")) {
                ShareLink(item: url) {
                    Label(String(localized: "Share File"), systemImage: "square.and.arrow.up")
                }
            }
        } else if let text = items.first as? String {
            // Text as well as URLs: the debt reminder shares a drafted message,
            // and without this branch macOS showed an empty sheet.
            shareBody(label: String(localized: "Message ready to share")) {
                ShareLink(item: text) {
                    Label(String(localized: "Share Message"), systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    @ViewBuilder
    private func shareBody(label: String, @ViewBuilder link: () -> some View) -> some View {
        VStack(spacing: VSpacing.lg) {
            Text(label)
                .font(VTypography.bodyBold)
                .foregroundStyle(VColors.textPrimary)

            link()
                .buttonStyle(.borderedProminent)
                .tint(VColors.primary)

            // Without this the sheet is a dead end. macOS gives a SwiftUI
            // sheet no close affordance of its own, and this one had no
            // cancel action for Escape to run either — so exporting data
            // trapped the window until the file was actually shared. The
            // iOS branch is a UIActivityViewController, which brings its own.
            Button(String(localized: "Cancel")) { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(VColors.textSecondary)
                .keyboardShortcut(.cancelAction)
        }
        .padding(VSpacing.screenPadding)
    }
}
#endif
