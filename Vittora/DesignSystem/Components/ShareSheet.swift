import SwiftUI

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

    var body: some View {
        if let url = items.first as? URL {
            VStack(spacing: VSpacing.lg) {
                Text(String(localized: "File ready to share"))
                    .font(VTypography.bodyBold)
                    .foregroundStyle(VColors.textPrimary)

                ShareLink(item: url) {
                    Label(String(localized: "Share File"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .tint(VColors.primary)
            }
            .padding(VSpacing.screenPadding)
        }
    }
}
#endif
