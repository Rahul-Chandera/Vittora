import Foundation

struct SaveSavingsGoalUseCase: Sendable {
    let savingsGoalRepository: any SavingsGoalRepository

    enum GoalError: LocalizedError {
        case nameTooShort
        case invalidTarget
        case negativeCurrentAmount

        var errorDescription: String? {
            switch self {
            case .nameTooShort:
                return String(localized: "Goal name must be at least 2 characters.")
            case .invalidTarget:
                return String(localized: "Target amount must be greater than zero.")
            case .negativeCurrentAmount:
                return String(localized: "Saved amount cannot be negative.")
            }
        }
    }

    func executeCreate(
        name: String,
        category: GoalCategory,
        targetAmount: Decimal,
        currentAmount: Decimal,
        targetDate: Date?,
        linkedAccountID: UUID?,
        note: String?,
        colorHex: String
    ) async throws -> SavingsGoalEntity {
        try validate(name: name, targetAmount: targetAmount, currentAmount: currentAmount)
        let goal = SavingsGoalEntity(
            name: name.trimmingCharacters(in: .whitespaces),
            category: category,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            targetDate: targetDate,
            linkedAccountID: linkedAccountID,
            note: note?.trimmingCharacters(in: .whitespaces),
            colorHex: colorHex
        )
        try await savingsGoalRepository.create(goal)
        return goal
    }

    func executeUpdate(_ goal: SavingsGoalEntity) async throws {
        try validate(name: goal.name, targetAmount: goal.targetAmount, currentAmount: goal.currentAmount)
        var updated = goal
        // Auto-mark achieved if fully funded
        if updated.currentAmount >= updated.targetAmount && updated.status == .active {
            updated.status = .achieved
        }
        try await savingsGoalRepository.update(updated)
    }

    func executeAddContribution(goalID: UUID, amount: Decimal) async throws -> SavingsGoalEntity {
        guard var goal = try await savingsGoalRepository.fetchByID(goalID) else {
            throw VittoraError.notFound(String(localized: "Savings goal not found"))
        }
        guard amount > 0 else {
            throw GoalError.negativeCurrentAmount
        }
        goal.currentAmount += amount
        if goal.currentAmount >= goal.targetAmount {
            goal.status = .achieved
        }
        try await savingsGoalRepository.update(goal)
        return goal
    }

    // MARK: - Validation

    private func validate(name: String, targetAmount: Decimal, currentAmount: Decimal) throws {
        guard name.trimmingCharacters(in: .whitespaces).count >= 2 else { throw GoalError.nameTooShort }
        guard targetAmount > 0 else { throw GoalError.invalidTarget }
        guard currentAmount >= 0 else { throw GoalError.negativeCurrentAmount }
    }
}
