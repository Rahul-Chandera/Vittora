import Foundation
import VittoraCore

/// Bridges app events to conversion milestones for F5 instrumentation.
struct ConversionEventRecorder: Sendable {
    let tracker: any ConversionEventTracking
    let transactionRepository: any TransactionRepository
    let accountRepository: any AccountRepository
    let budgetRepository: any BudgetRepository

    @discardableResult
    func afterTransactionCreated() async -> ConversionEventResult? {
        guard let count = try? await transactionRepository.fetchTransactionCount(),
              count >= FreeTierLimits.transactionMilestoneCount else {
            return nil
        }
        return tracker.record(.tenthTransaction)
    }

    @discardableResult
    func afterOCRScanCompleted() -> ConversionEventResult {
        tracker.recordOCRScan()
    }

    @discardableResult
    func afterReportOpened() -> ConversionEventResult {
        tracker.record(.firstReport)
    }

    @discardableResult
    func afterSplitExpenseCreated() -> ConversionEventResult {
        tracker.record(.firstSplit)
    }

    @discardableResult
    func afterAccountCreated() async -> ConversionEventResult? {
        guard let accounts = try? await accountRepository.fetchAll(),
              accounts.count >= FreeTierLimits.maxAccounts else {
            return nil
        }
        return tracker.record(.accountLimitReached)
    }

    @discardableResult
    func afterBudgetCreated() async -> ConversionEventResult? {
        guard let budgets = try? await budgetRepository.fetchAll(),
              budgets.count >= FreeTierLimits.maxBudgets else {
            return nil
        }
        return tracker.record(.budgetLimitReached)
    }
}
