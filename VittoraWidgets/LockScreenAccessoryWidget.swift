import WidgetKit
import SwiftUI
import VittoraCore

struct LockScreenAccessoryEntry: TimelineEntry {
    let date: Date
    let todaySpent: Decimal
    let budgetRemaining: Decimal
    let currencyCode: String
    let todaySpentText: String
    let budgetRemainingText: String
    let budgetUsedFraction: Double
    let budgetUsedPercentText: String
    let hasBudget: Bool

    static var placeholder: LockScreenAccessoryEntry {
        let currencyCode = "USD"
        let todaySpent = Decimal(string: "42.00") ?? 42
        let budgetRemaining = Decimal(string: "250.00") ?? 250
        return LockScreenAccessoryEntry(
            date: .now,
            todaySpent: todaySpent,
            budgetRemaining: budgetRemaining,
            currencyCode: currencyCode,
            todaySpentText: todaySpent.formatted(.currency(code: currencyCode)),
            budgetRemainingText: budgetRemaining.formatted(.currency(code: currencyCode)),
            budgetUsedFraction: 0.75,
            budgetUsedPercentText: "75%",
            hasBudget: true
        )
    }

    static var empty: LockScreenAccessoryEntry {
        let dash = String(localized: "—")
        let currencyCode = Locale.current.currency?.identifier ?? "USD"
        return LockScreenAccessoryEntry(
            date: .now,
            todaySpent: 0,
            budgetRemaining: 0,
            currencyCode: currencyCode,
            todaySpentText: dash,
            budgetRemainingText: dash,
            budgetUsedFraction: 0,
            budgetUsedPercentText: dash,
            hasBudget: false
        )
    }
}

struct LockScreenAccessoryTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenAccessoryEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (LockScreenAccessoryEntry) -> Void) {
        let isPreview = context.isPreview
        Task {
            if isPreview {
                completion(.placeholder)
                return
            }
            completion(await Self.loadEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<LockScreenAccessoryEntry>) -> Void) {
        Task {
            let entry = await Self.loadEntry()
            let nextUpdate = Date.now.addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private static func loadEntry() async -> LockScreenAccessoryEntry {
        do {
            let provider = try WidgetDataProvider.makeSharedReadOnly()
            let spending = try await provider.todaySpending()
            let budget = try await provider.budgetSnapshot()

            let spentText = spending.amount.formatted(.currency(code: spending.currencyCode))
            let remaining = max(budget.total - budget.spent, 0)
            let remainingText = remaining.formatted(.currency(code: budget.currencyCode))
            let hasBudget = budget.total > 0
            let fraction = Self.usedFraction(spent: budget.spent, total: budget.total)
            let percentText = hasBudget
                ? "\(Self.usedPercent(spent: budget.spent, total: budget.total))%"
                : String(localized: "—")

            return LockScreenAccessoryEntry(
                date: .now,
                todaySpent: spending.amount,
                budgetRemaining: remaining,
                currencyCode: spending.currencyCode,
                todaySpentText: spentText,
                budgetRemainingText: remainingText,
                budgetUsedFraction: fraction,
                budgetUsedPercentText: percentText,
                hasBudget: hasBudget
            )
        } catch {
            return .empty
        }
    }

    /// Ring fill in 0...1 (over-budget clamps to full).
    static func usedFraction(spent: Decimal, total: Decimal) -> Double {
        guard total > 0 else { return 0 }
        let raw = NSDecimalNumber(decimal: spent / total).doubleValue
        guard raw.isFinite else { return 0 }
        return min(max(raw, 0), 1)
    }

    /// Display percent (can exceed 100 when over budget).
    static func usedPercent(spent: Decimal, total: Decimal) -> Int {
        guard total > 0 else { return 0 }
        let raw = NSDecimalNumber(decimal: spent / total).doubleValue
        guard raw.isFinite else { return 0 }
        return Int((raw * 100).rounded())
    }
}

struct LockScreenAccessoryWidget: Widget {
    let kind = "VittoraLockScreenAccessoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenAccessoryTimelineProvider()) { entry in
            LockScreenAccessoryWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    AccessoryWidgetBackground()
                }
        }
        .configurationDisplayName(String(localized: "Vittora Lock Screen"))
        .description(String(localized: "Today's spending and budget progress on the Lock Screen."))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenAccessoryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.redactionReasons) private var redactionReasons
    let entry: LockScreenAccessoryEntry

    var body: some View {
        // System semantic styles only — hardcoded colors vanish in vibrant mode.
        switch family {
        case .accessoryCircular:
            circularContent
        case .accessoryRectangular:
            rectangularContent
        case .accessoryInline:
            inlineContent
        default:
            rectangularContent
        }
    }

    private var isPrivacyRedacted: Bool {
        redactionReasons.contains(.privacy)
    }

    /// Budget progress ring; label follows privacy redaction.
    private var circularContent: some View {
        Gauge(value: entry.budgetUsedFraction) {
            Text(String(localized: "Budget"))
        } currentValueLabel: {
            Text(entry.budgetUsedPercentText)
                .privacySensitive()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(circularAccessibilityLabel)
    }

    /// Today's spent + remaining, two lines.
    private var rectangularContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "Spent \(entry.todaySpentText) today"))
                .font(.headline)
                .privacySensitive()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if entry.hasBudget {
                Text(String(localized: "\(entry.budgetRemainingText) left"))
                    .font(.body)
                    .privacySensitive()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text(String(localized: "Set a budget"))
                    .font(.body)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spendingAccessibilityLabel)
    }

    private var inlineContent: some View {
        Text(String(localized: "Spent \(entry.todaySpentText) today"))
            .privacySensitive()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spendingAccessibilityLabel)
    }

    private var circularAccessibilityLabel: String {
        if isPrivacyRedacted {
            return WidgetAccessibilityLabels.lockScreenBudget
        }
        return WidgetAccessibilityLabels.budgetRemaining(
            amount: entry.budgetRemaining,
            progress: entry.budgetUsedFraction,
            currencyCode: entry.currencyCode
        )
    }

    private var spendingAccessibilityLabel: String {
        if isPrivacyRedacted {
            return WidgetAccessibilityLabels.lockScreenSpending
        }
        // Inline only shows today's spend; rectangular can include remaining.
        if family == .accessoryInline || !entry.hasBudget {
            return WidgetAccessibilityLabels.todaySpending(
                amount: entry.todaySpent,
                changePercentVsYesterday: nil,
                currencyCode: entry.currencyCode
            )
        }
        return WidgetAccessibilityLabels.todaySpendingAndBudgetRemaining(
            todayAmount: entry.todaySpent,
            remainingAmount: entry.budgetRemaining,
            progress: entry.budgetUsedFraction,
            currencyCode: entry.currencyCode
        )
    }
}

#if DEBUG
#Preview("Circular", as: .accessoryCircular) {
    LockScreenAccessoryWidget()
} timeline: {
    LockScreenAccessoryEntry.placeholder
}

#Preview("Rectangular", as: .accessoryRectangular) {
    LockScreenAccessoryWidget()
} timeline: {
    LockScreenAccessoryEntry.placeholder
}

#Preview("Inline", as: .accessoryInline) {
    LockScreenAccessoryWidget()
} timeline: {
    LockScreenAccessoryEntry.placeholder
}
#endif
