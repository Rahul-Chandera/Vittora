import SwiftUI
import VittoraCore

enum VTypography {
    // MARK: - Headers
    static let largeTitle = Font.system(.largeTitle, design: .default).weight(.bold)
    static let title1 = Font.system(.title, design: .default).weight(.bold)
    static let title2 = Font.system(.title2, design: .default).weight(.bold)
    static let title3 = Font.system(.title3, design: .default).weight(.semibold)

    // MARK: - Body
    static let body = Font.system(.body, design: .default)
    static let bodyBold = Font.system(.body, design: .default).weight(.semibold)
    static let callout = Font.system(.callout, design: .default)
    static let calloutBold = Font.system(.callout, design: .default).weight(.semibold)
    static let subheadline = Font.system(.subheadline, design: .default).weight(.semibold)
    static let caption1 = Font.system(.caption, design: .default)
    static let caption1Bold = Font.system(.caption, design: .default).weight(.semibold)
    // `.caption2` only partially scales at accessibility sizes and is flagged by
    // XCTest's Dynamic Type audit. Use the fully scalable caption tier instead.
    static let caption2 = Font.system(.caption, design: .default)
    static let caption2Bold = Font.system(.caption, design: .default).weight(.semibold)

    // MARK: - Amount Text (Rounded Numbers for Financial Data)
    static let amountLarge = Font.system(.title, design: .rounded).weight(.semibold)
    static let amountMedium = Font.system(.title2, design: .rounded).weight(.semibold)
    static let amountSmall = Font.system(.title3, design: .rounded).weight(.semibold)
    static let amountCaption = Font.system(.callout, design: .rounded).weight(.semibold)

    // MARK: - Monospaced (for tables, codes)
    static let monospacedSmall = Font.system(.caption, design: .monospaced)
    static let monospacedBody = Font.system(.body, design: .monospaced)
}
