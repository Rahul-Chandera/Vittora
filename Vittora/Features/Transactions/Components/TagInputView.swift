import SwiftUI

struct TagInputView: View {
    @Binding var tags: [String]
    @Binding var tagInput: String
    var onAddTag: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VSpacing.sm) {
            // Existing tags
            if !tags.isEmpty {
                FlowLayout(spacing: VSpacing.xs) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: VSpacing.xs) {
                            Text(tag)
                                .font(VTypography.caption1)
                                .foregroundColor(VColors.primary)

                            Button {
                                var updated = tags
                                updated.removeAll { $0 == tag }
                                tags = updated
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                                    .foregroundColor(VColors.textSecondary)
                            }
                        }
                        .padding(.horizontal, VSpacing.sm)
                        .padding(.vertical, VSpacing.xs)
                        .background(VColors.primary.opacity(0.1))
                        .cornerRadius(VSpacing.cornerRadiusSM)
                    }
                }
                .padding(.bottom, VSpacing.sm)
            }

            // Input field
            HStack {
                TextField(String(localized: "Add tag (press return)"), text: $tagInput)
                    .font(VTypography.body)
                    .foregroundColor(VColors.textPrimary)
                    .onSubmit {
                        onAddTag()
                    }

                if !tagInput.isEmpty {
                    Button {
                        onAddTag()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(VColors.primary)
                    }
                }
            }
            .padding(VSpacing.sm)
            .background(VColors.tertiaryBackground)
            .cornerRadius(VSpacing.cornerRadiusSM)
            .overlay(
                RoundedRectangle(cornerRadius: VSpacing.cornerRadiusSM)
                    .stroke(VColors.textTertiary.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var currentWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentWidth + size.width > maxWidth {
                height += lineHeight + spacing
                currentWidth = size.width
                lineHeight = size.height
            } else {
                currentWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
        }

        height += lineHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && x != bounds.minX {
                y += lineHeight + spacing
                x = bounds.minX
                lineHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    VStack {
        TagInputView(
            tags: .constant(["urgent", "work", "important"]),
            tagInput: .constant(""),
            onAddTag: {}
        )

        TagInputView(
            tags: .constant([]),
            tagInput: .constant(""),
            onAddTag: {}
        )
    }
    .padding(VSpacing.lg)
    .background(VColors.background)
}
