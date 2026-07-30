// Render lines of text to transparent PNGs using CoreText.
//
// Pillow on this machine has no Raqm, so it cannot shape complex scripts:
// Devanagari matras and conjuncts come out in the wrong order. CoreText shapes
// correctly for every script the app ships and picks fallback fonts itself, so
// all headline rendering goes through here.
//
// Takes a JSON manifest so the whole run is one swift invocation rather than one
// per string — process startup dominates otherwise.
//
// Usage: swift render_text.swift manifest.json
// Manifest: [{"out": "...png", "size": 200, "weight": "bold|medium",
//             "rgb": [17, 24, 39], "text": "…"}]
import AppKit
import Foundation

struct Item: Decodable {
    let out: String
    let size: Double
    let weight: String
    let rgb: [Double]
    let text: String
}

let args = Array(CommandLine.arguments.dropFirst())
guard let manifestPath = args.first else {
    FileHandle.standardError.write(Data("usage: render_text.swift manifest.json\n".utf8))
    exit(64)
}

let items = try JSONDecoder().decode(
    [Item].self, from: Data(contentsOf: URL(fileURLWithPath: manifestPath))
)

for item in items {
    let font = NSFont.systemFont(
        ofSize: item.size, weight: item.weight == "bold" ? .bold : .medium
    )
    let color = NSColor(
        srgbRed: item.rgb[0] / 255, green: item.rgb[1] / 255, blue: item.rgb[2] / 255, alpha: 1
    )
    let attributed = NSAttributedString(
        string: item.text, attributes: [.font: font, .foregroundColor: color]
    )

    // Generous padding: Devanagari ascenders and matras sit outside the
    // typographic line height, and a tight box clips them.
    let measured = attributed.size()
    let pad = item.size * 0.5
    let width = Int((measured.width + pad * 2).rounded(.up))
    let height = Int((measured.height + pad * 2).rounded(.up))

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { exit(1) }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    attributed.draw(at: NSPoint(x: pad, y: pad))
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
    try png.write(to: URL(fileURLWithPath: item.out))
}
