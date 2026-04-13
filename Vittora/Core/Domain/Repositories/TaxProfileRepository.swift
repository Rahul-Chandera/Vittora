import Foundation

protocol TaxProfileRepository: Sendable {
    /// Returns the single stored tax profile, or nil if none has been saved.
    func fetch() async throws -> TaxProfile?
    /// Creates or replaces the stored profile.
    func save(_ profile: TaxProfile) async throws
    /// Deletes the stored profile.
    func delete() async throws
}
