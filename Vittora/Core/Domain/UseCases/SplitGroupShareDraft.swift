import Foundation
import VittoraCore

/// User-initiated share copy for split groups (K3 / FUNCTIONAL-7).
/// Never sent automatically — only surfaced through ShareLink / share UI.
enum SplitGroupShareDraft {
    nonisolated static func inviteMessage(
        groupName: String,
        memberNames: [UUID: String],
        memberIDs: [UUID],
        balances: [MemberBalance],
        groupID: UUID,
        currencyCode: String
    ) -> String {
        let members = memberList(memberIDs: memberIDs, memberNames: memberNames)
        let balanceText = balanceSection(balances: balances, memberNames: memberNames, currencyCode: currencyCode)
        let link = SplitGroupDeepLink.url(for: groupID).absoluteString

        return String(
            localized:
            """
            You're invited to track shared expenses in "\(groupName)" on Vittora.

            Members: \(members)

            \(balanceText)

            Open in Vittora: \(link)
            """
        )
    }

    nonisolated static func summaryMessage(
        groupName: String,
        memberNames: [UUID: String],
        memberIDs: [UUID],
        balances: [MemberBalance],
        outstandingExpenses: [GroupExpense],
        currencyCode: String
    ) -> String {
        let members = memberList(memberIDs: memberIDs, memberNames: memberNames)
        let balanceText = balanceSection(balances: balances, memberNames: memberNames, currencyCode: currencyCode)
        let expenseText = expenseSection(expenses: outstandingExpenses, memberNames: memberNames, currencyCode: currencyCode)

        return String(
            localized:
            """
            Split summary for "\(groupName)"

            Members: \(members)

            \(balanceText)

            \(expenseText)
            """
        )
    }

    nonisolated private static func memberList(memberIDs: [UUID], memberNames: [UUID: String]) -> String {
        memberIDs
            .map { memberNames[$0] ?? String(localized: "Unknown") }
            .joined(separator: ", ")
    }

    nonisolated private static func balanceSection(
        balances: [MemberBalance],
        memberNames: [UUID: String],
        currencyCode: String
    ) -> String {
        guard !balances.isEmpty else {
            return String(localized: "Balances: All settled up!")
        }

        let lines = balances.map { balance in
            let from = memberNames[balance.fromMemberID] ?? String(localized: "Unknown")
            let to = memberNames[balance.toMemberID] ?? String(localized: "Unknown")
            let amount = balance.amount.formatted(.currency(code: currencyCode))
            return String(localized: "• \(from) owes \(to) \(amount)")
        }
        return String(localized: "Balances:") + "\n" + lines.joined(separator: "\n")
    }

    nonisolated private static func expenseSection(
        expenses: [GroupExpense],
        memberNames: [UUID: String],
        currencyCode: String
    ) -> String {
        guard !expenses.isEmpty else {
            return String(localized: "Outstanding expenses: None")
        }

        let lines = expenses.prefix(10).map { expense in
            let payer = memberNames[expense.paidByMemberID] ?? String(localized: "Unknown")
            let amount = expense.amount.formatted(.currency(code: currencyCode))
            let date = expense.date.formatted(date: .abbreviated, time: .omitted)
            return String(localized: "• \(expense.title) — \(amount) (\(payer), \(date))")
        }
        var section = String(localized: "Outstanding expenses:") + "\n" + lines.joined(separator: "\n")
        if expenses.count > 10 {
            section += "\n" + String(localized: "…and \(expenses.count - 10) more")
        }
        return section
    }
}
