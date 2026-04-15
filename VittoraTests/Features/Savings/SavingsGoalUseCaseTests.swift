import Foundation
import Testing

@testable import Vittora

@Suite("Savings Goal Use Case Tests")
struct SavingsGoalUseCaseTests {

    // MARK: - FetchSavingsGoalsUseCase

    @Suite("FetchSavingsGoalsUseCase")
    struct FetchSavingsGoalsUseCaseTests {

        @Test("Execute returns all goals")
        func testFetchAll() async throws {
            let repo = MockSavingsGoalRepository()
            await repo.seed(SavingsGoalEntity(name: "Vacation", targetAmount: 3000))
            await repo.seed(SavingsGoalEntity(name: "Car", category: .vehicle, targetAmount: 15000, status: .achieved))

            let useCase = FetchSavingsGoalsUseCase(savingsGoalRepository: repo)
            let all = try await useCase.execute()

            #expect(all.count == 2)
        }

        @Test("ExecuteActive returns only active goals")
        func testFetchActive() async throws {
            let repo = MockSavingsGoalRepository()
            await repo.seed(SavingsGoalEntity(name: "Vacation", targetAmount: 2000, status: .active))
            await repo.seed(SavingsGoalEntity(name: "Done", targetAmount: 500, status: .achieved))
            await repo.seed(SavingsGoalEntity(name: "Paused", targetAmount: 1000, status: .paused))

            let useCase = FetchSavingsGoalsUseCase(savingsGoalRepository: repo)
            let active = try await useCase.executeActive()

            #expect(active.count == 1)
            #expect(active[0].name == "Vacation")
        }

        @Test("ExecuteProgressSummary returns correct aggregated counts and amounts")
        func testProgressSummary() async throws {
            let repo = MockSavingsGoalRepository()
            await repo.seed(SavingsGoalEntity(name: "A", targetAmount: 1000, currentAmount: 400, status: .active))
            await repo.seed(SavingsGoalEntity(name: "B", targetAmount: 500, currentAmount: 500, status: .achieved))
            await repo.seed(SavingsGoalEntity(name: "C", targetAmount: 2000, currentAmount: 0, status: .active))

            let useCase = FetchSavingsGoalsUseCase(savingsGoalRepository: repo)
            let summary = try await useCase.executeProgressSummary()

            #expect(summary.totalGoals == 3)
            #expect(summary.activeGoals == 2)
            #expect(summary.achievedGoals == 1)
            #expect(summary.totalTargetAmount == 3500)
            #expect(summary.totalSavedAmount == 900)
        }

        @Test("Progress summary with empty list returns zeros")
        func testEmptySummary() async throws {
            let useCase = FetchSavingsGoalsUseCase(savingsGoalRepository: MockSavingsGoalRepository())
            let summary = try await useCase.executeProgressSummary()

            #expect(summary.totalGoals == 0)
            #expect(summary.activeGoals == 0)
            #expect(summary.achievedGoals == 0)
            #expect(summary.totalTargetAmount == 0)
            #expect(summary.totalSavedAmount == 0)
            #expect(summary.overallProgressFraction == 0)
        }

        @Test("Propagates repository errors")
        func testPropagatesRepositoryError() async throws {
            let repo = MockSavingsGoalRepository()
            await repo.configureShouldThrow(true)

            let useCase = FetchSavingsGoalsUseCase(savingsGoalRepository: repo)

            await #expect(throws: (any Error).self) {
                try await useCase.execute()
            }
        }
    }

    // MARK: - SaveSavingsGoalUseCase

    @Suite("SaveSavingsGoalUseCase")
    struct SaveSavingsGoalUseCaseTests {

        // MARK: executeCreate

        @Test("Creates a valid savings goal")
        func testCreateValidGoal() async throws {
            let repo = MockSavingsGoalRepository()
            let useCase = SaveSavingsGoalUseCase(savingsGoalRepository: repo)

            let goal = try await useCase.executeCreate(
                name: "Emergency Fund",
                category: .emergency,
                targetAmount: 10000,
                currentAmount: 0,
                targetDate: nil,
                linkedAccountID: nil,
                note: nil,
                colorHex: "#FF0000"
            )

            let all = await repo.goals
            #expect(all.count == 1)
            #expect(goal.name == "Emergency Fund")
            #expect(goal.targetAmount == 10000)
            #expect(goal.status == .active)
        }

        @Test("Trims whitespace from name on create")
        func testCreateTrimsName() async throws {
            let repo = MockSavingsGoalRepository()
            let useCase = SaveSavingsGoalUseCase(savingsGoalRepository: repo)

            let goal = try await useCase.executeCreate(
                name: "  Trip  ",
                category: .travel,
                targetAmount: 2000,
                currentAmount: 0,
                targetDate: nil,
                linkedAccountID: nil,
                note: nil,
                colorHex: "#00FF00"
            )

            #expect(goal.name == "Trip")
        }

        @Test("Throws nameTooShort when name is less than 2 chars")
        func testThrowsNameTooShort() async throws {
            let useCase = SaveSavingsGoalUseCase(savingsGoalRepository: MockSavingsGoalRepository())

            await #expect(throws: (any Error).self) {
                try await useCase.executeCreate(
                    name: "A",
                    category: .other,
                    targetAmount: 500,
                    currentAmount: 0,
                    targetDate: nil,
                    linkedAccountID: nil,
                    note: nil,
                    colorHex: "#000000"
                )
            }
        }

        @Test("Throws nameTooShort for whitespace-only name")
        func testThrowsForWhitespaceOnlyName() async throws {
            let useCase = SaveSavingsGoalUseCase(savingsGoalRepository: MockSavingsGoalRepository())

            await #expect(throws: (any Error).self) {
                try await useCase.executeCreate(
                    name: "   ",
                    category: .other,
                    targetAmount: 500,
                    currentAmount: 0,
                    targetDate: nil,
                    linkedAccountID: nil,
                    note: nil,
                    colorHex: "#000000"
                )
            }
        }

        @Test("Throws invalidTarget when targetAmount is zero")
        func testThrowsInvalidTargetZero() async throws {
            let useCase = SaveSavingsGoalUseCase(savingsGoalRepository: MockSavingsGoalRepository())

            await #expect(throws: (any Error).self) {
                try await useCase.executeCreate(
                    name: "Valid Name",
                    category: .other,
                    targetAmount: 0,
                    currentAmount: 0,
                    targetDate: nil,
                    linkedAccountID: nil,
                    note: nil,
                    colorHex: "#000000"
                )
            }
        }

        @Test("Throws negativeCurrentAmount when currentAmount is negative")
        func testThrowsNegativeCurrentAmount() async throws {
            let useCase = SaveSavingsGoalUseCase(savingsGoalRepository: MockSavingsGoalRepository())

            await #expect(throws: (any Error).self) {
                try await useCase.executeCreate(
                    name: "Valid Name",
                    category: .other,
                    targetAmount: 1000,
                    currentAmount: -50,
                    targetDate: nil,
                    linkedAccountID: nil,
                    note: nil,
                    colorHex: "#000000"
                )
            }
        }

        // MARK: executeUpdate

        @Test("Updates goal without auto-achieving when currentAmount below target")
        func testUpdateDoesNotAutoAchieveWhenBelowTarget() async throws {
            let repo = MockSavingsGoalRepository()
            let goal = SavingsGoalEntity(
                name: "Car",
                category: .vehicle,
                targetAmount: 5000,
                currentAmount: 2000,
                status: .active
            )
            await repo.seed(goal)

            let useCase = SaveSavingsGoalUseCase(savingsGoalRepository: repo)
            try await useCase.executeUpdate(goal)

            let updated = await repo.goals.first { $0.id == goal.id }
            #expect(updated?.status == .active)
        }

        @Test("Auto-marks goal as achieved when currentAmount reaches target")
        func testAutoAchievesWhenFullyFunded() async throws {
            let repo = MockSavingsGoalRepository()
            let goal = SavingsGoalEntity(
                name: "Fund",
                category: .emergency,
                targetAmount: 1000,
                currentAmount: 1000,
                status: .active
            )
            await repo.seed(goal)

            let useCase = SaveSavingsGoalUseCase(savingsGoalRepository: repo)
            try await useCase.executeUpdate(goal)

            let updated = await repo.goals.first { $0.id == goal.id }
            #expect(updated?.status == .achieved)
        }

        @Test("Does not change status if already achieved on update")
        func testDoesNotRevertAchievedStatus() async throws {
            let repo = MockSavingsGoalRepository()
            let goal = SavingsGoalEntity(
                name: "Done",
                category: .other,
                targetAmount: 500,
                currentAmount: 600,
                status: .achieved
            )
            await repo.seed(goal)

            let useCase = SaveSavingsGoalUseCase(savingsGoalRepository: repo)
            // achieved goals: auto-mark condition requires status == .active, so status stays achieved
            try await useCase.executeUpdate(goal)

            let updated = await repo.goals.first { $0.id == goal.id }
            #expect(updated?.status == .achieved)
        }

        // MARK: executeAddContribution

        @Test("Adds contribution and updates goal's current amount")
        func testAddContribution() async throws {
            let repo = MockSavingsGoalRepository()
            let goal = SavingsGoalEntity(name: "Vacation", targetAmount: 3000, currentAmount: 1000)
            await repo.seed(goal)

            let useCase = SaveSavingsGoalUseCase(savingsGoalRepository: repo)
            let updated = try await useCase.executeAddContribution(goalID: goal.id, amount: 500)

            #expect(updated.currentAmount == 1500)
        }

        @Test("Auto-achieves goal when contribution reaches target")
        func testContributionAutoAchieves() async throws {
            let repo = MockSavingsGoalRepository()
            let goal = SavingsGoalEntity(
                name: "Gadget",
                category: .gadget,
                targetAmount: 1000,
                currentAmount: 900,
                status: .active
            )
            await repo.seed(goal)

            let useCase = SaveSavingsGoalUseCase(savingsGoalRepository: repo)
            let updated = try await useCase.executeAddContribution(goalID: goal.id, amount: 200)

            #expect(updated.status == .achieved)
            #expect(updated.currentAmount == 1100)
        }

        @Test("Throws when goal not found for contribution")
        func testThrowsWhenGoalNotFoundForContribution() async throws {
            let useCase = SaveSavingsGoalUseCase(savingsGoalRepository: MockSavingsGoalRepository())

            await #expect(throws: (any Error).self) {
                try await useCase.executeAddContribution(goalID: UUID(), amount: 100)
            }
        }

        @Test("Throws when contribution amount is zero")
        func testThrowsForZeroContribution() async throws {
            let repo = MockSavingsGoalRepository()
            let goal = SavingsGoalEntity(name: "Home", targetAmount: 50000)
            await repo.seed(goal)

            let useCase = SaveSavingsGoalUseCase(savingsGoalRepository: repo)

            await #expect(throws: (any Error).self) {
                try await useCase.executeAddContribution(goalID: goal.id, amount: 0)
            }
        }
    }
}
