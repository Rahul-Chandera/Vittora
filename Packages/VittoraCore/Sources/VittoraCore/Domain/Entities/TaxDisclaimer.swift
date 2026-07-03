import Foundation

public enum TaxDisclaimer {
    public static var text: String {
        String(localized: "Estimates only. Consult a qualified tax professional for advice.")
    }

    /// Always-visible US results label (DEC-010 / M1 de-risk condition #1).
    public static var usFederalEstimateLabel: String {
        String(localized: "Federal estimate — state taxes not included")
    }
}
