import Foundation
import Testing
import VittoraCore

/// The parser decides what becomes money in the ledger from a message the user's own
/// automation hands it, so the cases that must return nil matter as much as the ones
/// that must not.
@Suite("Bank Message Parser Tests")
struct BankMessageParserTests {

    // MARK: - Debits it should read

    @Test("UPI debit to a VPA: amount, rupees, readable merchant, UPI")
    func upiVPA() throws {
        let debit = try #require(BankMessageParser.parseDebit(
            "Rs.250.00 debited from A/c XX1234 on 25-Oct-26 to VPA swiggy@axisbank (UPI Ref No 629812345678). Not you? Call 18002586161"
        ))
        #expect(debit.amount == Decimal(string: "250.00"))
        #expect(debit.currencyCode == "INR")
        #expect(debit.merchant == "Swiggy")
        #expect(debit.paymentMethod == .upi)
    }

    @Test("Card spend: the amount spent, not the available balance after it")
    func cardSpendIgnoresBalance() throws {
        let debit = try #require(BankMessageParser.parseDebit(
            "INR 1,250.00 spent on HDFC Bank Card x1234 at AMAZON PAY INDIA on 2026-10-25:10:22:33. Avl bal: INR 52,300.00"
        ))
        #expect(debit.amount == 1250)
        #expect(debit.currencyCode == "INR")
        #expect(debit.merchant == "AMAZON PAY INDIA")
    }

    @Test("Money sent to a person")
    func sentToPerson() throws {
        let debit = try #require(BankMessageParser.parseDebit(
            "Sent Rs.500.00 From HDFC Bank A/C *1234 To RAHUL KUMAR On 25/10/26 Ref 629812345678 Not You?"
        ))
        #expect(debit.amount == 500)
        #expect(debit.merchant == "RAHUL KUMAR")
    }

    @Test("ICICI style: merchant named before 'credited'")
    func iciciStyle() throws {
        let debit = try #require(BankMessageParser.parseDebit(
            "ICICI Bank Acct XX123 debited for Rs 300.00 on 25-Oct-26; Zomato credited. UPI:629812345678. Call 18002662 for dispute."
        ))
        #expect(debit.amount == 300)
        #expect(debit.merchant == "Zomato")
        #expect(debit.paymentMethod == .upi)
    }

    @Test("A debit whose beneficiary is an account number has no merchant")
    func beneficiaryAccountIsNotAMerchant() throws {
        let debit = try #require(BankMessageParser.parseDebit(
            "Your a/c no. XXXXXX1234 is debited for Rs.300.00 on 25-10-2026 and credited to a/c no. XXXXXX5678 (UPI Ref no 629812345678)"
        ))
        #expect(debit.amount == 300)
        #expect(debit.merchant == nil)
    }

    @Test("US card alert: dollars, merchant after 'with', not the time after 'at'")
    func usCardTransaction() throws {
        let debit = try #require(BankMessageParser.parseDebit(
            "Chase: You made a $45.20 transaction with STARBUCKS on Oct 25, 2026 at 8:14 AM ET."
        ))
        #expect(debit.amount == Decimal(string: "45.20"))
        #expect(debit.currencyCode == "USD")
        #expect(debit.merchant == "STARBUCKS")
    }

    @Test("US charge alert keeps a merchant with an asterisk")
    func usChargeAlert() throws {
        let debit = try #require(BankMessageParser.parseDebit(
            "Amex: A charge of $30.00 at UBER *TRIP was made on your Card ending 1001."
        ))
        #expect(debit.amount == 30)
        #expect(debit.merchant == "UBER *TRIP")
    }

    @Test("'atm' inside a word does not reject the message")
    func atmOnlyAsAWord() throws {
        let debit = try #require(BankMessageParser.parseDebit(
            "Rs 800 debited from A/c XX1234 at APOLLO TREATMENT CENTRE on 25-Oct-26"
        ))
        #expect(debit.amount == 800)
    }

    // MARK: - Messages that are not spending

    @Test("A credit is not spending")
    func creditIsIgnored() {
        #expect(BankMessageParser.parseDebit(
            "Rs.5,000.00 credited to A/c XX1234 on 25-Oct-26 by NEFT from ACME CORP"
        ) == nil)
    }

    @Test("Money received, even when the message says 'paid by'")
    func receivedPaidByIsIgnored() {
        #expect(BankMessageParser.parseDebit(
            "You have received Rs 500.00 in your a/c XX1234, paid by RAHUL via UPI"
        ) == nil)
    }

    @Test("An OTP that mentions an amount is not spending")
    func otpIsIgnored() {
        #expect(BankMessageParser.parseDebit(
            "123456 is your OTP for txn of Rs 999.00 at FLIPKART. Do not share it with anyone."
        ) == nil)
    }

    @Test("An upcoming autopay is not spending yet")
    func upcomingAutopayIsIgnored() {
        #expect(BankMessageParser.parseDebit(
            "Rs 649 will be debited on 28-Oct-26 for NETFLIX autopay. Maintain sufficient balance."
        ) == nil)
    }

    @Test("An ATM withdrawal moves money to cash; it is not an expense")
    func atmWithdrawalIsIgnored() {
        #expect(BankMessageParser.parseDebit(
            "Rs.2,000.00 withdrawn at ATM S1AW1234 from A/c XX1234 on 25-Oct-26"
        ) == nil)
    }

    @Test("A balance message is not spending")
    func balanceIsIgnored() {
        #expect(BankMessageParser.parseDebit(
            "Your A/c XX1234 balance is Rs 10,000.00 as of 25-Oct-26"
        ) == nil)
    }

    @Test("A declined payment is not spending")
    func declinedIsIgnored() {
        #expect(BankMessageParser.parseDebit(
            "Your transaction of $25.00 at TARGET was declined."
        ) == nil)
    }
}
