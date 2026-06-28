import Foundation

@Observable
@MainActor
final class AccountFormViewModel {
    var name: String = ""
    var selectedType: AccountType = .bank
    var initialBalance: String = "0"
    var selectedCurrency: String = CurrencyDefaults.code
    var selectedIcon: String = "building.columns.fill"
    var statementDayOfMonth: Int?
    var dueDayOfMonth: Int?
    var isEditing = false
    var editingID: UUID?
    var validationErrors: [String] = []

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Decimal(localizedAmount: initialBalance) != nil)
    }

    private let createUseCase: CreateAccountUseCase
    private let updateUseCase: UpdateAccountUseCase
    private let repository: any AccountRepository

    init(
        createUseCase: CreateAccountUseCase,
        updateUseCase: UpdateAccountUseCase,
        repository: any AccountRepository
    ) {
        self.createUseCase = createUseCase
        self.updateUseCase = updateUseCase
        self.repository = repository
    }

    func loadAccount(_ entity: AccountEntity) {
        isEditing = true
        editingID = entity.id
        name = entity.name
        selectedType = entity.type
        initialBalance = "\(entity.balance)"
        selectedCurrency = entity.currencyCode
        selectedIcon = entity.icon
        statementDayOfMonth = entity.statementDayOfMonth
        dueDayOfMonth = entity.dueDayOfMonth
    }

    func save() async throws {
        validationErrors = []
        guard let balance = Decimal(localizedAmount: initialBalance) else {
            throw VittoraError.validationFailed(
                String(localized: "Please enter a valid opening balance.")
            )
        }

        if isEditing, let id = editingID {
            try await updateUseCase.execute(
                id: id,
                name: name,
                type: selectedType,
                balance: balance,
                currencyCode: selectedCurrency,
                icon: selectedIcon,
                statementDayOfMonth: selectedType == .creditCard ? statementDayOfMonth : nil,
                dueDayOfMonth: selectedType == .creditCard ? dueDayOfMonth : nil
            )
        } else {
            try await createUseCase.execute(
                name: name,
                type: selectedType,
                balance: balance,
                currencyCode: selectedCurrency,
                icon: selectedIcon,
                statementDayOfMonth: selectedType == .creditCard ? statementDayOfMonth : nil,
                dueDayOfMonth: selectedType == .creditCard ? dueDayOfMonth : nil
            )
        }
    }
}
