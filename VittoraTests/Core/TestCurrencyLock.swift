import Foundation

/// Serializes tests that mutate the shared currency `UserDefaults` keys so
/// parallel suites cannot race `CurrencyDefaults.code` (standard vs App Group).
actor TestCurrencyLock {
    static let shared = TestCurrencyLock()

    func run<T: Sendable>(_ body: @Sendable () throws -> T) rethrows -> T {
        try body()
    }

    func run<T: Sendable>(_ body: @Sendable () async throws -> T) async rethrows -> T {
        try await body()
    }
}
