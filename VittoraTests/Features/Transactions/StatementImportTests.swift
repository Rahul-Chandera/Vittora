import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Bank statement import: OFX/QFX, QIF, and bank-statement CSVs with split withdrawal
/// and deposit columns. A wrong sign or a wrong date puts money in the wrong place, so
/// those are what these pin.
@Suite("Statement Import Tests")
@MainActor
struct StatementImportTests {
    private let locale = Locale(identifier: "en_US")
    private let indiaLocale = Locale(identifier: "en_IN")

    private func makeUseCase() -> ImportTransactionsFromCSVUseCase {
        let accounts = MockAccountRepository()
        let transactions = MockTransactionRepository()
        return ImportTransactionsFromCSVUseCase(
            addTransactionUseCase: AddTransactionUseCase(
                accountRepository: accounts,
                categoryRepository: MockCategoryRepository(),
                ledgerWriting: MockLedgerWriting(transactionRepository: transactions, accountRepository: accounts)
            ),
            duplicateDetectionUseCase: DuplicateDetectionUseCase(transactionRepository: transactions),
            payeeRepository: MockPayeeRepository(),
            categoryRepository: MockCategoryRepository()
        )
    }

    private func ymd(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // MARK: - OFX

    @Test("OFX 1.x (SGML, unclosed tags): sign decides expense or income; a bad row is counted")
    func ofxSGML() throws {
        let ofx = """
        OFXHEADER:100
        DATA:OFXSGML
        <OFX><BANKMSGSRSV1><STMTTRNRS><STMTRS><BANKTRANLIST>
        <STMTTRN>
        <TRNTYPE>DEBIT
        <DTPOSTED>20261025120000[-5:EST]
        <TRNAMT>-45.20
        <FITID>1001
        <NAME>STARBUCKS #123
        <MEMO>Card purchase
        </STMTTRN>
        <STMTTRN>
        <TRNTYPE>CREDIT
        <DTPOSTED>20261024
        <TRNAMT>2500.00
        <FITID>1002
        <NAME>ACME PAYROLL
        </STMTTRN>
        <STMTTRN>
        <TRNTYPE>DEBIT
        <TRNAMT>-9.99
        </STMTTRN>
        </BANKTRANLIST></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>
        """
        let preview = try makeUseCase().preview(csvData: Data(ofx.utf8), profile: .ofx, locale: locale)

        #expect(preview.mapping == nil)
        #expect(preview.rows.count == 2)
        #expect(preview.invalidRowCount == 1)
        let coffee = preview.rows[0]
        #expect(coffee.amount == Decimal(string: "45.20"))
        #expect(coffee.type == .expense)
        #expect(coffee.payeeName == "STARBUCKS #123")
        #expect(coffee.note == "Card purchase")
        #expect(ymd(coffee.date) == "2026-10-25")
        #expect(preview.rows[1].type == .income)
        #expect(preview.rows[1].amount == 2500)
    }

    @Test("OFX 2.x (XML) and QFX read the same way, entities decoded")
    func ofxXML() throws {
        let ofx = """
        <?xml version="1.0" encoding="UTF-8"?><OFX><BANKTRANLIST>
        <STMTTRN><TRNTYPE>DEBIT</TRNTYPE><DTPOSTED>20261020</DTPOSTED><TRNAMT>-12.50</TRNAMT><NAME>BARNES &amp; NOBLE</NAME></STMTTRN>
        </BANKTRANLIST></OFX>
        """
        let parsed = StatementFileParser.parseOFX(ofx)
        #expect(parsed.rows.count == 1)
        #expect(parsed.rows[0].payeeName == "BARNES & NOBLE")
        #expect(parsed.rows[0].amount == Decimal(string: "12.50"))
    }

    // MARK: - QIF

    @Test("QIF: Quicken's apostrophe year, category leaf, transfers are not categories")
    func qifUS() throws {
        let qif = """
        !Type:Bank
        D10/25'26
        T-42.15
        PWhole Foods
        MWeekly shop
        LFood:Groceries
        ^
        D10/24'26
        T-500.00
        PTransfer to savings
        L[Savings]
        ^
        D10/23'26
        T3,200.00
        PPaycheck
        ^
        """
        let preview = try makeUseCase().preview(csvData: Data(qif.utf8), profile: .qif, locale: locale)

        #expect(preview.rows.count == 3)
        let groceries = preview.rows[0]
        #expect(ymd(groceries.date) == "2026-10-25")
        #expect(groceries.amount == Decimal(string: "42.15"))
        #expect(groceries.type == .expense)
        #expect(groceries.categoryName == "Groceries")
        #expect(groceries.note == "Weekly shop")
        #expect(preview.rows[1].categoryName == nil)
        #expect(preview.rows[2].type == .income)
        #expect(preview.rows[2].amount == 3200)
    }

    @Test("QIF from a day-first locale: one unambiguous date settles the file")
    func qifDayFirst() throws {
        let qif = """
        !Type:Bank
        D05/10/2026
        T-10.00
        PCafe
        ^
        D25/10/2026
        T-20.00
        PBakery
        ^
        """
        let parsed = StatementFileParser.parseQIF(qif, locale: locale)
        #expect(parsed.rows.count == 2)
        #expect(ymd(parsed.rows[0].date) == "2026-10-05")
    }

    // MARK: - Bank statement CSV

    @Test("HDFC-style statement: header found below the preamble, withdrawal and deposit columns, dd/MM/yy")
    func hdfcStatement() throws {
        let csv = """
        HDFC BANK Ltd.,,,,,,
        Account No :,XXXXXXXX1234,,,,,
        Statement From : 01/10/2026 To : 31/10/2026,,,,,,
        ,,,,,,
        Date,Narration,Chq./Ref.No.,Value Dt,Withdrawal Amt.,Deposit Amt.,Closing Balance
        25/10/26,UPI-SWIGGY-SWIGGY@AXISBANK-UTIB0000100-629812345678-PAYMENT,0000629812345678,25/10/26,250.00,,"1,02,350.00"
        24/10/26,NEFT CR-ICIC0000001-ACME CORP-OCT SALARY-N12345,N12345,24/10/26,,"1,50,000.00","1,02,600.00"
        """
        let preview = try makeUseCase().preview(csvData: Data(csv.utf8), profile: .bankStatement, locale: indiaLocale)

        #expect(preview.rows.count == 2)
        let swiggy = preview.rows[0]
        #expect(swiggy.type == .expense)
        #expect(swiggy.amount == 250)
        #expect(swiggy.payeeName == "SWIGGY")
        #expect(swiggy.note == "UPI-SWIGGY-SWIGGY@AXISBANK-UTIB0000100-629812345678-PAYMENT")
        #expect(ymd(swiggy.date) == "2026-10-25")
        let salary = preview.rows[1]
        #expect(salary.type == .income)
        #expect(salary.amount == 150_000)
        #expect(salary.payeeName == "ACME CORP")
    }

    @Test("ICICI-style statement: Transaction Date wins over the earlier Value Date column")
    func iciciStatement() throws {
        let csv = """
        S No.,Value Date,Transaction Date,Cheque Number,Transaction Remarks,Withdrawal Amount (INR ),Deposit Amount (INR ),Balance (INR )
        1,26/10/2026,25/10/2026,,UPI/629812345678/Payment/swiggy@axis/Axis Bank,300.00,0.00,"10,000.00"
        """
        let preview = try makeUseCase().preview(csvData: Data(csv.utf8), profile: .bankStatement, locale: indiaLocale)

        #expect(preview.rows.count == 1)
        #expect(ymd(preview.rows[0].date) == "2026-10-25")
        #expect(preview.rows[0].payeeName == "Swiggy")
        #expect(preview.rows[0].amount == 300)
    }

    @Test("SBI-style statement: Debit and Credit columns, dd-MMM-yyyy dates")
    func sbiStatement() throws {
        let csv = """
        Txn Date,Value Date,Description,Ref No./Cheque No.,Debit,Credit,Balance
        25-Oct-2026,25-Oct-2026,BY TRANSFER-UPI/DR/629812345678/BIGBASKET/UTIB/bigbasket@axis/Payment,629812345678,"1,250.00",,"48,750.00"
        """
        let preview = try makeUseCase().preview(csvData: Data(csv.utf8), profile: .bankStatement, locale: indiaLocale)

        #expect(preview.rows.count == 1)
        #expect(preview.rows[0].payeeName == "BIGBASKET")
        #expect(preview.rows[0].amount == 1250)
        #expect(ymd(preview.rows[0].date) == "2026-10-25")
    }

    @Test("A CSV with no recognisable statement header is refused, not half-read")
    func noStatementHeader() {
        let csv = """
        Hello,World
        1,2
        """
        #expect(throws: CSVImportError.self) {
            try makeUseCase().preview(csvData: Data(csv.utf8), profile: .bankStatement, locale: indiaLocale)
        }
    }

    // MARK: - Narrations

    @Test("Card and transfer narrations clean up to the merchant", arguments: [
        ("POS 416021XXXXXX1234 AMAZON PAY INDI", "AMAZON PAY INDI"),
        ("NEFT DR-HDFC0000001-ACME CORP-NETBANK, MUM-N123456789", "ACME CORP"),
        ("Grocery run", "Grocery run"),
    ])
    func narrationCleaning(raw: String, expected: String) {
        #expect(CSVTransactionImportMapper.cleanedBankNarration(raw) == expected)
    }

    @Test("File extensions pick OFX and QIF; CSV is left to the columns")
    func extensionProfiles() {
        #expect(CSVImportProfile.forFileExtension("QFX") == .ofx)
        #expect(CSVImportProfile.forFileExtension("ofx") == .ofx)
        #expect(CSVImportProfile.forFileExtension("qif") == .qif)
        #expect(CSVImportProfile.forFileExtension("csv") == nil)
    }
}
