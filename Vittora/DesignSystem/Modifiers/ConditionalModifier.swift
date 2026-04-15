import SwiftUI

/// A generic conditional modifier that applies a transformation only when a condition is true.
/// Allows cleaner conditional modifier chains without if-else logic.
struct ConditionalModifier<Content: View>: View {
    let content: Content
    let condition: Bool
    let transform: (Content) -> AnyView

    init(
        _ content: Content,
        condition: Bool,
        transform: @escaping (Content) -> AnyView
    ) {
        self.content = content
        self.condition = condition
        self.transform = transform
    }

    var body: some View {
        if condition {
            transform(content)
        } else {
            AnyView(content)
        }
    }
}

extension View {
    /// Conditionally apply a modifier transformation.
    ///
    /// Example:
    /// ```
    /// Text("Hello")
    ///     .if(isSelected) { view in
    ///         AnyView(view.font(.bold))
    ///     }
    /// ```
    func `if`<T: View>(
        _ condition: Bool,
        transform: @escaping (Self) -> T
    ) -> some View {
        if condition {
            AnyView(transform(self))
        } else {
            AnyView(self)
        }
    }

    /// Conditionally apply a modifier with fallback.
    ///
    /// Example:
    /// ```
    /// Text("Hello")
    ///     .ifElse(isSelected,
    ///         if: { $0.foregroundColor(.blue) },
    ///         else: { $0.foregroundColor(.gray) }
    ///     )
    /// ```
    func ifElse<T: View>(
        _ condition: Bool,
        if trueTransform: @escaping (Self) -> T,
        else falseTransform: @escaping (Self) -> T
    ) -> some View {
        if condition {
            return AnyView(trueTransform(self))
        } else {
            return AnyView(falseTransform(self))
        }
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var isSelected = false
    @Previewable @State var isLoading = false

    return VStack(spacing: VSpacing.lg) {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text("Conditional Modifier Examples")
                    .font(VTypography.title3)
                    .foregroundColor(VColors.textPrimary)

                Text("Basic if() modifier")
                    .font(VTypography.caption1)
                    .foregroundColor(VColors.textSecondary)

                Toggle("Apply Bold", isOn: $isSelected)

                Text("This text responds to the toggle")
                    .font(VTypography.body)
                    .if(isSelected) { view in
                        AnyView(view.fontWeight(.bold).foregroundColor(VColors.primary))
                    }
                    .if(!isSelected) { view in
                        AnyView(view.foregroundColor(VColors.textSecondary))
                    }
            }
        }

        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text("ifElse() modifier")
                    .font(VTypography.title3)
                    .foregroundColor(VColors.textPrimary)

                Toggle("Show Loading", isOn: $isLoading)

                Text("Content changes based on state")
                    .font(VTypography.body)
                    .ifElse(isLoading,
                        if: { view in
                            AnyView(view
                                .redacted(reason: .placeholder)
                                .shimmer()
                            )
                        },
                        else: { view in
                            AnyView(view.foregroundColor(VColors.textPrimary))
                        }
                    )
            }
        }

        Spacer()
    }
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}
