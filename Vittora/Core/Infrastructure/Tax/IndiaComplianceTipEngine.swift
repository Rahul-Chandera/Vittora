import Foundation
import VittoraCore

struct IndiaComplianceTip: Identifiable, Sendable, Equatable {
    nonisolated var id: IndiaComplianceRuleID { ruleID }
    nonisolated let ruleID: IndiaComplianceRuleID
    nonisolated let statutorySource: String
    nonisolated let assessmentYear: String
    nonisolated let threshold: Decimal
    nonisolated let userFigure: Decimal
    nonisolated let title: String
    nonisolated let detail: String

    /// Combined user-facing body used for imperative-phrasing audits.
    nonisolated var advisoryText: String { "\(title)\n\(detail)" }
}

/// Pure evaluation of India compliance tips from the user's own records.
enum IndiaComplianceTipEngine {
    nonisolated private static let paisa = Decimal(sign: .plus, exponent: -2, significand: 1)

    struct Input: Sendable {
        nonisolated let country: TaxCountry
        nonisolated let financialYear: String
        nonisolated let incomeSourceType: IncomeSourceType
        nonisolated let annualIncome: Decimal
        nonisolated let transactions: [TransactionEntity]
        nonisolated let accountsByID: [UUID: AccountEntity]
        nonisolated let categoriesByID: [UUID: CategoryEntity]
        nonisolated let calendar: Calendar

        nonisolated init(
            country: TaxCountry,
            financialYear: String,
            incomeSourceType: IncomeSourceType,
            annualIncome: Decimal,
            transactions: [TransactionEntity],
            accountsByID: [UUID: AccountEntity],
            categoriesByID: [UUID: CategoryEntity],
            calendar: Calendar = Calendar(identifier: .gregorian)
        ) {
            self.country = country
            self.financialYear = financialYear
            self.incomeSourceType = incomeSourceType
            self.annualIncome = annualIncome
            self.transactions = transactions
            self.accountsByID = accountsByID
            self.categoriesByID = categoriesByID
            self.calendar = calendar
        }
    }

    nonisolated static func evaluate(_ input: Input) -> [IndiaComplianceTip] {
        guard input.country == .india else { return [] }

        var tips: [IndiaComplianceTip] = []

        if let tip = section269STTip(input: input) {
            tips.append(tip)
        }
        if let tip = section40A3Tip(input: input) {
            tips.append(tip)
        }
        if let tip = sftCashDepositTip(input: input) {
            tips.append(tip)
        }
        if let tip = gstRegistrationTip(input: input) {
            tips.append(tip)
        }
        if let tip = section194IBTip(input: input) {
            tips.append(tip)
        }

        return tips
    }

    // MARK: - §269ST

    nonisolated private static func section269STTip(input: Input) -> IndiaComplianceTip? {
        let rule = IndiaComplianceRules.section269ST
        let cashIncome = input.transactions.filter {
            $0.type == .income && $0.paymentMethod == .cash
        }

        var maxFigure: Decimal = 0

        for tx in cashIncome where rule.isTriggered(by: tx.amount) {
            maxFigure = max(maxFigure, tx.amount)
        }

        var dayPayeeTotals: [String: Decimal] = [:]
        for tx in cashIncome {
            guard let payeeID = tx.payeeID else { continue }
            let day = dayKey(for: tx.date, calendar: input.calendar)
            let key = "\(payeeID.uuidString)|\(day)"
            dayPayeeTotals[key, default: 0] += tx.amount
        }
        for total in dayPayeeTotals.values where rule.isTriggered(by: total) {
            maxFigure = max(maxFigure, total)
        }

        guard rule.isTriggered(by: maxFigure) else { return nil }

        let formattedUser = formatINR(maxFigure)
        let formattedThreshold = formatINR(rule.threshold)
        return IndiaComplianceTip(
            ruleID: rule.id,
            statutorySource: rule.statutorySource,
            assessmentYear: rule.assessmentYear,
            threshold: rule.threshold,
            userFigure: maxFigure,
            title: String(localized: "Cash receipt limit (Section 269ST)"),
            detail: String(
                localized: "Recorded cash receipts of \(formattedUser) from one person in a day meet or exceed the \(formattedThreshold) statutory limit on receiving cash in aggregate from one person in a day."
            )
        )
    }

    // MARK: - §40A(3)

    nonisolated private static func section40A3Tip(input: Input) -> IndiaComplianceTip? {
        guard input.incomeSourceType == .selfEmployed else { return nil }

        let rule = IndiaComplianceRules.section40A3
        let cashExpenses = input.transactions.filter {
            $0.type == .expense && $0.paymentMethod == .cash
        }

        var dayTotals: [String: Decimal] = [:]
        for tx in cashExpenses {
            let key = dayKey(for: tx.date, calendar: input.calendar)
            dayTotals[key, default: 0] += tx.amount
        }

        let maxFigure = dayTotals.values.max() ?? 0
        guard rule.isTriggered(by: maxFigure) else { return nil }

        let formattedUser = formatINR(maxFigure)
        let formattedThreshold = formatINR(rule.threshold)
        return IndiaComplianceTip(
            ruleID: rule.id,
            statutorySource: rule.statutorySource,
            assessmentYear: rule.assessmentYear,
            threshold: rule.threshold,
            userFigure: maxFigure,
            title: String(localized: "Cash business expense (Section 40A(3))"),
            detail: String(
                localized: "Recorded cash business expenses of \(formattedUser) in a day exceed the \(formattedThreshold) threshold under which cash expenditure is not allowed as a deduction."
            )
        )
    }

    // MARK: - SFT

    nonisolated private static func sftCashDepositTip(input: Input) -> IndiaComplianceTip? {
        let deposits = cashDepositsByAccountKind(input: input)
        let savingsRule = IndiaComplianceRules.sftSavingsDeposit
        let currentRule = IndiaComplianceRules.sftCurrentDeposit

        if currentRule.isTriggered(by: deposits.current) {
            let formattedUser = formatINR(deposits.current)
            let formattedThreshold = formatINR(currentRule.threshold)
            return IndiaComplianceTip(
                ruleID: .sftCashDeposit,
                statutorySource: currentRule.statutorySource,
                assessmentYear: currentRule.assessmentYear,
                threshold: currentRule.threshold,
                userFigure: deposits.current,
                title: String(localized: "Large cash deposit reporting (SFT)"),
                detail: String(
                    localized: "Recorded cash deposits of \(formattedUser) into current accounts in this financial year meet or exceed the \(formattedThreshold) SFT reporting threshold for current accounts."
                )
            )
        }

        if savingsRule.isTriggered(by: deposits.savings) {
            let formattedUser = formatINR(deposits.savings)
            let formattedThreshold = formatINR(savingsRule.threshold)
            return IndiaComplianceTip(
                ruleID: .sftCashDeposit,
                statutorySource: savingsRule.statutorySource,
                assessmentYear: savingsRule.assessmentYear,
                threshold: savingsRule.threshold,
                userFigure: deposits.savings,
                title: String(localized: "Large cash deposit reporting (SFT)"),
                detail: String(
                    localized: "Recorded cash deposits of \(formattedUser) into savings accounts in this financial year meet or exceed the \(formattedThreshold) SFT reporting threshold for savings accounts."
                )
            )
        }

        return nil
    }

    nonisolated private static func cashDepositsByAccountKind(
        input: Input
    ) -> (savings: Decimal, current: Decimal) {
        var savings: Decimal = 0
        var current: Decimal = 0

        func addDeposit(accountID: UUID?, amount: Decimal) {
            guard let accountID, let account = input.accountsByID[accountID], account.type == .bank else {
                return
            }
            if isCurrentAccount(account) {
                current += amount
            } else {
                savings += amount
            }
        }

        for tx in input.transactions where tx.type == .income && tx.paymentMethod == .cash {
            addDeposit(accountID: tx.accountID, amount: tx.amount)
        }

        var legsByPair: [UUID: [TransactionEntity]] = [:]
        for tx in input.transactions where tx.type == .transfer {
            guard let pairID = tx.transferPairID else { continue }
            legsByPair[pairID, default: []].append(tx)
        }
        for legs in legsByPair.values {
            guard let credit = legs.first(where: { $0.transferDirection == .credit }),
                  let debit = legs.first(where: { $0.transferDirection == .debit }),
                  let debitAccountID = debit.accountID,
                  let debitAccount = input.accountsByID[debitAccountID],
                  debitAccount.type == .cash
            else {
                continue
            }
            addDeposit(accountID: credit.accountID, amount: credit.amount)
        }

        return (savings, current)
    }

    nonisolated private static func isCurrentAccount(_ account: AccountEntity) -> Bool {
        account.name.localizedCaseInsensitiveContains("current")
    }

    // MARK: - GST

    nonisolated private static func gstRegistrationTip(input: Input) -> IndiaComplianceTip? {
        guard input.incomeSourceType == .selfEmployed else { return nil }

        let rule = IndiaComplianceRules.gstServicesGeneral
        let recordedIncome = input.transactions
            .filter { $0.type == .income }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let turnover = recordedIncome > 0 ? recordedIncome : input.annualIncome
        guard rule.isTriggered(by: turnover) else { return nil }

        let formattedUser = formatINR(turnover)
        let formattedServices = formatINR(rule.threshold)
        let formattedGoods = formatINR(IndiaComplianceRules.gstGoodsGeneralThreshold)
        let formattedSpecialServices = formatINR(IndiaComplianceRules.gstServicesSpecialCategoryThreshold)
        let formattedSpecialGoods = formatINR(IndiaComplianceRules.gstGoodsSpecialCategoryThreshold)

        return IndiaComplianceTip(
            ruleID: rule.id,
            statutorySource: rule.statutorySource,
            assessmentYear: rule.assessmentYear,
            threshold: rule.threshold,
            userFigure: turnover,
            title: String(localized: "GST registration threshold"),
            detail: String(
                localized: "Recorded annual turnover of \(formattedUser) exceeds the \(formattedServices) GST registration threshold for services (goods: \(formattedGoods); special-category states: services \(formattedSpecialServices) / goods \(formattedSpecialGoods))."
            )
        )
    }

    // MARK: - §194-IB

    nonisolated private static func section194IBTip(input: Input) -> IndiaComplianceTip? {
        let rule = IndiaComplianceRules.section194IB
        let rentCategoryIDs = Set(
            input.categoriesByID.values
                .filter { $0.name.compare("Rent", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
                .map(\.id)
        )
        guard !rentCategoryIDs.isEmpty else { return nil }

        var monthTotals: [String: Decimal] = [:]
        for tx in input.transactions where tx.type == .expense {
            guard let categoryID = tx.categoryID, rentCategoryIDs.contains(categoryID) else { continue }
            let key = monthKey(for: tx.date, calendar: input.calendar)
            monthTotals[key, default: 0] += tx.amount
        }

        let maxFigure = monthTotals.values.max() ?? 0
        guard rule.isTriggered(by: maxFigure) else { return nil }

        let formattedUser = formatINR(maxFigure)
        let formattedThreshold = formatINR(rule.threshold)
        return IndiaComplianceTip(
            ruleID: rule.id,
            statutorySource: rule.statutorySource,
            assessmentYear: rule.assessmentYear,
            threshold: rule.threshold,
            userFigure: maxFigure,
            title: String(localized: "TDS on rent (Section 194-IB)"),
            detail: String(
                localized: "Recorded rent of \(formattedUser) in a month exceeds the \(formattedThreshold) monthly threshold at which tax is deductible at source on rent paid by an individual."
            )
        )
    }

    // MARK: - Helpers

    nonisolated private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    nonisolated private static func monthKey(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)"
    }

    nonisolated private static func formatINR(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "INR"))
    }

    /// Exposed for boundary tests that need one-paisa offsets without float literals.
    nonisolated static func amountByAddingPaisa(_ amount: Decimal, paisaDelta: Int) -> Decimal {
        amount + (paisa * Decimal(paisaDelta))
    }
}
