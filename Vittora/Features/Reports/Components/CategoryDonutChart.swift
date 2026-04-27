import SwiftUI
import Charts

struct CategoryDonutChart: View {
    let breakdowns: [CategoryBreakdown]
    @Binding var selectedCategory: UUID?
    var currencyCode: String = CurrencyDefaults.code
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Chart(Array(breakdowns.prefix(8).enumerated()), id: \.offset) { index, item in
            SectorMark(
                angle: .value("Amount", item.amount),
                innerRadius: .ratio(0.6),
                outerRadius: selectedCategory == item.id ? .ratio(1.0) : .ratio(0.9),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(categoryColor(at: index))
            .opacity(selectedCategory == nil || selectedCategory == item.id ? 1.0 : 0.5)
        }
        .chartAngleSelection(value: Binding(
            get: { selectedCategory.flatMap { id in breakdowns.firstIndex(where: { $0.id == id }) } },
            set: { newIndex in
                if let index = newIndex {
                    selectedCategory = breakdowns[index].id
                } else {
                    selectedCategory = nil
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
