import Foundation
@testable import Vittora

@MainActor
final class MockTaxProfileRepository: TaxProfileRepository {
    private(set) var profile: TaxProfile?
    var shouldThrowError: Bool = false
    var throwError: VittoraError = .unknown(String(localized: "Mock error"))

    func fetch() async throws -> TaxProfile? {
        if shouldThrowError { throw throwError }
        return profile
    }

    func save(_ incoming: TaxProfile) async throws {
        if shouldThrowError { throw throwError }
        profile = incoming
    }

    func delete() async throws {
        if shouldThrowError { throw throwError }
        profile = nil
    }

    func seed(_ incoming: TaxProfile) {
        profile = incoming
    }
}
