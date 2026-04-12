import SwiftUI

enum VSpacing {
    // MARK: - Base Spacing Scale
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 40

    // MARK: - Semantic Spacings
    static let cardPadding: CGFloat = 16
    static let listRowSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 24
    static let screenPadding: CGFloat = 16
    static let groupedScreenPadding: CGFloat = 20

    // MARK: - Corner Radii
    static let cornerRadiusXS: CGFloat = 4
    static let cornerRadiusSM: CGFloat = 8
    static let cornerRadiusMD: CGFloat = 12
    static let cornerRadiusLG: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 20
    static let cornerRadiusCard: CGFloat = 12
    static let cornerRadiusPill: CGFloat = 999 // For fully rounded pill shapes

    // MARK: - Shadow Specifications
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        let opacity: Double

        static let subtle = Shadow(
            color: .black,
            radius: 2,
            x: 0,
            y: 1,
            opacity: 0.08
        )

        static let medium = Shadow(
            color: .black,
            radius: 8,
            x: 0,
            y: 2,
            opacity: 0.12
        )

        static let elevated = Shadow(
            color: .black,
            radius: 12,
            x: 0,
            y: 4,
            opacity: 0.15
        )
    }

    // MARK: - Animation Durations
    static let animationQuick: CGFloat = 0.15
    static let animationStandard: CGFloat = 0.3
    static let animationSlow: CGFloat = 0.5

    // MARK: - Stroke Widths
    static let strokeThin: CGFloat = 0.5
    static let strokeNormal: CGFloat = 1.0
    static let strokeMedium: CGFloat = 1.5
    static let strokeThick: CGFloat = 2.0
}

// MARK: - Commonly Used Edge Insets
extension EdgeInsets {
    static let screenPadding = EdgeInsets(
        top: VSpacing.screenPadding,
        leading: VSpacing.screenPadding,
        bottom: VSpacing.screenPadding,
        trailing: VSpacing.screenPadding
    )

    static let cardPadding = EdgeInsets(
        top: VSpacing.cardPadding,
        leading: VSpacing.cardPadding,
        bottom: VSpacing.cardPadding,
        trailing: VSpacing.cardPadding
    )

    static let tightPadding = EdgeInsets(
        top: VSpacing.sm,
        leading: VSpacing.sm,
        bottom: VSpacing.sm,
        trailing: VSpacing.sm
    )

    static let largePadding = EdgeInsets(
        top: VSpacing.xl,
        leading: VSpacing.xl,
        bottom: VSpacing.xl,
        trailing: VSpacing.xl
    )
}
