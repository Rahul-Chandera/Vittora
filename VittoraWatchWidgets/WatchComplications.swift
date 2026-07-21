import SwiftUI
import VittoraCore
import WidgetKit

struct WatchComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchSnapshot?
    let isPlaceholder: Bool

    var currentSnapshot: WatchSnapshot? {
        guard let snapshot, !snapshot.isStale(at: date) else { return nil }
        return snapshot
    }

    var relevance: TimelineEntryRelevance? {
        guard currentSnapshot != nil else { return nil }
        return TimelineEntryRelevance(score: 100, duration: 60 * 60)
    }

    static var placeholder: Self {
        Self(
            date: .now,
            snapshot: WatchSnapshot(
                todaySpend: 42,
                budgetSpent: 250,
                budgetTotal: 1_000,
                recentTransactions: [],
                currencyCode: "USD"
            ),
            isPlaceholder: true
        )
    }
}

struct WatchComplicationTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchComplicationEntry {
        .placeholder
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping @Sendable (WatchComplicationEntry) -> Void
    ) {
        completion(context.isPreview ? .placeholder : Self.entry(at: .now))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping @Sendable (Timeline<WatchComplicationEntry>) -> Void
    ) {
        let now = Date.now
        let snapshot = (try? WatchSnapshotCache.watchAppGroup())?.load()
        let entries = WidgetTimelineDates.entryDates(now: now).map {
            WatchComplicationEntry(date: $0, snapshot: snapshot, isPlaceholder: false)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private static func entry(at date: Date) -> WatchComplicationEntry {
        WatchComplicationEntry(
            date: date,
            snapshot: (try? WatchSnapshotCache.watchAppGroup())?.load(),
            isPlaceholder: false
        )
    }
}

struct VittoraWatchComplication: Widget {
    let kind = "VittoraWatchComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchComplicationTimelineProvider()) { entry in
            WatchComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "Vittora spending"))
        .description(String(localized: "See today's spending and budget at a glance."))
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

private struct WatchComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchComplicationEntry

    var body: some View {
        Group {
            if let snapshot = entry.currentSnapshot {
                content(for: snapshot)
            } else {
                unavailableContent
            }
        }
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }

    @ViewBuilder
    private func content(for snapshot: WatchSnapshot) -> some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: budgetProgress(snapshot)) {
                Text(String(localized: "Budget"))
            } currentValueLabel: {
                amount(snapshot.budgetRemaining, currencyCode: snapshot.currencyCode)
                    .font(.caption2)
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryCorner:
            amount(snapshot.todaySpend, currencyCode: snapshot.currencyCode)
                .font(.headline)
                .widgetLabel {
                    Label(String(localized: "Today"), systemImage: "creditcard")
                }
        case .accessoryInline:
            Text(
                "\(String(localized: "Today")) \(formatted(snapshot.todaySpend, snapshot.currencyCode)) · "
                    + "\(String(localized: "Left")) \(formatted(snapshot.budgetRemaining, snapshot.currencyCode))"
            )
            .privacySensitive()
        default:
            VStack(alignment: .leading, spacing: 2) {
                labeledAmount(
                    String(localized: "Today"),
                    snapshot.todaySpend,
                    currencyCode: snapshot.currencyCode
                )
                labeledAmount(
                    String(localized: "Budget left"),
                    snapshot.budgetRemaining,
                    currencyCode: snapshot.currencyCode
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var unavailableContent: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Text("—")
                    .font(.headline)
                Text(String(localized: "Open"))
                    .font(.caption2)
            }
        case .accessoryCorner:
            Text("—")
                .font(.headline)
                .widgetLabel {
                    Text(String(localized: "Open Vittora"))
                }
        case .accessoryInline:
            Text(String(localized: "— · Open Vittora"))
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text("—")
                    .font(.headline)
                Text(String(localized: "Open Vittora"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func labeledAmount(_ label: String, _ value: Decimal, currencyCode: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            amount(value, currencyCode: currencyCode)
                .fontWeight(.semibold)
        }
        .font(.caption)
    }

    private func amount(_ value: Decimal, currencyCode: String) -> some View {
        Text(formatted(value, currencyCode))
            .privacySensitive()
            .minimumScaleFactor(0.6)
            .lineLimit(1)
    }

    private func formatted(_ value: Decimal, _ currencyCode: String) -> String {
        value.formatted(.currency(code: currencyCode))
    }

    private func budgetProgress(_ snapshot: WatchSnapshot) -> Double {
        guard snapshot.budgetTotal > 0 else { return 0 }
        let ratio = Double(truncating: (snapshot.budgetSpent / snapshot.budgetTotal) as NSDecimalNumber)
        return min(max(ratio, 0), 1)
    }
}

#if DEBUG
#Preview(as: .accessoryRectangular) {
    VittoraWatchComplication()
} timeline: {
    WatchComplicationEntry.placeholder
}
#endif
