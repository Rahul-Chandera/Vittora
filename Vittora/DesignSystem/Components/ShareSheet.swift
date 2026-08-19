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
