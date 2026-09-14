import Foundation
import VittoraCore

/// Bridges app events to conversion milestones for F5 instrumentation.
struct ConversionEventRecorder: Sendable {
    let tracker: any ConversionEventTracking
    let transactionRepository: any TransactionRepository

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
}
