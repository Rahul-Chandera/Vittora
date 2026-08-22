import SwiftUI
import Charts
import VittoraCore

/// Maps between a sector and a position on the donut's angle axis.
///
/// `chartAngleSelection` reports a value on the axis the marks are plotted
/// against. Here that axis is `.value("Amount", item.amount)`, so the reported
/// value is a position along the SUMMED amounts — not the index of a mark.
/// Using it to subscript the data crashed the first time a drag selected
/// anything past the opening sliver: with $3,510 of spending the reported
/// value ran into the thousands while the array held four categories.
/// (`Thread 1: Fatal error: Index out of range`, reported from a device.)
///
/// Separated from the view so the mapping can be tested without a chart.
enum CategoryDonutSelection {
    /// Sectors the chart actually draws. Selection must resolve against these
    /// and not the full list — the previous code looked up an index in the
    /// unclipped array, so a ninth category could never round-trip.
    nonisolated static func plotted(_ breakdowns: [CategoryBreakdown]) -> [CategoryBreakdown] {
        Array(breakdowns.prefix(8))
    }

    /// The sector whose arc covers `value` on the cumulative-amount axis.
    nonisolated static func category(
        atCumulativeAmount value: Int,
        in breakdowns: [CategoryBreakdown]
    ) -> CategoryBreakdown? {
        guard value >= 0 else { return nil }
        let target = Decimal(value)
        var upperBound = Decimal(0)
        for item in plotted(breakdowns) {
            upperBound += item.amount
            if target <= upperBound {
                return item
            }
        }
        // Past the last arc: rounding can put a selection a hair beyond the
        // total, and the nearest sector is the last one rather than nothing.
        return plotted(breakdowns).last
    }

    /// The midpoint of a sector's arc, so a selection made anywhere else —
    /// tapping the legend, restoring state — highlights the same wedge a drag
    /// to that sector would have produced.
    nonisolated static func cumulativeMidpoint(
        of id: UUID,
        in breakdowns: [CategoryBreakdown]
    ) -> Int? {
        var lowerBound = Decimal(0)
        for item in plotted(breakdowns) {
            if item.id == id {
                let midpoint = lowerBound + item.amount / 2
                return (midpoint as NSDecimalNumber).intValue
            }
            lowerBound += item.amount
        }
        return nil
    }
}

struct CategoryDonutChart: View {
    let breakdowns: [CategoryBreakdown]
    @Binding var selectedCategory: UUID?
    var currencyCode: String = CurrencyDefaults.code
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Chart(Array(CategoryDonutSelection.plotted(breakdowns).enumerated()), id: \.offset) { index, item in
            SectorMark(
                angle: .value("Amount", item.amount),
                innerRadius: .ratio(0.6),
                outerRadius: selectedCategory == item.id ? .ratio(1.0) : .ratio(0.9),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(categoryColor(at: index))
            .opacity(selectedCategory == nil || selectedCategory == item.id ? 1.0 : 0.5)
            .accessibilityLabel(item.category.displayName)
            .accessibilityValue(item.amount.formatted(.currency(code: currencyCode)))
        }
        .chartAngleSelection(value: Binding(
            get: {
                selectedCategory.flatMap {
                    CategoryDonutSelection.cumulativeMidpoint(of: $0, in: breakdowns)
                }
            },
            set: { newValue in
                selectedCategory = newValue.flatMap {
                    CategoryDonutSelection.category(atCumulativeAmount: $0, in: breakdowns)?.id
                }
            }
        ))
        .animation(reduceMotion ? .none : .easeInOut(duration: VSpacing.animationStandard), value: selectedCategory)
        .accessibilityChartDescriptor(
            CategoryBreakdownChartDescriptor(
                breakdowns: breakdowns,
                currencyCode: currencyCode
            )
        )
    }

    private func categoryColor(at index: Int) -> Color {
        VColors.categoryColors[index % VColors.categoryColors.count]
    }
}

#Preview {
    CategoryDonutChart(breakdowns: [], selectedCategory: .constant(nil))
        .frame(width: 160, height: 160)
        .padding()
}
