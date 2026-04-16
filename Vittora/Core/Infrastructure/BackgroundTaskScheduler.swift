import Foundation
import SwiftData

#if os(iOS)
import BackgroundTasks
#endif

final class BackgroundTaskScheduler: Sendable {
    #if os(iOS)
    static let recurringTaskID = "com.enerjiktech.vittora.recurring-generation"
    #endif

    private let generateUseCase: GenerateRecurringTransactionsUseCase

    init(generateUseCase: GenerateRecurringTransactionsUseCase) {
        self.generateUseCase = generateUseCase
    }

    #if os(iOS)
    /// Register background task handler for recurring transaction generation
    static func register(generateUseCase: GenerateRecurringTransactionsUseCase) {
        let scheduler = BackgroundTaskScheduler(generateUseCase: generateUseCase)

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: recurringTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task {
                await scheduler.handleRecurringTask(refreshTask)
            }
        }
    }

    /// Schedule the next background refresh task
    static func scheduleNextRefresh() {
        #if targetEnvironment(simulator)
        return
        #else
        let request = BGAppRefreshTaskRequest(identifier: recurringTaskID)
        // Schedule for 4 hours from now
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background task: \(error)")
        }
        #endif
    }

    /// Handle the background task execution
    private func handleRecurringTask(_ task: BGAppRefreshTask) async {
        // Schedule the next refresh
        Self.scheduleNextRefresh()

        do {
            let count = try await generateUseCase.execute()
            print("Generated \(count) recurring transactions")
            task.setTaskCompleted(success: true)
        } catch {
            print("Background task failed: \(error)")
            task.setTaskCompleted(success: false)
        }
    }
    #endif
}
