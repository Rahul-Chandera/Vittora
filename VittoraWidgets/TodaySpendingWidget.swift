import WidgetKit
import SwiftUI
import VittoraCore

struct TodaySpendingEntry: TimelineEntry {
    let date: Date
    let snapshot: TodaySpendingSnapshot
    let isPlaceholder: Bool

    static var placeholder: TodaySpendingEntry {
        TodaySpendingEntry(
            date: .now,
            snapshot: TodaySpendingSnapshot(
                todayAmount: 42,
                yesterdayAmount: 35,
                last7DayAmounts: [20, 28, 15, 40, 32, 35, 42],
                currencyCode: "USD"
            ),
            isPlaceholder: true
        )
    }
}

struct TodaySpendingTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaySpendingEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (TodaySpendingEntry) -> Void) {
        let isPreview = context.isPreview
        Task {
            if isPreview {
                completion(.placeholder)
                return
            }
            completion(await Self.loadEntry(date: .now))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<TodaySpendingEntry>) -> Void) {
        Task {
            let now = Date.now
            let dates = WidgetTimelineDates.entryDates(now: now)
            let snapshot = await Self.loadSnapshot()
            let entries = dates.map {
                TodaySpendingEntry(date: $0, snapshot: snapshot, isPlaceholder: false)
            }
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }

    private static func loadEntry(date: Date) async -> TodaySpendingEntry {
        TodaySpendingEntry(date: date, snapshot: await loadSnapshot(), isPlaceholder: false)
    }

    private static func loadSnapshot() async -> TodaySpendingSnapshot {
        do {
            let provider = try WidgetDataProvider.makeSharedReadOnly()
            return try await provider.todaySpendingSnapshot()
        } catch {
            return TodaySpendingSnapshot(
                todayAmount: 0,
                yesterdayAmount: 0,
                last7DayAmounts: Array(repeating: 0, count: 7),
                currencyCode: CurrencyDefaults.code
            )
        }
    }
}

struct TodaySpendingWidget: Widget {
    let kind = "VittoraTodaySpendingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaySpendingTimelineProvider()) { entry in
            TodaySpendingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "Today's Spending"))
        .description(String(localized: "See how much you've spent today."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodaySpendingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsContainerBackground
    let entry: TodaySpendingEntry

    /// StandBy / distance layouts omit the standard container — bump amount size.
    private var isStandByContext: Bool { !showsContainerBackground }

    private var usesAccentedRendering: Bool { renderingMode == .accented }

    private var amountFont: Font {
        if isStandByContext && family == .systemSmall {
            return WidgetTypography.titleStandBy
        }
        return WidgetTypography.title
    }

    private var amountColor: Color {
        usesAccentedRendering ? WidgetColors.textPrimary : WidgetColors.expense
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumContent
            default:
                smallContent
            }
        }
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Today"))
                .font(WidgetTypography.caption)
                .foregroundStyle(WidgetColors.textSecondary)
            Text(formatted(entry.snapshot.todayAmount))
                .font(amountFont)
                .foregroundStyle(amountColor)
                .widgetAccentable(usesAccentedRendering)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            trendLabel
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }

    private var mediumContent: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Today's Spending"))
                    .font(WidgetTypography.caption)
                    .foregroundStyle(WidgetColors.textSecondary)
                Text(formatted(entry.snapshot.todayAmount))
                    .font(isStandByContext ? WidgetTypography.titleStandBy : WidgetTypography.title)
                    .foregroundStyle(amountColor)
                    .widgetAccentable(usesAccentedRendering)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                trendLabel
                Spacer(minLength: 0)
                addExpenseLink
            }
            sparkline
                .frame(maxWidth: .infinity)
        }
        .padding()
    }

    /// W4: opens the app straight into quick entry via the `vittora://add` link.
    /// Medium only — the small family has no room for it.
    private var addExpenseLink: some View {
        Link(destination: QuickAddDeepLink.url(for: .expense)) {
            Label(String(localized: "Add expense"), systemImage: "plus.circle.fill")
                .font(WidgetTypography.caption)
                .foregroundStyle(WidgetColors.primary)
        }
        .accessibilityLabel(String(localized: "Add expense"))
    }

    @ViewBuilder
    private var trendLabel: some View {
        if let percent = entry.snapshot.changePercentVsYesterday {
            let up = percent > 0
            let flat = abs(percent) < 0.05
            HStack(spacing: 2) {
                Image(systemName: flat ? "minus" : (up ? "arrow.up" : "arrow.down"))
                    .font(.caption2)
                Text(String(format: "%.0f%%", abs(percent)))
                    .font(WidgetTypography.caption2)
            }
            .foregroundStyle(
                usesAccentedRendering
                    ? WidgetColors.textSecondary
                    : (flat ? WidgetColors.textSecondary : (up ? WidgetColors.expense : WidgetColors.income))
            )
        }
    }

    private var sparkline: some View {
        let amounts = entry.snapshot.last7DayAmounts
        let maxAmount = amounts.max() ?? 0
        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(amounts.enumerated()), id: \.offset) { index, amount in
                let height = sparkHeight(amount: amount, maxAmount: maxAmount)
                let isToday = index == amounts.count - 1
                Capsule()
                    .fill(
                        usesAccentedRendering
                            ? (isToday ? WidgetColors.textPrimary : WidgetColors.textSecondary.opacity(0.45))
                            : (isToday ? WidgetColors.expense : WidgetColors.primary.opacity(0.45))
                    )
                    .widgetAccentable(usesAccentedRendering && isToday)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
            }
        }
        .frame(height: 56, alignment: .bottom)
        .accessibilityLabel(String(localized: "Seven-day spending"))
    }

    private func sparkHeight(amount: Decimal, maxAmount: Decimal) -> CGFloat {
        guard maxAmount > 0 else { return 4 }
        let ratio = CGFloat(truncating: (amount / maxAmount) as NSDecimalNumber)
        return max(4, 56 * ratio)
    }

    private func formatted(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: entry.snapshot.currencyCode))
    }
}

#if DEBUG
#Preview(as: .systemSmall) {
    TodaySpendingWidget()
} timeline: {
    TodaySpendingEntry.placeholder
}

#Preview(as: .systemMedium) {
    TodaySpendingWidget()
} timeline: {
    TodaySpendingEntry.placeholder
}
#endif
