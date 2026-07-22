import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("India Compliance Tips")
struct IndiaComplianceTipsTests {

    private let calendar = Calendar(identifier: .gregorian)
    private let fy = "2025-26"

    // MARK: - §269ST boundaries (>= ₹2,00,000)

    @Test("§269ST triggers at exact ₹2,00,000, not one paisa below, and above")
    func section269STBoundaries() {
        let rule = IndiaComplianceRules.section269ST
        let threshold = rule.threshold
        let below = IndiaComplianceTipEngine.amountByAddingPaisa(threshold, paisaDelta: -1)
        let above = IndiaComplianceTipEngine.amountByAddingPaisa(threshold, paisaDelta: 1)

        #expect(rule.comparison == .greaterThanOrEqual)
        #expect(!rule.isTriggered(by: below))
        #expect(rule.isTriggered(by: threshold))
        #expect(rule.isTriggered(by: above))

        #expect(tips(for: cashIncome(amount: below)).contains { $0.ruleID == .section269ST } == false)
        #expect(tips(for: cashIncome(amount: threshold)).contains { $0.ruleID == .section269ST })
        #expect(tips(for: cashIncome(amount: above)).contains { $0.ruleID == .section269ST })
    }

    // MARK: - §40A(3) boundaries (> ₹10,000)

    @Test("§40A(3) triggers one paisa above ₹10,000, not at exact threshold")
    func section40A3Boundaries() {
        let rule = IndiaComplianceRules.section40A3
        let threshold = rule.threshold
        let below = IndiaComplianceTipEngine.amountByAddingPaisa(threshold, paisaDelta: -1)
        let above = IndiaComplianceTipEngine.amountByAddingPaisa(threshold, paisaDelta: 1)

        #expect(rule.comparison == .greaterThan)
        #expect(!rule.isTriggered(by: below))
        #expect(!rule.isTriggered(by: threshold))
        #expect(rule.isTriggered(by: above))

        #expect(tips(
            for: cashExpense(amount: threshold),
            incomeSourceType: .selfEmployed
        ).contains { $0.ruleID == .section40A3 } == false)
        #expect(tips(
            for: cashExpense(amount: above),
            incomeSourceType: .selfEmployed
        ).contains { $0.ruleID == .section40A3 })
        #expect(tips(
            for: cashExpense(amount: above),
            incomeSourceType: .salaried
        ).contains { $0.ruleID == .section40A3 } == false)
    }

    // MARK: - SFT boundaries (>=)

    @Test("SFT savings tip triggers at exact ₹10,00,000")
    func sftSavingsBoundaries() {
        let rule = IndiaComplianceRules.sftSavingsDeposit
        let threshold = rule.threshold
        let below = IndiaComplianceTipEngine.amountByAddingPaisa(threshold, paisaDelta: -1)
        let above = IndiaComplianceTipEngine.amountByAddingPaisa(threshold, paisaDelta: 1)
        let savings = AccountEntity(name: "Savings", type: .bank)

        #expect(rule.comparison == .greaterThanOrEqual)
        #expect(!hasSFT(tips(for: cashDeposit(amount: below, account: savings), accounts: [savings])))
        #expect(hasSFT(tips(for: cashDeposit(amount: threshold, account: savings), accounts: [savings])))
        #expect(hasSFT(tips(for: cashDeposit(amount: above, account: savings), accounts: [savings])))
    }

    @Test("SFT current tip triggers at exact ₹50,00,000")
    func sftCurrentBoundaries() {
        let rule = IndiaComplianceRules.sftCurrentDeposit
        let threshold = rule.threshold
        let below = IndiaComplianceTipEngine.amountByAddingPaisa(threshold, paisaDelta: -1)
        let current = AccountEntity(name: "Business Current", type: .bank)

        #expect(rule.comparison == .greaterThanOrEqual)
        #expect(!hasSFT(tips(for: cashDeposit(amount: below, account: current), accounts: [current])))
        #expect(hasSFT(tips(for: cashDeposit(amount: threshold, account: current), accounts: [current])))
    }

    // MARK: - GST boundaries (> ₹20,00,000 services) + business gate

    @Test("GST tip triggers one paisa above ₹20,00,000 and only for business income")
    func gstRegistrationBoundaries() {
        let rule = IndiaComplianceRules.gstServicesGeneral
        let threshold = rule.threshold
        let below = IndiaComplianceTipEngine.amountByAddingPaisa(threshold, paisaDelta: -1)
        let above = IndiaComplianceTipEngine.amountByAddingPaisa(threshold, paisaDelta: 1)

        #expect(rule.comparison == .greaterThan)
        #expect(!rule.isTriggered(by: threshold))
        #expect(rule.isTriggered(by: above))

        #expect(tips(
            for: [],
            incomeSourceType: .selfEmployed,
            annualIncome: threshold
        ).contains { $0.ruleID == .gstRegistration } == false)

        #expect(tips(
            for: [],
            incomeSourceType: .selfEmployed,
            annualIncome: above
        ).contains { $0.ruleID == .gstRegistration })

        #expect(tips(
            for: [],
            incomeSourceType: .salaried,
            annualIncome: above
        ).contains { $0.ruleID == .gstRegistration } == false)

        #expect(tips(
            for: [TransactionEntity(
                amount: above,
                date: date(2025, 6, 1),
                type: .income,
                paymentMethod: .bankTransfer
            )],
            incomeSourceType: .selfEmployed,
            annualIncome: 0
        ).contains { $0.ruleID == .gstRegistration })
    }

    // MARK: - §194-IB boundaries (> ₹50,000/month)

    @Test("§194-IB triggers one paisa above ₹50,000 monthly rent")
    func section194IBBoundaries() {
        let rule = IndiaComplianceRules.section194IB
        let threshold = rule.threshold
        let above = IndiaComplianceTipEngine.amountByAddingPaisa(threshold, paisaDelta: 1)
        let rent = CategoryEntity(name: "Rent", icon: "house.fill", type: .expense)

        #expect(rule.comparison == .greaterThan)
        #expect(!rule.isTriggered(by: threshold))
        #expect(rule.isTriggered(by: above))

        #expect(tips(
            for: [TransactionEntity(
                amount: threshold,
                date: date(2025, 6, 5),
                type: .expense,
                paymentMethod: .upi,
                categoryID: rent.id
            )],
            categories: [rent]
        ).contains { $0.ruleID == .section194IB } == false)

        #expect(tips(
            for: [TransactionEntity(
                amount: above,
                date: date(2025, 6, 5),
                type: .expense,
                paymentMethod: .upi,
                categoryID: rent.id
            )],
            categories: [rent]
        ).contains { $0.ruleID == .section194IB })
    }

    // MARK: - Country gate

    @Test("Tips are suppressed entirely when the user's country is not India")
    func suppressesTipsForNonIndia() {
        let result = IndiaComplianceTipEngine.evaluate(
            IndiaComplianceTipEngine.Input(
                country: .unitedStates,
                financialYear: "2026",
                incomeSourceType: .selfEmployed,
                annualIncome: 50_00_000,
                transactions: [
                    TransactionEntity(
                        amount: 5_00_000,
                        date: date(2025, 6, 1),
                        type: .income,
                        paymentMethod: .cash
                    ),
                ],
                accountsByID: [:],
                categoriesByID: [:],
                calendar: calendar
            )
        )
        #expect(result.isEmpty)
    }

    // MARK: - Imperative phrasing

    @Test("Tip strings contain no imperative advice phrasing")
    func tipStringsAvoidImperativeAdvice() {
        let savings = AccountEntity(name: "Savings", type: .bank)
        let rent = CategoryEntity(name: "Rent", icon: "house.fill", type: .expense)
        let payee = UUID()
        let allTips = tips(
            for: [
                TransactionEntity(
                    amount: 2_00_000,
                    date: date(2025, 5, 1),
                    type: .income,
                    paymentMethod: .cash,
                    payeeID: payee
                ),
                TransactionEntity(
                    amount: 10_001,
                    date: date(2025, 5, 2),
                    type: .expense,
                    paymentMethod: .cash
                ),
                TransactionEntity(
                    amount: 10_00_000,
                    date: date(2025, 5, 3),
                    type: .income,
                    paymentMethod: .cash,
                    accountID: savings.id
                ),
                TransactionEntity(
                    amount: 25_00_000,
                    date: date(2025, 5, 4),
                    type: .income,
                    paymentMethod: .upi
                ),
                TransactionEntity(
                    amount: 50_001,
                    date: date(2025, 5, 5),
                    type: .expense,
                    paymentMethod: .upi,
                    categoryID: rent.id
                ),
            ],
            incomeSourceType: .selfEmployed,
            annualIncome: 25_00_000,
            accounts: [savings],
            categories: [rent]
        )

        #expect(allTips.count == 5)
        let banned = ["you should", "reduce your", "you must", "you need to"]
        for tip in allTips {
            let lower = tip.advisoryText.lowercased()
            for phrase in banned {
                #expect(!lower.contains(phrase), "Tip \(tip.ruleID) contains '\(phrase)'")
            }
        }
    }

    // MARK: - Dismissal persistence + FY reset

    @Test("Dismissal persists across store instances and resets for a new financial year")
    func dismissalPersistsAndResetsOnNewFinancialYear() {
        let suiteName = "india-compliance-tips-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsIndiaComplianceTipDismissalStore(userDefaults: defaults)
        #expect(!store.isDismissed(ruleID: .section269ST, financialYear: "2025-26"))

        store.dismiss(ruleID: .section269ST, financialYear: "2025-26")
        let reloaded = UserDefaultsIndiaComplianceTipDismissalStore(userDefaults: defaults)
        #expect(reloaded.isDismissed(ruleID: .section269ST, financialYear: "2025-26"))
        #expect(!reloaded.isDismissed(ruleID: .section269ST, financialYear: "2026-27"))
    }

    // MARK: - Wiring through use case

    @Test("Use case wires repository transactions into tips and respects dismissal")
    @MainActor
    func useCaseWiresTransactionsAndDismissal() async throws {
        let transactionRepository = MockTransactionRepository()
        let accountRepository = MockAccountRepository()
        let categoryRepository = MockCategoryRepository()
        let suiteName = "india-compliance-wiring-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let dismissalStore = UserDefaultsIndiaComplianceTipDismissalStore(userDefaults: defaults)

        let savings = AccountEntity(name: "Savings", type: .bank)
        try await accountRepository.create(savings)
        try await transactionRepository.create(
            TransactionEntity(
                amount: 2_50_000,
                date: date(2025, 8, 10),
                type: .income,
                paymentMethod: .cash,
                accountID: savings.id
            )
        )

        let useCase = EvaluateIndiaComplianceTipsUseCase(
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            dismissalStore: dismissalStore,
            calendar: calendar
        )

        let profile = TaxProfile(
            country: .india,
            annualIncome: 8_00_000,
            financialYear: fy,
            incomeSourceType: .salaried
        )
        let tips = try await useCase.execute(profile: profile)
        #expect(tips.contains { $0.ruleID == .section269ST })

        if let tip = tips.first(where: { $0.ruleID == .section269ST }) {
            useCase.dismiss(tip: tip, financialYear: fy)
        }
        let afterDismiss = try await useCase.execute(profile: profile)
        #expect(afterDismiss.contains { $0.ruleID == .section269ST } == false)

        try await transactionRepository.create(
            TransactionEntity(
                amount: 2_50_000,
                date: date(2026, 8, 10),
                type: .income,
                paymentMethod: .cash,
                accountID: savings.id
            )
        )
        let nextYearProfile = TaxProfile(
            country: .india,
            annualIncome: 8_00_000,
            financialYear: "2026-27",
            incomeSourceType: .salaried
        )
        let nextYearTips = try await useCase.execute(profile: nextYearProfile)
        #expect(nextYearTips.contains { $0.ruleID == .section269ST })
        #expect(!dismissalStore.isDismissed(ruleID: .section269ST, financialYear: "2026-27"))
    }

    @Test("Use case returns no tips for a US tax profile even with crossing amounts")
    @MainActor
    func useCaseSuppressesNonIndiaCountry() async throws {
        let transactionRepository = MockTransactionRepository()
        try await transactionRepository.create(
            TransactionEntity(
                amount: 5_00_000,
                date: date(2025, 8, 10),
                type: .income,
                paymentMethod: .cash
            )
        )
        let suiteName = "india-compliance-us-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let useCase = EvaluateIndiaComplianceTipsUseCase(
            transactionRepository: transactionRepository,
            accountRepository: MockAccountRepository(),
            categoryRepository: MockCategoryRepository(),
            dismissalStore: UserDefaultsIndiaComplianceTipDismissalStore(userDefaults: defaults)
        )
        let tips = try await useCase.execute(
            profile: TaxProfile(country: .unitedStates, annualIncome: 90_000, financialYear: "2026")
        )
        #expect(tips.isEmpty)
    }

    // MARK: - Helpers

    private func tips(
        for transactions: [TransactionEntity],
        incomeSourceType: IncomeSourceType = .salaried,
        annualIncome: Decimal = 0,
        accounts: [AccountEntity] = [],
        categories: [CategoryEntity] = [],
        country: TaxCountry = .india
    ) -> [IndiaComplianceTip] {
        IndiaComplianceTipEngine.evaluate(
            IndiaComplianceTipEngine.Input(
                country: country,
                financialYear: fy,
                incomeSourceType: incomeSourceType,
                annualIncome: annualIncome,
                transactions: transactions,
                accountsByID: Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) }),
                categoriesByID: Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) }),
                calendar: calendar
            )
        )
    }

    private func cashIncome(amount: Decimal) -> [TransactionEntity] {
        [
            TransactionEntity(
                amount: amount,
                date: date(2025, 6, 15),
                type: .income,
                paymentMethod: .cash,
                payeeID: UUID()
            ),
        ]
    }

    private func cashExpense(amount: Decimal) -> [TransactionEntity] {
        [
            TransactionEntity(
                amount: amount,
                date: date(2025, 6, 15),
                type: .expense,
                paymentMethod: .cash
            ),
        ]
    }

    private func cashDeposit(amount: Decimal, account: AccountEntity) -> [TransactionEntity] {
        [
            TransactionEntity(
                amount: amount,
                date: date(2025, 6, 15),
                type: .income,
                paymentMethod: .cash,
                accountID: account.id
            ),
        ]
    }

    private func hasSFT(_ tips: [IndiaComplianceTip]) -> Bool {
        tips.contains { $0.ruleID == .sftCashDeposit }
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }
}
