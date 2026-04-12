import SwiftUI

enum VTypography {
    // MARK: - Headers
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let title1 = Font.system(size: 28, weight: .bold, design: .default)
    static let title2 = Font.system(size: 22, weight: .bold, design: .default)
    static let title3 = Font.system(size: 20, weight: .semibold, design: .default)

    // MARK: - Body
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyBold = Font.system(size: 17, weight: .semibold, design: .default)
    static let callout = Font.system(size: 16, weight: .regular, design: .default)
    static let calloutBold = Font.system(size: 16, weight: .semibold, design: .default)
    static let subheadline = Font.system(size: 15, weight: .semibold, design: .default)
    static let caption1 = Font.system(size: 13, weight: .regular, design: .default)
    static let caption1Bold = Font.system(size: 13, weight: .semibold, design: .default)
    static let caption2 = Font.system(size: 12, weight: .regular, design: .default)
    static let caption2Bold = Font.system(size: 12, weight: .semibold, design: .default)

    // MARK: - Amount Text (Rounded Numbers for Financial Data)
    static let amountLarge = Font.system(size: 32, weight: .semibold, design: .rounded)
    static let amountMedium = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let amountSmall = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let amountCaption = Font.system(size: 14, weight: .semibold, design: .rounded)

    // MARK: - Monospaced (for tables, codes)
    static let monospacedSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let monospacedBody = Font.system(size: 17, weight: .regular, design: .monospaced)

    // MARK: - Dynamic Type Support
    enum DynamicSize {
        case xSmall
        case small
        case medium
        case large
        case xLarge
        case xxLarge
        case xxxLarge

        var sizeMultiplier: CGFloat {
            switch self {
            case .xSmall: return 0.8
            case .small: return 0.9
            case .medium: return 1.0
            case .large: return 1.1
            case .xLarge: return 1.2
            case .xxLarge: return 1.3
            case .xxxLarge: return 1.4
            }
        }
    }
}

// MARK: - Font Extension Helpers
extension Font {
    static func scaledBody(sizeMultiplier: CGFloat = 1.0) -> Font {
        return .system(size: 17 * sizeMultiplier, weight: .regular)
    }

    static func scaledTitle(sizeMultiplier: CGFloat = 1.0) -> Font {
        return .system(size: 28 * sizeMultiplier, weight: .bold)
    }

    static func scaledAmount(sizeMultiplier: CGFloat = 1.0) -> Font {
        return .system(size: 24 * sizeMultiplier, weight: .semibold, design: .rounded)
    }
}
