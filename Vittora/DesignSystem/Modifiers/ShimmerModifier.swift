import SwiftUI

/// A loading placeholder modifier with a subtle shimmer animation effect.
/// Ideal for skeleton loading states while data is being fetched.
struct ShimmerModifier: ViewModifier {
    @State private var isAnimating = false
    let isActive: Bool

    init(isActive: Bool = true) {
        self.isActive = isActive
    }

    func body(content: Content) -> some View {
        if isActive {
            content
                .redacted(reason: .placeholder)
                .overlay(
                    ShimmerView(isAnimating: $isAnimating)
                )
                .onAppear {
                    isAnimating = true
                }
        } else {
            content
        }
    }
}

// MARK: - ShimmerView
private struct ShimmerView: View {
    @Binding var isAnimating: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let gradientColor = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: .white, location: 0),
            .init(color: .white.opacity(0.5), location: 0.5),
            .init(color: .white, location: 1),
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(gradientColor)
                    .frame(width: geometry.size.width * 2)
                    .offset(x: isAnimating ? geometry.size.width : -geometry.size.width)
                    .animation(
                        reduceMotion ? .none : Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            .clipped()
        }
    }
}

extension View {
    /// Apply shimmer loading effect placeholder to the view.
    func shimmer(isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: VSpacing.lg) {
        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                Text("Loading Content")
                    .font(VTypography.title3)
                    .shimmer()
                    .frame(height: 24)

                Text("This is a placeholder that will shimmer while content loads.")
                    .font(VTypography.body)
                    .shimmer()
                    .frame(height: 60)
                    .lineLimit(3)
            }
        }

        VCard {
            VStack(alignment: .leading, spacing: VSpacing.md) {
                HStack(spacing: VSpacing.md) {
                    Circle()
                        .fill(VColors.secondaryBackground)
                        .frame(width: 44, height: 44)
                        .shimmer()

                    VStack(alignment: .leading, spacing: VSpacing.sm) {
                        Text("Transaction")
                            .font(VTypography.body)
                            .shimmer()
                            .frame(height: 18)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Amount")
                            .font(VTypography.caption1)
                            .shimmer()
                            .frame(height: 16)
                            .frame(maxWidth: 100, alignment: .leading)
                    }
                }
            }
        }

        Spacer()
    }
    .padding(VSpacing.screenPadding)
    .background(VColors.background)
}
