import WidgetKit
import SwiftUI
import AppIntents
import VittoraCore

struct QuickLogEntryTimeline: TimelineEntry {
    let date: Date
    let presets: [(amount: Decimal, label: String, categoryID: UUID?)]
    let pendingCount: Int
    let currencyCode: String

    static var placeholder: QuickLogEntryTimeline {
        QuickLogEntryTimeline(
            date: .now,
            presets: [
                (120, "Coffee", nil),
                (60, "Commute", nil),
            ],
            pendingCount: 0,
            currencyCode: "USD"
        )
    }
}

struct QuickLogTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuickLogEntryTimeline { .placeholder }

    func snapshot(for configuration: QuickLogConfigurationIntent, in context: Context) async -> QuickLogEntryTimeline {
        context.isPreview ? .placeholder : await entry(for: configuration)
    }

    func timeline(for configuration: QuickLogConfigurationIntent, in context: Context) async -> Timeline<QuickLogEntryTimeline> {
        // .never: nothing here changes on a schedule. The only thing that moves the
        // pending count is a tap, and the intent reloads the timeline itself.
        Timeline(entries: [await entry(for: configuration)], policy: .never)
    }

    private func entry(for configuration: QuickLogConfigurationIntent) async -> QuickLogEntryTimeline {
        let presets = configuration.configuredPresets.map { preset in
            (
                amount: preset.amount,
                label: preset.category?.name ?? String(localized: "Expense"),
                categoryID: preset.category?.id
            )
        }
        return QuickLogEntryTimeline(
            date: .now,
            presets: presets,
            pendingCount: QuickLogQueue()?.pendingCount ?? 0,
            currencyCode: CurrencyDefaults.code
        )
    }
}

struct QuickLogWidgetView: View {
    let entry: QuickLogEntryTimeline

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entry.presets.isEmpty {
                // Configuring is the only way to make this widget useful, so say so rather
                // than showing an empty frame the user cannot interpret.
                Text("Quick Log")
                    .font(.headline)
                Text("Touch and hold, then Edit Widget to choose the expenses you log most.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(entry.presets.enumerated()), id: \.offset) { _, preset in
                    Button(intent: LogPresetExpenseIntent(
                        amount: preset.amount,
                        categoryID: preset.categoryID,
                        note: nil
                    )) {
                        HStack {
                            Text(preset.label)
                                .lineLimit(1)
                            Spacer()
                            Text(preset.amount.formatted(.currency(code: entry.currencyCode)))
                                .monospacedDigit()
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }

                if entry.pendingCount > 0 {
                    // Honest about the hand-off: the tap is captured, the ledger entry
                    // appears when the app next runs. Claiming it was "saved" would be a
                    // lie the user discovers later.
                    Text("^[\(entry.pendingCount) tap](inflect: true) waiting for Vittora to open")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct QuickLogWidget: Widget {
    nonisolated static let kind = "QuickLogWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: QuickLogConfigurationIntent.self,
            provider: QuickLogTimelineProvider()
        ) { entry in
            QuickLogWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Log")
        .description("Log the expenses you repeat most, without opening the app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
