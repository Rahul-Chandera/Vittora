import SwiftUI

struct DocumentThumbnailView: View {
    let entity: DocumentEntity
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                thumbnailContent
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: VSpacing.cornerRadiusMD))
                    .overlay(
                        RoundedRectangle(cornerRadius: VSpacing.cornerRadiusMD)
                            .stroke(VColors.textTertiary.opacity(0.3), lineWidth: 1)
                    )

                fileTypeBadge
                    .offset(x: 4, y: -4)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(String(localized: "Delete"), systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let thumbData = entity.thumbnailData,
           let image = platformImage(from: thumbData) {
            image
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                VColors.secondaryBackground
                Image(systemName: fileIcon)
                    .font(.system(size: 28))
                    .foregroundColor(VColors.textTertiary)
            }
        }
    }

    private var fileTypeBadge: some View {
        Text(fileExtension.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(badgeColor)
            .cornerRadius(4)
    }

    private var fileIcon: String {
        if entity.mimeType.hasPrefix("image/") { return "photo" }
        if entity.mimeType == "application/pdf" { return "doc.fill" }
        return "doc"
    }

    private var fileExtension: String {
        entity.fileName.components(separatedBy: ".").last ?? "?"
    }

    private var badgeColor: Color {
        if entity.mimeType.hasPrefix("image/") { return .blue }
        if entity.mimeType == "application/pdf" { return .red }
        return .gray
    }

    #if canImport(UIKit)
    private func platformImage(from data: Data) -> Image? {
        UIImage(data: data).map { Image(uiImage: $0) }
    }
    #elseif canImport(AppKit)
    private func platformImage(from data: Data) -> Image? {
        NSImage(data: data).map { Image(nsImage: $0) }
    }
    #else
    private func platformImage(from data: Data) -> Image? { nil }
    #endif
}

#Preview {
    DocumentThumbnailView(
        entity: DocumentEntity(fileName: "receipt.jpg", mimeType: "image/jpeg"),
        onTap: {},
        onDelete: {}
    )
    .padding()
}
