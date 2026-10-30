import AppIntents
import Foundation
import VittoraCore

/// Logs an expense without opening Vittora, so a Shortcuts automation can do it: an
/// Apple Pay tap (the Wallet "Transaction" trigger passes amount and merchant), a bank
/// message, the Action button, or Siri.
///
/// The expense goes through `QuickLogQueue`, like a widget tap, and the app books it the
/// next time it runs, or straight away if it is already open. The app stays the only
/// writer of the ledger.
struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource { "Log Expense" }
    static var description: IntentDescription {
        IntentDescription("Log an expense without opening Vittora. Use it in a Shortcuts automation, for example one that runs when you tap to pay.")
    }
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Amount")
    var amount: IntentCurrencyAmount

    @Parameter(title: "Payee or Merchant")
    var payee: String?

    @Parameter(title: "Category")
    var category: ExpenseCategoryEntity?

    @Parameter(title: "Paid With")
    var paidWith: IntentPaymentMethod?

    @Parameter(title: "Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) at \(\.$payee)") {
            \.$category
            \.$paidWith
            \.$note
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let entry = QuickLogEntry(
            amount: amount.amount,
            categoryID: category?.id,
            note: note.trimmedNonEmpty,
            payeeName: payee.trimmedNonEmpty,
            currencyCode: amount.currencyCode,
            paymentMethod: paidWith?.paymentMethod.rawValue
        )
        return .result(dialog: await QuickLogIntentSupport.enqueue(entry))
    }
}

/// Reads a bank, card or UPI debit alert on the device and logs the amount spent.
///
/// Vittora never reads messages. The text arrives only when the user builds a Shortcuts
/// automation ("When I get a message from my bank…") and passes the message in.
struct LogExpenseFromMessageIntent: AppIntent {
    static var title: LocalizedStringResource { "Log Expense from Message" }
    static var description: IntentDescription {
        IntentDescription("Reads a bank or UPI payment alert on your device and logs the amount spent. Credits, OTPs and upcoming payments are ignored.")
    }
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Message", inputOptions: String.IntentInputOptions(multiline: true))
    var message: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log the expense in \(\.$message)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let debit = BankMessageParser.parseDebit(message) else {
            return .result(dialog: IntentDialog("That message isn't a payment, so nothing was logged."))
        }
        let entry = QuickLogEntry(
            amount: debit.amount,
            payeeName: debit.merchant,
            currencyCode: debit.currencyCode,
            paymentMethod: debit.paymentMethod?.rawValue
        )
        return .result(dialog: await QuickLogIntentSupport.enqueue(entry))
    }
}

enum QuickLogIntentSupport {
    /// Queues the entry and returns what to tell the user.
    static func enqueue(_ entry: QuickLogEntry) async -> IntentDialog {
        guard entry.amount > 0 else {
            return IntentDialog("Enter an amount greater than zero.")
        }
        guard let queue = QuickLogQueue(), queue.enqueue(entry) else {
            return IntentDialog("Vittora couldn't save that expense. Try again.")
        }
        await MainActor.run {
            NotificationCenter.default.post(name: QuickLogQueue.didEnqueueNotification, object: nil)
        }
        let amount = CurrencyFormatter.format(entry.amount, currencyCode: entry.currencyCode ?? CurrencyDefaults.code)
        if let payee = entry.payeeName {
            return IntentDialog("Logged \(amount) at \(payee).")
        }
        return IntentDialog("Logged \(amount).")
    }
}

/// An expense category, read from the shared store read-only.
struct ExpenseCategoryEntity: AppEntity, Identifiable, Sendable {
    let id: UUID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Category")
    }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    static var defaultQuery: ExpenseCategoryQuery { ExpenseCategoryQuery() }
}

struct ExpenseCategoryQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ExpenseCategoryEntity] {
        await allCategories().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ExpenseCategoryEntity] {
        await allCategories()
    }

    /// Empty rather than throwing when there is no store yet, so the picker still opens.
    private func allCategories() async -> [ExpenseCategoryEntity] {
        guard let provider = try? WidgetDataProvider.makeSharedReadOnly(),
              let categories = try? await provider.expenseCategories()
        else { return [] }
        return categories.map { ExpenseCategoryEntity(id: $0.id, name: $0.name) }
    }
}

enum IntentPaymentMethod: String, AppEnum {
    case card, cash, upi, bankTransfer, wallet

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Payment Method")
    }
    static var caseDisplayRepresentations: [IntentPaymentMethod: DisplayRepresentation] {
        [
            .card: "Card",
            .cash: "Cash",
            .upi: "UPI",
            .bankTransfer: "Bank Transfer",
            .wallet: "Wallet",
        ]
    }

    /// "Card" books as a credit card: Apple Pay and card alerts rarely say which kind,
    /// and the transaction can be edited.
    var paymentMethod: PaymentMethod {
        switch self {
        case .card: .creditCard
        case .cash: .cash
        case .upi: .upi
        case .bankTransfer: .bankTransfer
        case .wallet: .wallet
        }
    }
}

private extension Optional where Wrapped == String {
    var trimmedNonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
