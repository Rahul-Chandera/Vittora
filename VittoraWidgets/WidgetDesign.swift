import SwiftUI

/// Minimal design tokens for the widget extension (cannot import the app target).
enum WidgetColors {
    static let primary = Color(red: 58 / 255, green: 215 / 255, blue: 166 / 255)
    static let expense = Color(red: 197 / 255, green: 34 / 255, blue: 31 / 255)
    static let income = Color(red: 27 / 255, green: 127 / 255, blue: 55 / 255)
    static let warning = Color.orange
    static let budgetSafe = Color.green
    static let budgetDanger = Color.red
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    static func budgetStatus(progress: Double) -> Color {
        if progress >= 0.9 { return budgetDanger }
        if progress >= 0.75 { return warning }
        return budgetSafe
    }

    static func hex(_ hex: String) -> Color {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else {
            return primary
        }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

enum WidgetTypography {
    static let title = Font.system(.title2, design: .rounded).weight(.semibold)
    static let amount = Font.system(.title3, design: .rounded).weight(.semibold)
    static let headline = Font.headline
    static let caption = Font.caption
    static let caption2 = Font.caption2
}
