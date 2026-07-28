import Foundation
import Testing

@Suite("Spanish localization catalog")
struct SpanishLocalizationCatalogTests {
    @Test("every Localizable.xcstrings entry has an es translation")
    func everyStringHasSpanishTranslation() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // SpanishLocalizationCatalogTests.swift
            .deletingLastPathComponent() // Localization
            .deletingLastPathComponent() // Core
            .deletingLastPathComponent() // VittoraTests
            .appendingPathComponent("Vittora", isDirectory: true)
            .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let catalog = try JSONDecoder().decode(StringCatalog.self, from: data)

        let missing = catalog.strings.compactMap { key, entry -> String? in
            // Empty catalog keys are allowed to keep an empty translation (matches `hi`).
            if key.isEmpty { return nil }
            let localization = entry.localizations?["es"]
            let value = localization?.stringUnit?.value
            let translated = localization?.stringUnit?.state == "translated"
                && value != nil
                && !(value?.isEmpty ?? true)
            return translated ? nil : key
        }.sorted()

        #expect(
            missing.isEmpty,
            "Missing es translations (\(missing.count)): \(missing.prefix(20).joined(separator: " | "))"
        )
    }
}

private struct StringCatalog: Decodable {
    var strings: [String: CatalogEntry]
}

private struct CatalogEntry: Decodable {
    var localizations: [String: CatalogLocalization]?
}

private struct CatalogLocalization: Decodable {
    var stringUnit: CatalogStringUnit?
}

private struct CatalogStringUnit: Decodable {
    var state: String?
    var value: String?
}
