import WidgetKit
import SwiftUI
import VittoraCore

struct BudgetRemainingEntry: TimelineEntry {
    let date: Date
    let snapshot: BudgetRemainingSnapshot
    let isPlaceholder: Bool

    static var placeholder: BudgetRemainingEntry {
        BudgetRemainingEntry(
            date: .now,
            snapshot: BudgetRemainingSnapshot(
                spent: 750,
                total: 1000,
                currencyCode: "USD",
                categories: [
                    BudgetCategoryProgress(name: "Groceries", spent: 320, amount: 400, colorHex: "#34C759"),
                    BudgetCategoryProgress(name: "Dining", spent: 180, amount: 200, colorHex: "#FF9500"),
                    BudgetCategoryProgress(name: "Transport", spent: 90, amount: 150, colorHex: "#007AFF"),
                ],
                hasBudgets: true
            ),
            isPlaceholder: true
        )
    }

    static var empty: BudgetRemainingEntry {
        BudgetRemainingEntry(
            date: .now,
            snapshot: BudgetRemainingSnapshot(
                spent: 0,
                total: 0,
                currencyCode: CurrencyDefaults.code,
                categories: [],
                hasBudgets: false
            ),
            isPlaceholder: false
        )
    }
}

struct BudgetRemainingTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetRemainingEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (BudgetRemainingEntry) -> Void) {
        let isPreview = context.isPreview
        Task {
            if isPreview {
                completion(.placeholder)
                return
            }
            completion(await Self.loadEntry(date: .now))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<BudgetRemainingEntry>) -> Void) {
        Task {
            let now = Date.now
            let dates = WidgetTimelineDates.entryDates(now: now)
            let snapshot = await Self.loadSnapshot()
            let entries = dates.map {
                BudgetRemainingEntry(date: $0, snapshot: snapshot, isPlaceholder: false)
            }
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }

    private static func loadEntry(date: Date) async -> BudgetRemainingEntry {
        BudgetRemainingEntry(date: date, snapshot: await loadSnapshot(), isPlaceholder: false)
    }

    private static func loadSnapshot() async -> BudgetRemainingSnapshot {
        do {
            let provider = try WidgetDataProvider.makeSharedReadOnly()
            return try await provider.budgetRemainingSnapshot()
        } catch {
            return BudgetRemainingSnapshot(
                spent: 0,
                total: 0,
                currencyCode: CurrencyDefaults.code,
                categories: [],
                hasBudgets: false
            )
        }
    }
}

struct BudgetRemainingWidget: Widget {
    let kind = "VittoraBudgetRemainingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetRemainingTimelineProvider()) { entry in
            BudgetRemainingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "Budget Remaining"))
        .description(String(localized: "Track what's left in this month's budgets."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BudgetRemainingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BudgetRemainingEntry

    var body: some View {
        Group {
            if !entry.snapshot.hasBudgets && !entry.isPlaceholder {
                emptyContent
            } else {
                switch family {
                case .systemMedium:
                    mediumContent
                default:
                    smallContent
                }
            }
        }
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Budget Remaining"))
                .font(WidgetTypography.caption)
                .foregroundStyle(WidgetColors.textSecondary)
            Text(String(localized: "Set a budget"))
                .font(WidgetTypography.headline)
                .foregroundStyle(WidgetColors.textPrimary)
            Text(String(localized: "Add a monthly budget in Vittora to track what's left."))
                .font(WidgetTypography.caption2)
                .foregroundStyle(WidgetColors.textSecondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }

    private var smallContent: some View {
        HStack(spacing: 12) {
            progressRing(size: 52, lineWidth: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Remaining"))
                    .font(WidgetTypography.caption)
                    .foregroundStyle(WidgetColors.textSecondary)
                Text(formatted(entry.snapshot.remaining))
                    .font(WidgetTypography.amount)
                    .foregroundStyle(remainingColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding()
    }

    private var mediumContent: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(spacing: 8) {
                progressRing(size: 64, lineWidth: 7)
                Text(formatted(entry.snapshot.remaining))
                    .font(WidgetTypography.caption)
                    .foregroundStyle(remainingColor)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(width: 80)

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Top Budgets"))
                    .font(WidgetTypography.caption)
                    .foregroundStyle(WidgetColors.textSecondary)
                ForEach(Array(entry.snapshot.categories.enumerated()), id: \.offset) { _, category in
                    categoryRow(category)
                }
                Spacer(minLength: 0)
            }
        }
        .padding()
    }

    private func progressRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        let progress = min(max(entry.snapshot.progress, 0), 1)
        return ZStack {
            Circle()
                .stroke(WidgetColors.textSecondary.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    WidgetColors.budgetStatus(progress: entry.snapshot.progress),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(Int(min(entry.snapshot.progress * 100, 999)))%")
                .font(WidgetTypography.caption2)
                .foregroundStyle(WidgetColors.textPrimary)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(String(localized: "Budget progress"))
        .accessibilityValue("\(Int(min(entry.snapshot.progress * 100, 999)))%")
    }

    private func categoryRow(_ category: BudgetCategoryProgress) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(category.name)
                    .font(WidgetTypography.caption2)
                    .foregroundStyle(WidgetColors.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(formatted(category.remaining))
                    .font(WidgetTypography.caption2)
                    .foregroundStyle(WidgetColors.textSecondary)
                    .lineLimit(1)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(WidgetColors.textSecondary.opacity(0.15))
                    Capsule()
                        .fill(WidgetColors.hex(category.colorHex))
                        .frame(width: geo.size.width * CGFloat(min(category.progress, 1)))
                }
            }
            .frame(height: 5)
        }
    }

    private var remainingColor: Color {
        entry.snapshot.remaining < 0 ? WidgetColors.budgetDanger : WidgetColors.budgetSafe
    }

    private func formatted(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: entry.snapshot.currencyCode))
    }
}

#if DEBUG
#Preview(as: .systemSmall) {
    BudgetRemainingWidget()
} timeline: {
    BudgetRemainingEntry.placeholder
}

#Preview(as: .systemMedium) {
    BudgetRemainingWidget()
} timeline: {
    BudgetRemainingEntry.placeholder
}
#endif
