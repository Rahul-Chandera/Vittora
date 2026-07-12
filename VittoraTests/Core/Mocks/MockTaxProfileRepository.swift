import Foundation
import VittoraCore
@testable import Vittora

@MainActor
final class MockTaxProfileRepository: TaxProfileRepository {
    private(set) var profile: TaxProfile?
    var shouldThrowError: Bool = false
    var throwError: VittoraError = .unknown(String(localized: "Mock error"))
    var writeFailureControls = MockWriteFailureControls()

    private func checkWriteFailure(for entityID: UUID? = nil) throws {
        try writeFailureControls.checkWrite(entityID: entityID)
    }

    func fetch() async throws -> TaxProfile? {
        if shouldThrowError { throw throwError }
        return profile
    }

    func save(_ incoming: TaxProfile) async throws {
        try checkWriteFailure(for: incoming.id)
        if shouldThrowError { throw throwError }
        profile = incoming
    }

    func delete() async throws {
        try checkWriteFailure(for: profile?.id)
        if shouldThrowError { throw throwError }
        profile = nil
    }

    func seed(_ incoming: TaxProfile) {
        profile = incoming
    }
}
