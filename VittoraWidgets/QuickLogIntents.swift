import AppIntents
import WidgetKit
import VittoraCore

/// A category as the widget configuration editor sees it (M2.7.5).
///
/// Read from the App Group store read-only, which is all an extension may do — the host
/// app owns writes and migrations.
struct CategoryAppEntity: AppEntity, Identifiable, Sendable {
    let id: UUID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Category")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery: CategoryEntityQuery { CategoryEntityQuery() }
}

struct CategoryEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CategoryAppEntity] {
        await allCategories().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CategoryAppEntity] {
        await allCategories()
    }

    /// Expense categories only: the preset logs an expense, so offering income ones would
    /// configure a button that books against the wrong side of the ledger.
    ///
    /// Returns empty rather than throwing when the store cannot be opened. That happens for
    /// real: adding the widget before ever launching the app means there is no store on
    /// disk yet, and a thrown error leaves the configuration picker dead — tapping it does
    /// nothing at all, with no way for the user to tell why. An empty list at least opens.
    private func allCategories() async -> [CategoryAppEntity] {
        guard let provider = try? WidgetDataProvider.makeSharedReadOnly(),
              let categories = try? await provider.expenseCategories()
        else { return [] }
        return categories.map { CategoryAppEntity(id: $0.id, name: $0.name) }
    }
}

/// One configured button: an amount, a category, and a label.
struct QuickLogPreset: AppEntity, Identifiable, Sendable {
    let id: String
    let label: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Preset")
    }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(label)") }
    static var defaultQuery: QuickLogPresetQuery { QuickLogPresetQuery() }
}

struct QuickLogPresetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [QuickLogPreset] { [] }
}

/// Records a tap. `openAppWhenRun` is false — that is the whole point: the expense is
/// captured without the app coming to the front. The queue is drained by the app later,
/// because the extension may not write the ledger.
struct LogPresetExpenseIntent: AppIntent {
    static var title: LocalizedStringResource { "Log Expense" }
    static var description: IntentDescription {
        IntentDescription("Record a preset expense without opening Vittora")
    }
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Category")
    var categoryID: String?

    @Parameter(title: "Note")
    var note: String?

    init() {}

    init(amount: Decimal, categoryID: UUID?, note: String?) {
        // Decimal to Double only at the AppIntents boundary, which has no Decimal
        // parameter type. Re-parsed via the string form below so the stored amount never
        // takes a binary floating point detour.
        self.amount = (amount as NSDecimalNumber).doubleValue
        self.categoryID = categoryID?.uuidString
        self.note = note
    }

    func perform() async throws -> some IntentResult {
        guard let queue = QuickLogQueue() else { return .result() }
        // String round-trip, not Decimal(double:): the latter carries the binary
        // representation of 0.1 into a money value.
        let decimalAmount = Decimal(string: String(amount)) ?? 0
        queue.enqueue(
            QuickLogEntry(
                amount: decimalAmount,
                categoryID: categoryID.flatMap(UUID.init(uuidString:)),
                note: note
            )
        )
        WidgetCenter.shared.reloadTimelines(ofKind: QuickLogWidget.kind)
        return .result()
    }
}

/// Widget configuration: up to three presets.
struct QuickLogConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Quick Log" }
    static var description: IntentDescription {
        IntentDescription("Choose the expenses you log most often")
    }

    // Optional, not `default: 0`. A default pre-fills the field with "0" and typing
    // appends to it, so entering 120 yields 0120 and the preset logs the wrong amount.
    // Optional leaves the field empty, which is also what "unused slot" should look like.
    @Parameter(title: "First amount")
    var firstAmount: Double?
    @Parameter(title: "First category")
    var firstCategory: CategoryAppEntity?

    @Parameter(title: "Second amount")
    var secondAmount: Double?
    @Parameter(title: "Second category")
    var secondCategory: CategoryAppEntity?

    @Parameter(title: "Third amount")
    var thirdAmount: Double?
    @Parameter(title: "Third category")
    var thirdCategory: CategoryAppEntity?

    /// Only the slots the user actually filled in. An amount of zero means "unused", so an
    /// unconfigured widget shows one hint rather than three dead buttons.
    var configuredPresets: [(amount: Decimal, category: CategoryAppEntity?)] {
        [
            (firstAmount, firstCategory),
            (secondAmount, secondCategory),
            (thirdAmount, thirdCategory),
        ]
        .compactMap { amount, category -> (Decimal, CategoryAppEntity?)? in
            guard let amount, amount > 0 else { return nil }
            return (Decimal(string: String(amount)) ?? 0, category)
        }
    }
}
