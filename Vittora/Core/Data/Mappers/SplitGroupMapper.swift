import Foundation

enum SplitGroupMapper {
    nonisolated static func toEntity(_ model: SDSplitGroup) -> SplitGroup {
        SplitGroup(
            id: model.id,
            name: model.name,
            memberIDs: model.memberIDs,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    nonisolated static func updateModel(_ model: SDSplitGroup, from entity: SplitGroup) {
        model.name = entity.name
        model.memberIDs = entity.memberIDs
        model.updatedAt = .now
    }
}

enum GroupExpenseMapper {
    nonisolated static func toEntity(_ model: SDGroupExpense) -> GroupExpense {
        GroupExpense(
            id: model.id,
            groupID: model.groupID,
            paidByMemberID: model.paidByMemberID,
            amount: model.amount,
            title: model.title,
            date: model.date,
            splitMethod: model.splitMethod,
            shares: model.shares,
            categoryID: model.categoryID,
            note: model.note,
            isSettled: model.isSettled,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    nonisolated static func updateModel(_ model: SDGroupExpense, from entity: GroupExpense) {
        model.groupID = entity.groupID
        model.paidByMemberID = entity.paidByMemberID
        model.amount = entity.amount
        model.title = entity.title
        model.date = entity.date
        model.splitMethod = entity.splitMethod
        model.shares = entity.shares
        model.categoryID = entity.categoryID
        model.note = entity.note
        model.isSettled = entity.isSettled
        model.updatedAt = .now
    }
}
