import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Flag for a currency code, as an **Image** rather than Text.
///
/// Rasterising is not cosmetic. As a `Text` node the flag is audited as text, and
/// flags are mostly white (🇯🇵 🇸🇬 🇦🇪 🇺🇸) so they miss AA against the row —
/// and where the row is an `.accessibilityElement(children: .combine)`, the
/// glyph also widened the combined element enough to report clipping. That was
/// 4 contrast + 9 clipped failures in testOnboardingAccessibilityAudit.
/// An emoji flag is a fixed-palette image whose colours cannot be adjusted, so
/// the honest fix is to present it as the image it is rather than exempt the
/// screen from the audit.
///
/// Callers should hide it from accessibility — the currency name and code
/// already carry the meaning — and skip it at accessibility text sizes, where
/// the row needs its width for the label.
func currencyFlagImage(for currencyCode: String) -> Image? {
    #if canImport(UIKit)
    let emoji = currencyFlagEmoji(for: currencyCode)
    if let cached = FlagImageCache.shared.image(for: emoji) { return Image(uiImage: cached) }
    let font = UIFont.systemFont(ofSize: 22)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let size = (emoji as NSString).size(withAttributes: attributes)
    guard size.width > 0, size.height > 0 else { return nil }
    let rendered = UIGraphicsImageRenderer(size: size).image { _ in
        (emoji as NSString).draw(at: .zero, withAttributes: attributes)
    }
    FlagImageCache.shared.store(rendered, for: emoji)
    return Image(uiImage: rendered)
    #else
    return nil
    #endif
}

#if canImport(UIKit)
/// Rasterised flags are reused across rows and redraws; rendering per row per
/// frame is needless work in a scrolling list.
private final class FlagImageCache {
    static let shared = FlagImageCache()
    private var storage: [String: UIImage] = [:]
    func image(for key: String) -> UIImage? { storage[key] }
    func store(_ image: UIImage, for key: String) { storage[key] = image }
}
#endif

func currencyFlagEmoji(for currencyCode: String) -> String {
    let special = ["EUR": "🇪🇺", "XAF": "🌍", "XOF": "🌍", "XCD": "🌎", "XPF": "🌏"]
    if let s = special[currencyCode] { return s }
    let region = String(currencyCode.prefix(2)).uppercased()
    guard region.count == 2, region.allSatisfy({ $0.isLetter }) else { return "🏳️" }
    // Regional indicators sit 0x1F1E6 above "A".
    let scalars = region.unicodeScalars.compactMap { UnicodeScalar($0.value + 0x1F1E6 - 65) }
    guard scalars.count == 2 else { return "🏳️" }
    return String(String.UnicodeScalarView(scalars))
}
