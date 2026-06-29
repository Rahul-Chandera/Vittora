import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import VittoraCore
#endif

extension Color {
    /// Initialize a Color from a hex string.
    ///
    /// - Parameter hex: Hex color string in format "#RRGGBB" or "RRGGBB"
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespaces)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        guard hexSanitized.count == 6 else { return nil }

        let scanner = Scanner(string: hexSanitized)
        var hexNumber: UInt64 = 0

        guard scanner.scanHexInt64(&hexNumber) else { return nil }

        let red = CGFloat((hexNumber & 0xFF0000) >> 16) / 255
        let green = CGFloat((hexNumber & 0x00FF00) >> 8) / 255
        let blue = CGFloat(hexNumber & 0x0000FF) / 255

        self.init(red: red, green: green, blue: blue)
    }

    /// Get the hex string representation of this color.
    ///
    /// - Returns: Hex color string in format "#RRGGBB"
    var hexString: String? {
        guard let components = Self.rgbByteComponents(for: self) else { return nil }
        return String(format: "#%02X%02X%02X", components.r, components.g, components.b)
    }

    /// Lighten or darken the color by a specified percentage.
    ///
    /// - Parameter percentage: Percentage change (-100 to 100)
    /// - Returns: Modified color
    func adjusted(by percentage: CGFloat) -> Color {
        guard let components = Self.normalizedRGBComponents(for: self) else { return self }

        let r = max(0, min(1, components.r + (percentage / 100)))
        let g = max(0, min(1, components.g + (percentage / 100)))
        let b = max(0, min(1, components.b + (percentage / 100)))

        return Color(red: r, green: g, blue: b)
    }

    /// Get a lighter version of this color.
    var lighter: Color {
        adjusted(by: 20)
    }

    /// Get a darker version of this color.
    var darker: Color {
        adjusted(by: -20)
    }

    /// Apply opacity to the color.
    func withOpacity(_ opacity: Double) -> Color {
        self.opacity(opacity)
    }

    private static func rgbByteComponents(for color: Color) -> (r: Int, g: Int, b: Int)? {
        guard let components = normalizedRGBComponents(for: color) else { return nil }
        return (
            Int((components.r * 255).rounded()),
            Int((components.g * 255).rounded()),
            Int((components.b * 255).rounded())
        )
    }

    private static func normalizedRGBComponents(for color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat)? {
        #if os(iOS)
        let platformColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (red, green, blue)
        }

        var white: CGFloat = 0
        guard platformColor.getWhite(&white, alpha: &alpha) else { return nil }
        return (white, white, white)
        #elseif os(macOS)
        guard let platformColor = NSColor(color).usingColorSpace(.sRGB) else { return nil }

        if platformColor.colorSpace.colorSpaceModel == .gray {
            var white: CGFloat = 0
            var alpha: CGFloat = 0
            platformColor.getWhite(&white, alpha: &alpha)
            return (white, white, white)
        }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue)
        #endif
    }
}
