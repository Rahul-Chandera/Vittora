import Foundation
import OSLog
import SwiftData

#if os(iOS)
import BackgroundTasks
import VittoraCore
#endif

final class BackgroundTaskScheduler: Sendable {
    #if os(iOS)
    static let recurringTaskID = "com.enerjiktech.vittora.recurring-generation"
    #endif
    private static let logger = Logger(subsystem: "com.vittora.app", category: "background")

    private let coordinator: RecurringGenerationCoordinator

    init(coordinator: RecurringGenerationCoordinator) {
        self.coordinator = coordinator
    }

    #if os(iOS)
    /// Register background task handler for recurring transaction generation
    static func register(coordinator: RecurringGenerationCoordinator) {
        let scheduler = BackgroundTaskScheduler(coordinator: coordinator)

        // The launch handler's isolation must match the queue it runs on.
        //
        // `register` is called from the App's init, which is @MainActor, so
        // without this the closure inherits main-actor isolation. BackgroundTasks
        // then invokes it on its own queue — `using: nil` means a default
        // BACKGROUND queue, not the main one — and Swift 6's isolation check
        // traps: EXC_BREAKPOINT in _dispatch_assert_queue_fail, via
        // swift_task_isCurrentExecutorWithFlags.
        //
        // The app is launched into the background specifically to run this task
        // ("Role: Non UI" in the reports), so it crashed roughly a second after
        // launch every time iOS scheduled a refresh — meaning recurring
        // transactions never generated in the background. Present since 1.0.0;
        // invisible because the crash happens with no UI on screen.
        //
        // Fixed by running the handler ON the main queue rather than by
        // stripping the closure's isolation: BGAppRefreshTask is not Sendable,
        // so a @Sendable closure cannot hand it to the Task that does the work.
        // Passing `.main` makes the inherited assumption true instead. The
        // handler only spawns a Task, so this puts no real work on the main
        // queue, and the actual generation still runs on the coordinator actor.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: recurringTaskID,
            using: .main
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
            logger.error("Failed to schedule background task: \(error.localizedDescription)")
        }
        #endif
    }

    /// Handle the background task execution
    private func handleRecurringTask(_ task: BGAppRefreshTask) async {
        // Schedule the next refresh
        Self.scheduleNextRefresh()

        do {
            let count = try await coordinator.generate()
            Self.logger.info("Generated \(count) recurring transactions")
            task.setTaskCompleted(success: true)
        } catch {
            Self.logger.error("Background task failed: \(error.localizedDescription)")
            task.setTaskCompleted(success: false)
        }
    }
    #endif
}
