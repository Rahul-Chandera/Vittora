import Foundation

/// Per-member input row for a split expense form
struct MemberAllocationRow: Identifiable, Sendable {
    var id: UUID { memberID }
    let memberID: UUID
    let name: String
    /// User-entered value: percentage string, exact amount string, or shares string
    var inputValue: String = ""
    /// Computed allocation amount based on the current split method
    var calculatedAmount: Decimal = 0
}

@Observable
@MainActor
final class AddGroupExpenseViewModel {
    private let addExpenseUseCase: AddGroupExpenseUseCase
    let group: SplitGroup
    let memberNames: [UUID: String]

    // Form state
    var title = ""
    var amountString = ""
    var date = Date.now
    var selectedPayerID: UUID?
    var splitMethod: SplitMethod = .equal
    var allocations: [MemberAllocationRow] = []
    var note = ""
    var categoryID: UUID?

    var isSaving = false
    var error: String?

    var amount: Decimal { Decimal(string: amountString.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        amount > 0 &&
        selectedPayerID != nil
    }

    init(group: SplitGroup, memberNames: [UUID: String], addExpenseUseCase: AddGroupExpenseUseCase) {
        self.group = group
        self.memberNames = memberNames
        self.addExpenseUseCase = addExpenseUseCase
        self.selectedPayerID = group.memberIDs.first
        setupAllocations()
    }

    private func setupAllocations() {
        allocations = group.memberIDs.map { id in
            MemberAllocationRow(
                memberID: id,
                name: memberNames[id] ?? String(localized: "Unknown")
            )
        }
        recalculate()
    }

    func recalculate() {
        guard amount > 0, !allocations.isEmpty else {
            for i in allocations.indices { allocations[i].calculatedAmount = 0 }
            return
        }

        let count = allocations.count
        switch splitMethod {
        case .equal:
            let share = (amount / Decimal(count)).rounded(scale: 2)
            for i in allocations.indices {
                if i < count - 1 {
                    allocations[i].calculatedAmount = share
                } else {
                    allocations[i].calculatedAmount = amount - share * Decimal(count - 1)
                }
            }

        case .percentage:
            for i in allocations.indices {
                let pct = Decimal(string: allocations[i].inputValue) ?? (100 / Decimal(count))
                allocations[i].calculatedAmount = (amount * pct / 100).rounded(scale: 2)
            }

        case .exact:
            for i in allocations.indices {
                allocations[i].calculatedAmount = Decimal(string: allocations[i].inputValue.replacingOccurrences(of: ",", with: ".")) ?? 0
            }

        case .shares:
            let weights = allocations.map { Decimal(string: $0.inputValue) ?? 1 }
            let total = weights.reduce(Decimal(0), +)
            guard total > 0 else { return }
            for i in allocations.indices {
                if i < count - 1 {
                    allocations[i].calculatedAmount = (amount * weights[i] / total).rounded(scale: 2)
                } else {
                    let allocated = allocations.dropLast().reduce(Decimal(0)) { $0 + $1.calculatedAmount }
                    allocations[i].calculatedAmount = amount - allocated
                }
            }
        }
    }

    func save() async -> Bool {
        guard canSave, let payerID = selectedPayerID else { return false }
        isSaving = true
        error = nil

        var customValues: [UUID: Decimal] = [:]
        for row in allocations {
            switch splitMethod {
            case .equal: break
            case .percentage:
                customValues[row.memberID] = Decimal(string: row.inputValue) ?? (100 / Decimal(allocations.count))
            case .exact:
                customValues[row.memberID] = Decimal(string: row.inputValue.replacingOccurrences(of: ",", with: ".")) ?? 0
            case .shares:
                customValues[row.memberID] = Decimal(string: row.inputValue) ?? 1
            }
        }

        do {
            _ = try await addExpenseUseCase.execute(
                groupID: group.id,
                paidByMemberID: payerID,
                amount: amount,
                title: title,
                date: date,
                splitMethod: splitMethod,
                memberIDs: group.memberIDs,
                customValues: customValues,
                categoryID: categoryID,
                note: note.isEmpty ? nil : note
            )
            isSaving = false
            return true
        } catch {
            self.error = error.localizedDescription
            isSaving = false
            return false
        }
    }
}

private extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var result = Decimal()
        var copy = self
        NSDecimalRound(&result, &copy, scale, .bankers)
        return result
    }
}
