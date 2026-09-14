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
            return isTranslated(localization) ? nil : key
        }.sorted()

        #expect(
            missing.isEmpty,
            "Missing es translations (\(missing.count)): \(missing.prefix(20).joined(separator: " | "))"
        )
    }
}

private func isTranslated(_ localization: CatalogLocalization?) -> Bool {
    guard let localization else { return false }

    if let unit = localization.stringUnit,
       unit.state == "translated",
       let value = unit.value,
       !value.isEmpty {
        return true
    }

    if let plural = localization.variations?.plural, !plural.isEmpty {
        return plural.values.allSatisfy(isTranslatedCategory(_:))
    }

    if let substitutions = localization.substitutions, !substitutions.isEmpty {
        return substitutions.values.allSatisfy { substitution in
            guard let plural = substitution.variations?.plural, !plural.isEmpty else {
                return false
            }
            return plural.values.allSatisfy(isTranslatedCategory(_:))
        }
    }

    return false
}

private func isTranslatedCategory(_ category: CatalogPluralCategory) -> Bool {
    guard let unit = category.stringUnit,
          unit.state == "translated",
          let value = unit.value,
          !value.isEmpty else {
        return false
    }
    return true
}

private struct StringCatalog: Decodable {
    var strings: [String: CatalogEntry]
}

private struct CatalogEntry: Decodable {
    var localizations: [String: CatalogLocalization]?
}

private struct CatalogLocalization: Decodable {
    var stringUnit: CatalogStringUnit?
    var variations: CatalogVariations?
    var substitutions: [String: CatalogSubstitution]?
}

private struct CatalogVariations: Decodable {
    var plural: [String: CatalogPluralCategory]?
}

private struct CatalogPluralCategory: Decodable {
    var stringUnit: CatalogStringUnit?
}

private struct CatalogSubstitution: Decodable {
    var variations: CatalogVariations?
}

private struct CatalogStringUnit: Decodable {
    var state: String?
    var value: String?
}
