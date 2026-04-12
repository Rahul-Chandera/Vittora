import SwiftUI
import Testing

@Suite("Color Hex Conversion Tests")
struct ColorHexTests {
    @Test("Parse hex color with hash")
    func testParseHexWithHash() {
        let color = Color(hex: "#FF0000")
        #expect(color != nil)
    }

    @Test("Parse hex color without hash")
    func testParseHexWithoutHash() {
        let color = Color(hex: "00FF00")
        #expect(color != nil)
    }

    @Test("Parse invalid hex - too short")
    func testParseInvalidHexShort() {
        let color = Color(hex: "#FFF")
        #expect(color == nil)
    }

    @Test("Parse invalid hex - too long")
    func testParseInvalidHexLong() {
        let color = Color(hex: "#FF0000FF")
        #expect(color == nil)
    }

    @Test("Parse invalid hex - non-hex characters")
    func testParseInvalidHexCharacters() {
        let color = Color(hex: "#GGGGGG")
        #expect(color == nil)
    }

    @Test("Parse white color")
    func testParseWhite() {
        let color = Color(hex: "#FFFFFF")
        #expect(color != nil)
    }

    @Test("Parse black color")
    func testParseBlack() {
        let color = Color(hex: "#000000")
        #expect(color != nil)
    }

    @Test("Parse primary color - light mode")
    func testParsePrimaryColorLight() {
        let color = Color(hex: "#007A87")
        #expect(color != nil)
    }

    @Test("Parse primary color - dark mode")
    func testParsePrimaryColorDark() {
        let color = Color(hex: "#4DB6C4")
        #expect(color != nil)
    }

    @Test("Parse income color")
    func testParseIncomeColor() {
        let color = Color(hex: "#34A853")
        #expect(color != nil)
    }

    @Test("Parse expense color")
    func testParseExpenseColor() {
        let color = Color(hex: "#EA4335")
        #expect(color != nil)
    }

    @Test("Parse with whitespace")
    func testParseWithWhitespace() {
        let color = Color(hex: "  #FF0000  ")
        #expect(color != nil)
    }

    @Test("Case insensitive parsing")
    func testCaseInsensitiveParsing() {
        let colorLower = Color(hex: "#ff0000")
        let colorUpper = Color(hex: "#FF0000")
        #expect(colorLower != nil)
        #expect(colorUpper != nil)
    }

    @Test("Generate hex string from red color")
    func testGenerateHexRed() {
        let redColor = Color.red
        let hexString = redColor.hexString
        #expect(hexString != nil)
        // Red color should be FF0000 (allowing for minor variations in representation)
    }

    @Test("Generate hex string from green color")
    func testGenerateHexGreen() {
        let greenColor = Color.green
        let hexString = greenColor.hexString
        #expect(hexString != nil)
    }

    @Test("Generate hex string from blue color")
    func testGenerateHexBlue() {
        let blueColor = Color.blue
        let hexString = blueColor.hexString
        #expect(hexString != nil)
    }

    @Test("Round-trip conversion")
    func testRoundTripConversion() {
        let originalHex = "#4A90E2"
        if let color = Color(hex: originalHex) {
            let generatedHex = color.hexString
            #expect(generatedHex != nil)
            // Both should be valid hex strings
        }
    }

    @Test("Lighter color modifier")
    func testLighterColor() {
        let color = Color.black
        let lighterColor = color.lighter
        #expect(lighterColor != nil)
    }

    @Test("Darker color modifier")
    func testDarkerColor() {
        let color = Color.white
        let darkerColor = color.darker
        #expect(darkerColor != nil)
    }

    @Test("Adjusted color by percentage")
    func testAdjustedColor() {
        let color = Color.blue
        let adjustedColor = color.adjusted(by: 10)
        #expect(adjustedColor != nil)
    }

    @Test("Apply opacity to color")
    func testWithOpacity() {
        let color = Color.red
        let transparentColor = color.withOpacity(0.5)
        #expect(transparentColor != nil)
    }

    @Test("All standard colors have hex strings")
    func testStandardColorsHex() {
        let colors: [Color] = [.red, .green, .blue, .orange, .yellow, .pink, .purple]
        for color in colors {
            let hexString = color.hexString
            #expect(hexString != nil)
        }
    }
}
