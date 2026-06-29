import Foundation

public extension Decimal {
    /// True when the value is representable as a finite double (used for sync integrity checks).
    nonisolated var isFiniteDecimal: Bool {
        Double(truncating: NSDecimalNumber(decimal: self)).isFinite
    }
}
