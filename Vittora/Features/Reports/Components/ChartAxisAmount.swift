import Foundation

/// Compact amounts for chart axis labels.
///
/// The two chart components each carried their own copy of this, both doing
///
///     String(format: "%.0fk", amount / 1000)
///
/// which rounds to whole thousands — so a Spending Trends axis running
/// 0 / 500 / 1,000 / 1,500 / 2,000 printed "$2k" for BOTH 1,500 and 2,000: two
/// identical labels at different heights, with no way to read the chart
/// against them.
///
/// One decimal is shown only when the value is not a whole number of
/// thousands, so $2k stays $2k and $1,500 becomes $1.5k.
enum ChartAxisAmount {
    nonisolated static func compact(_ amount: Double, symbol: String) -> String {
        let magnitude = abs(amount)
        let sign = amount < 0 ? "-" : ""

        if magnitude >= 1_000_000 {
            return sign + symbol + scaled(magnitude / 1_000_000) + "M"
        }
        if magnitude >= 1_000 {
            return sign + symbol + scaled(magnitude / 1_000) + "k"
        }
        return sign + symbol + String(format: "%.0f", magnitude)
    }

    /// Whole values lose the ".0"; everything else keeps one place. Rounding to
    /// one decimal first means 1,999 reads "2k" rather than "2.0k".
    private nonisolated static func scaled(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", rounded)
    }
}
