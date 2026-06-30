import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("CSV Parser Tests")
struct CSVParserTests {
    @Test("parses quoted fields with commas")
    func parsesQuotedCommas() {
        let csv = """
        Date,Description,Amount
        2026-01-15,"Coffee, Inc.",-4.50
        """

        let rows = CSVParser.parse(csv)
        #expect(rows.count == 2)
        #expect(rows[1][1] == "Coffee, Inc.")
        #expect(rows[1][2] == "-4.50")
    }
}

@Suite("CSV Transaction Import Tests")
@MainActor
struct CSVTransactionImportTests {
    private let accountID = UUID()
    private let locale = Locale(identifier: "en_US")

    @Test("Mint profile maps signed amounts to income and expense")
    func mintProfileParsesRows() throws {
        let csv = """
        Date,Description,Amount,Category
        2026-01-10,Whole Foods,-42.15,Groceries
        2026-01-11,Paycheck,2500.00,Income
        """

        let preview = try ImportTransactionsFromCSVUseCase(
            addTransactionUseCase: makeAddUseCase(),
            duplicateDetectionUseCase: DuplicateDetectionUseCase(transactionRepository: MockTransactionRepository()),
            payeeRepository: MockPayeeRepository(),
            categoryRepository: MockCategoryRepository()
        ).preview(csvData: Data(csv.utf8), profile: .mint, locale: locale)

        #expect(preview.rows.count == 2)
        #expect(preview.rows[0].type == .expense)
        #expect(preview.rows[0].amount == Decimal(string: "42.15"))
        #expect(preview.rows[1].type == .income)
        #expect(preview.rows[1].amount == 2500)
    }

    @Test("YNAB profile uses outflow and inflow columns")
    func ynabProfileParsesRows() throws {
        let csv = """
        Date,Payee,Category Group/Category,Memo,Outflow,Inflow
        01/15/2026,Landlord,Rent,,1200.00,
        01/16/2026,Employer,Income,,,3000.00
        """

        let preview = try ImportTransactionsFromCSVUseCase(
            addTransactionUseCase: makeAddUseCase(),
            duplicateDetectionUseCase: DuplicateDetectionUseCase(transactionRepository: MockTransactionRepository()),
            payeeRepository: MockPayeeRepository(),
            categoryRepository: MockCategoryRepository()
        ).preview(csvData: Data(csv.utf8), profile: .ynab, locale: locale)

        #expect(preview.rows.count == 2)
        #expect(preview.rows[0].type == .expense)
        #expect(preview.rows[0].amount == 1200)
        #expect(preview.rows[1].type == .income)
    }

    @Test("import skips duplicate transactions")
    func importSkipsDuplicates() async throws {
        let csv = """
        Date,Description,Amount
        2026-02-01,Coffee Shop,-5.00
        """

        let account = AccountEntity(name: "Checking", type: .bank, balance: 100)
        let accountRepo = MockAccountRepository()
        try await accountRepo.create(account)

        let existingPayee = PayeeEntity(name: "Coffee Shop")
        let payeeRepo = MockPayeeRepository()
        await payeeRepo.seed(existingPayee)

        let transactionRepo = MockTransactionRepository()
        try await transactionRepo.create(
            TransactionEntity(
                amount: 5,
                date: date(from: "2026-02-01"),
                type: .expense,
                accountID: account.id,
                payeeID: existingPayee.id
            )
        )

        let useCase = ImportTransactionsFromCSVUseCase(
            addTransactionUseCase: makeAddUseCase(
                accountRepository: accountRepo,
                transactionRepository: transactionRepo
            ),
            duplicateDetectionUseCase: DuplicateDetectionUseCase(transactionRepository: transactionRepo),
            payeeRepository: payeeRepo,
            categoryRepository: MockCategoryRepository()
        )

        let result = try await useCase.execute(
            csvData: Data(csv.utf8),
            profile: .generic,
            accountID: account.id,
            currencyCode: "USD",
            locale: locale
        )

        #expect(result.importedCount == 0)
        #expect(result.skippedDuplicateCount == 1)
    }

    @Test("import creates payees and transactions")
    func importCreatesTransactions() async throws {
        let csv = """
        Date,Description,Amount
        2026-03-01,New Merchant,-12.50
        """

        let account = AccountEntity(name: "Checking", type: .bank, balance: 100)
        let accountRepo = MockAccountRepository()
        try await accountRepo.create(account)

        let payeeRepo = MockPayeeRepository()
        let transactionRepo = MockTransactionRepository()
        let ledger = MockLedgerWriting(transactionRepository: transactionRepo, accountRepository: accountRepo)

        let useCase = ImportTransactionsFromCSVUseCase(
            addTransactionUseCase: AddTransactionUseCase(
                accountRepository: accountRepo,
                categoryRepository: MockCategoryRepository(),
                ledgerWriting: ledger
            ),
            duplicateDetectionUseCase: DuplicateDetectionUseCase(transactionRepository: transactionRepo),
            payeeRepository: payeeRepo,
            categoryRepository: MockCategoryRepository()
        )

        let result = try await useCase.execute(
            csvData: Data(csv.utf8),
            profile: .generic,
            accountID: account.id,
            currencyCode: "USD",
            locale: locale
        )

        #expect(result.importedCount == 1)
        #expect(result.createdPayeeCount == 1)
        let stored = await transactionRepo.transactions
        #expect(stored.count == 1)
        #expect(stored[0].amount == Decimal(string: "12.50"))
    }

    private func makeAddUseCase(
        accountRepository: MockAccountRepository = MockAccountRepository(),
        transactionRepository: MockTransactionRepository = MockTransactionRepository()
    ) -> AddTransactionUseCase {
        AddTransactionUseCase(
            accountRepository: accountRepository,
            categoryRepository: MockCategoryRepository(),
            ledgerWriting: MockLedgerWriting(
                transactionRepository: transactionRepository,
                accountRepository: accountRepository
            )
        )
    }

    private func date(from string: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string) ?? Date(timeIntervalSince1970: 0)
    }
}
