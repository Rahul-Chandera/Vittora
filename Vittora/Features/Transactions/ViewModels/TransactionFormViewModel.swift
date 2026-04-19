import Foundation

@Observable @MainActor final class TransactionFormViewModel {
    var amountString: String = ""
    var type: TransactionType = .expense
    var date: Date = .now
    var selectedCategoryID: UUID?
    var selectedAccountID: UUID?
    var selectedPayeeID: UUID?
    var note: String = ""
    var tags: [String] = []
    var tagInput: String = ""
    var paymentMethod: PaymentMethod = .cash
    var isQuickEntry: Bool = false
    var isEditing = false
    var editingID: UUID?
    var suggestedCategoryID: UUID?
    var duplicateWarning: [TransactionEntity] = []
    var isLoading = false
    var error: String?

    var amount: Decimal {
        Decimal(string: amountString) ?? 0
    }

    var canSave: Bool {
        amount > 0 && selectedAccountID != nil
    }

    private let addUseCase: AddTransactionUseCase
    private let updateUseCase: UpdateTransactionUseCase
    private let smartCategorizeUseCase: SmartCategorizeUseCase
    private let duplicateDetectionUseCase: DuplicateDetectionUseCase
    private let currencyCode: String

    init(
        addUseCase: AddTransactionUseCase,
        updateUseCase: UpdateTransactionUseCase,
        smartCategorizeUseCase: SmartCategorizeUseCase,
        duplicateDetectionUseCase: DuplicateDetectionUseCase,
        currencyCode: String = Locale.current.currency?.identifier ?? "USD"
    ) {
        self.addUseCase = addUseCase
        self.updateUseCase = updateUseCase
        self.smartCategorizeUseCase = smartCategorizeUseCase
        self.duplicateDetectionUseCase = duplicateDetectionUseCase
        self.currencyCode = currencyCode
    }

    func loadTransaction(_ entity: TransactionEntity) {
        isEditing = true
        editingID = entity.id
        amountString = "\(entity.amount)"
        type = entity.type
        date = entity.date
        selectedCategoryID = entity.categoryID
        selectedAccountID = entity.accountID
        selectedPayeeID = entity.payeeID
        note = entity.note ?? ""
        tags = entity.tags
        paymentMethod = entity.paymentMethod
    }

    func suggestCategory() async {
        guard selectedPayeeID != nil && amount > 0 else {
            suggestedCategoryID = nil
            return
        }

        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            suggestedCategoryID = try await smartCategorizeUseCase.execute(
                payeeID: selectedPayeeID,
                amount: amount
            )
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't suggest a category right now.")
            )
        }
    }

    func checkDuplicates() async {
        guard amount > 0, let accountID = selectedAccountID else {
            duplicateWarning = []
            return
        }

        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            duplicateWarning = try await duplicateDetectionUseCase.execute(
                amount: amount,
                date: date,
                payeeID: selectedPayeeID,
                accountID: accountID
            )
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't check for duplicate transactions right now.")
            )
        }
    }

    func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else {
            return
        }
        tags.append(trimmed)
        tagInput = ""
    }

    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    func save() async throws {
        guard canSave else {
            throw VittoraError.validationFailed(
                String(localized: "Amount must be greater than zero and an account must be selected.")
            )
        }

        guard let accountID = selectedAccountID else {
            throw VittoraError.validationFailed(String(localized: "An account is required."))
        }

        if isEditing, let editingID = editingID {
            // Update existing transaction
            var updated = TransactionEntity(
                id: editingID,
                amount: amount,
                date: date,
                note: note.isEmpty ? nil : note,
                type: type,
                paymentMethod: paymentMethod,
                currencyCode: currencyCode,
                tags: tags,
                categoryID: selectedCategoryID,
                accountID: accountID,
                payeeID: selectedPayeeID
            )
            updated.updatedAt = .now
            try await updateUseCase.execute(updated)
        } else {
            // Create new transaction
            _ = try await addUseCase.execute(
                amount: amount,
                type: type,
                date: date,
                categoryID: selectedCategoryID,
                accountID: accountID,
                payeeID: selectedPayeeID,
                note: note.isEmpty ? nil : note,
                tags: tags,
                paymentMethod: paymentMethod,
                currencyCode: currencyCode
            )
        }
    }
}
