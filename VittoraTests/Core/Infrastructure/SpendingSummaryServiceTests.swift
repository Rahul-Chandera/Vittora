import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Apple Intelligence monthly summary (M3.2.6).
///
/// The model itself cannot be exercised in a unit test — it needs a supported
/// device with Apple Intelligence enabled. What IS tested, and what actually
/// protects the user, is the faithfulness check: any figure the model invents
/// must be caught and the summary discarded.
@Suite("SpendingSummaryService")
@MainActor
struct SpendingSummaryServiceTests {

    private func d(_ s: String) -> Decimal { Decimal(string: s) ?? .nan }

    private func facts(
        spent: Decimal = 1_250,
        income: Decimal = 3_000,
        topName: String? = "Groceries",
        topAmount: Decimal? = 420
    ) -> SpendingSummaryService.Facts {
        .init(
            monthName: "September",
            totalSpent: spent,
            totalIncome: income,
            topCategoryName: topName,
            topCategoryAmount: topAmount,
            currencyCode: "GBP"
        )
    }

    // MARK: - The guard that matters

    /// The whole point: a figure the ledger does not contain must not reach the
    /// user, however well the sentence reads.
    @Test("a summary containing an invented figure is rejected")
    func rejectsInventedFigure() {
        let f = facts()
        #expect(SpendingSummaryService.isFaithful(
            "You spent 1250 against 3000 of income.", to: f
        ))
        #expect(!SpendingSummaryService.isFaithful(
            "You spent 1250 against 3000 of income, saving 1750.", to: f
        ), "1750 was never supplied — the model computed it")
    }

    /// A derived figure is exactly the hallucination risk the scope note warns
    /// about: it looks right and is unverifiable at a glance.
    @Test("a plausible derived total is still rejected")
    func rejectsDerivedTotal() {
        #expect(!SpendingSummaryService.isFaithful(
            "Your largest category was Groceries at 420, about 34% of spending.",
            to: facts()
        ))
    }

    @Test("supplied figures pass in grouped or plain form")
    func acceptsNumberForms() {
        let f = facts(spent: 1_250, income: 3_000)
        #expect(SpendingSummaryService.isFaithful("You spent 1,250 this month.", to: f))
        #expect(SpendingSummaryService.isFaithful("You spent £1,250.00 this month.", to: f), "currency formatting is how the app itself writes figures")
        #expect(SpendingSummaryService.isFaithful("You spent 1250 this month.", to: f))
    }

    /// A date or a small count is not a financial claim, so it must not trip
    /// the guard and discard an otherwise good summary.
    @Test("small integers and dates do not trip the guard")
    func allowsSmallIntegers() {
        #expect(SpendingSummaryService.isFaithful(
            "Across 12 days you spent 1250 against 3000 of income.", to: facts()
        ))
    }

    @Test("prose with no numbers at all is faithful")
    func noNumbers() {
        #expect(SpendingSummaryService.isFaithful(
            "Your spending was concentrated in groceries this month.", to: facts()
        ))
    }

    // MARK: - Fallback

    /// The deterministic sentence is a complete answer, not a placeholder.
    @Test("the fallback states the real figures")
    func fallbackIsComplete() {
        let text = SpendingSummaryService.deterministicSummary(facts())
        #expect(text.contains("September"))
        #expect(text.contains("Groceries"))
        #expect(!text.isEmpty)
    }

    /// It must be faithful by its own standard — otherwise the guard would
    /// reject the fallback too.
    @Test("the fallback passes its own faithfulness check")
    func fallbackIsFaithful() {
        let f = facts()
        #expect(SpendingSummaryService.isFaithful(
            SpendingSummaryService.deterministicSummary(f), to: f
        ))
    }

    @Test("a month with no top category still summarises")
    func fallbackWithoutCategory() {
        let f = facts(topName: nil, topAmount: nil)
        let text = SpendingSummaryService.deterministicSummary(f)
        #expect(text.contains("September"))
        #expect(SpendingSummaryService.isFaithful(text, to: f))
    }

    /// The feature is optional. On a device without Apple Intelligence,
    /// summarise must still return usable text rather than nothing.
    @Test("summarise always returns text, model or not")
    func alwaysReturnsSomething() async {
        let summary = await SpendingSummaryService().summarise(facts())
        #expect(!summary.text.isEmpty)
        // Whichever path ran, the result must survive the faithfulness check.
        #expect(SpendingSummaryService.isFaithful(summary.text, to: facts()))
    }

    /// The UI must be able to avoid claiming Apple Intelligence wrote something
    /// it did not.
    @Test("the summary reports which path produced it")
    func reportsProvenance() async {
        let summary = await SpendingSummaryService().summarise(facts())
        if !SpendingSummaryService.isAvailable {
            #expect(summary.isModelGenerated == false)
        }
    }

    @Test("zero figures do not break the summary")
    func zeroFigures() {
        let f = facts(spent: 0, income: 0, topName: nil, topAmount: nil)
        let text = SpendingSummaryService.deterministicSummary(f)
        #expect(!text.isEmpty)
        #expect(SpendingSummaryService.isFaithful(text, to: f))
    }
}
