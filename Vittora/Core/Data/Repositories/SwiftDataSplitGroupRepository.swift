import Foundation
import SwiftData

@ModelActor
actor SwiftDataSplitGroupRepository: SplitGroupRepository {

    // MARK: - Groups

    func fetchAllGroups() async throws -> [SplitGroup] {
        let descriptor = FetchDescriptor<SDSplitGroup>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(SplitGroupMapper.toEntity)
    }

    func fetchGroupByID(_ id: UUID) async throws -> SplitGroup? {
        let descriptor = FetchDescriptor<SDSplitGroup>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first.map(SplitGroupMapper.toEntity)
    }

    func createGroup(_ group: SplitGroup) async throws {
        let model = SDSplitGroup(
            id: group.id,
            name: group.name,
            memberIDs: group.memberIDs,
            createdAt: group.createdAt,
            updatedAt: group.updatedAt
        )
        modelContext.insert(model)
        try modelContext.save()
    }

    func updateGroup(_ group: SplitGroup) async throws {
        let id = group.id
        let descriptor = FetchDescriptor<SDSplitGroup>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Split group not found"))
        }
        SplitGroupMapper.updateModel(model, from: group)
        try modelContext.save()
    }

    func deleteGroup(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDSplitGroup>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Split group not found"))
        }
        // Delete all expenses for this group first
        let expenseDescriptor = FetchDescriptor<SDGroupExpense>(
            predicate: #Predicate { $0.groupID == id }
        )
        let expenses = try modelContext.fetch(expenseDescriptor)
        for expense in expenses {
            modelContext.delete(expense)
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    // MARK: - Expenses

    func fetchExpenses(forGroup groupID: UUID) async throws -> [GroupExpense] {
        let descriptor = FetchDescriptor<SDGroupExpense>(
            predicate: #Predicate { $0.groupID == groupID },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(GroupExpenseMapper.toEntity)
    }

    func fetchExpenseByID(_ id: UUID) async throws -> GroupExpense? {
        let descriptor = FetchDescriptor<SDGroupExpense>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first.map(GroupExpenseMapper.toEntity)
    }

    func createExpense(_ expense: GroupExpense) async throws {
        let model = SDGroupExpense(
            id: expense.id,
            groupID: expense.groupID,
            paidByMemberID: expense.paidByMemberID,
            amount: expense.amount,
            title: expense.title,
            date: expense.date,
            splitMethod: expense.splitMethod,
            shares: expense.shares,
            categoryID: expense.categoryID,
            note: expense.note,
            isSettled: expense.isSettled,
            createdAt: expense.createdAt,
            updatedAt: expense.updatedAt
        )
        modelContext.insert(model)
        try modelContext.save()
    }

    func updateExpense(_ expense: GroupExpense) async throws {
        let id = expense.id
        let descriptor = FetchDescriptor<SDGroupExpense>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Group expense not found"))
        }
        GroupExpenseMapper.updateModel(model, from: expense)
        try modelContext.save()
    }

    func deleteExpense(_ id: UUID) async throws {
        let descriptor = FetchDescriptor<SDGroupExpense>(
            predicate: #Predicate { $0.id == id }
        )
        guard let model = try modelContext.fetch(descriptor).first else {
            throw VittoraError.notFound(String(localized: "Group expense not found"))
        }
        modelContext.delete(model)
        try modelContext.save()
    }
}
