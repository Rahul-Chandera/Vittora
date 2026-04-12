import SwiftUI

extension Color {
    /// Initialize a Color from a hex string.
    ///
    /// - Parameter hex: Hex color string in format "#RRGGBB" or "RRGGBB"
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespaces)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        // Check for valid hex length
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
        #if os(macOS)
        guard let rgbColor = self.cgColor else { return nil }
        let components = rgbColor.components ?? [0, 0, 0]
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        guard let components = self.cgColor?.components else { return nil }
        guard components.count >= 3 else { return nil }

        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
        #endif
    }

    /// Lighten or darken the color by a specified percentage.
    ///
    /// - Parameter percentage: Percentage change (-100 to 100)
    /// - Returns: Modified color
    func adjusted(by percentage: CGFloat) -> Color {
        #if os(macOS)
        return self
        #else
        guard let components = self.cgColor?.components else { return self }
        guard components.count >= 3 else { return self }

        let r = max(0, min(1, components[0] + (percentage / 100)))
        let g = max(0, min(1, components[1] + (percentage / 100)))
        let b = max(0, min(1, components[2] + (percentage / 100)))

        return Color(red: r, green: g, blue: b)
        #endif
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
}
