import SwiftUI
import VittoraCore

/// Voice entry (M2.6.2): say "500 for groceries" instead of turning the crown.
///
/// The text field opens watchOS's own input sheet, which offers dictation
/// first — there is no API to start dictation directly, and this is the path
/// Apple's own apps use. What comes back is parsed, shown for a glance, and
/// queued to the phone like any other watch expense.
struct WatchVoiceExpenseView: View {
    @Bindable var store: WatchSnapshotStore
    @Environment(\.dismiss) private var dismiss
    @State private var spoken: String

    init(store: WatchSnapshotStore, spoken: String = "") {
        self.store = store
        _spoken = State(initialValue: spoken)
    }

    private var currencyCode: String {
        store.snapshot?.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
    }

    private var parsed: WatchVoiceExpense? {
        spoken.isEmpty ? nil : WatchVoiceExpense.parse(spoken)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    TextField(String(localized: "Say “500 for groceries”"), text: $spoken)
                        .accessibilityIdentifier("watch-voice-field")

                    if let parsed {
                        if let amount = parsed.amount {
                            result(amount: amount, parsed: parsed)
                        } else {
                            Text(String(localized: "I didn't catch an amount. Try “500 for groceries”."))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle(String(localized: "Say It"))
        }
    }

    @ViewBuilder
    private func result(amount: Decimal, parsed: WatchVoiceExpense) -> some View {
        let category = store.localCategory(for: parsed)
        Text(amount, format: .currency(code: currencyCode))
            .font(.title3.weight(.semibold))
        if let category {
            Label(category.name, systemImage: category.icon)
                .font(.footnote)
        } else if !parsed.categoryPhrase.isEmpty {
            // Not among the watch's eight categories; the phone matches it
            // against all of them when it records the expense.
            Label(parsed.categoryPhrase.localizedCapitalized, systemImage: "tag")
                .font(.footnote)
        }

        Button(String(localized: "Queue expense")) {
            if store.enqueueVoiceExpense(amount: amount, parsed: parsed) { dismiss() }
        }
        .accessibilityIdentifier("watch-voice-queue-button")

        if category == nil, parsed.categoryPhrase.isEmpty, store.snapshot?.quickCategories.isEmpty == false {
            NavigationLink(String(localized: "Choose category")) {
                WatchCategoryGridView(store: store, amount: amount, onQueued: { dismiss() })
            }
        }
    }
}

extension WatchSnapshotStore {
    /// The watch's own category for what was said, when it has one.
    func localCategory(for parsed: WatchVoiceExpense) -> WatchSnapshotCategory? {
        WatchVoiceExpense.matchCategory(parsed.categoryPhrase, in: snapshot?.quickCategories ?? [], name: \.name)
    }

    /// Queues a spoken expense. A category the watch knows goes by ID; one it
    /// doesn't goes as the spoken words, for the phone to match.
    @discardableResult
    func enqueueVoiceExpense(amount: Decimal, parsed: WatchVoiceExpense) -> Bool {
        let category = localCategory(for: parsed)
        return enqueueExpense(
            amount: amount,
            categoryID: category?.id,
            categoryHint: category == nil && !parsed.categoryPhrase.isEmpty ? parsed.categoryPhrase : nil
        )
    }
}
