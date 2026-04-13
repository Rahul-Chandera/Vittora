import Foundation

struct SaveTaxProfileUseCase: Sendable {
    let taxProfileRepository: any TaxProfileRepository

    enum ProfileError: LocalizedError {
        case invalidIncome

        var errorDescription: String? {
            switch self {
            case .invalidIncome:
                return String(localized: "Annual income must be greater than zero.")
            }
        }
    }

    func execute(_ profile: TaxProfile) async throws {
        guard profile.annualIncome > 0 else { throw ProfileError.invalidIncome }
        try await taxProfileRepository.save(profile)
    }

    func fetchOrDefault() async throws -> TaxProfile {
        try await taxProfileRepository.fetch() ?? TaxProfile()
    }
}
