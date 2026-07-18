import WidgetKit
import SwiftUI
import VittoraCore

struct PlaceholderEntry: TimelineEntry {
    let date: Date
    let todaySpendingText: String
}

struct PlaceholderTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(
            date: .now,
            todaySpendingText: String(localized: "—")
        )
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (PlaceholderEntry) -> Void) {
        Task {
            let entry = await Self.loadEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<PlaceholderEntry>) -> Void) {
        Task {
            let entry = await Self.loadEntry()
            let nextUpdate = Date.now.addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private static func loadEntry() async -> PlaceholderEntry {
        do {
            let provider = try WidgetDataProvider.makeSharedReadOnly()
            let spending = try await provider.todaySpending()
            let text = spending.amount.formatted(.currency(code: spending.currencyCode))
            return PlaceholderEntry(date: .now, todaySpendingText: text)
        } catch {
            return PlaceholderEntry(
                date: .now,
                todaySpendingText: String(localized: "—")
            )
        }
    }
}

struct PlaceholderWidget: Widget {
    let kind = "VittoraPlaceholderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderTimelineProvider()) { entry in
            PlaceholderWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "Vittora"))
        .description(String(localized: "Today's spending at a glance."))
        .supportedFamilies([.systemSmall])
    }
}

struct PlaceholderWidgetView: View {
    let entry: PlaceholderEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Vittora"))
                .font(.headline)
            Text(String(localized: "Today"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.todaySpendingText)
                .font(.title2.weight(.semibold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }
}

#if DEBUG
#Preview(as: .systemSmall) {
    PlaceholderWidget()
} timeline: {
    PlaceholderEntry(date: .now, todaySpendingText: "$42.00")
}
#endif
