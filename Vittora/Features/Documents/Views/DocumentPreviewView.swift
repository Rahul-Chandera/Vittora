import SwiftUI
import QuickLook

struct DocumentPreviewView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            QLPreviewControllerRepresentable(url: url)
                .ignoresSafeArea()
                .navigationTitle(url.lastPathComponent)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Done")) {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Platform QuickLook wrapper

#if os(iOS)
import UIKit

struct QLPreviewControllerRepresentable: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            url as NSURL
        }
    }
}
#else
import AppKit

struct QLPreviewControllerRepresentable: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif

#Preview {
    DocumentPreviewView(url: URL(fileURLWithPath: "/tmp/receipt.pdf"))
}
