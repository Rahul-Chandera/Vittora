import Foundation
import Testing

@testable import Vittora

@Suite("OnboardingViewModel Tests")
@MainActor
struct OnboardingViewModelTests {
    @Test("advance moves through the full onboarding flow")
    func advanceMovesThroughAllSteps() {
        let vm = OnboardingViewModel()

        #expect(vm.currentStep == .welcome)

        vm.advance()
        #expect(vm.currentStep == .currency)

        vm.advance()
        #expect(vm.currentStep == .profile)

        vm.advance()
        #expect(vm.currentStep == .account)

        vm.advance()
        #expect(vm.currentStep == .done)
    }

    @Test("account step requires valid first account details")
    func accountStepValidatesInput() {
        let vm = OnboardingViewModel()
        vm.currentStep = .account

        #expect(vm.canAdvance == false)

        vm.accountName = "Main Account"
        vm.openingBalance = "abc"
        #expect(vm.canAdvance == false)

        vm.openingBalance = "1250.50"
        #expect(vm.canAdvance == true)
    }

    @Test("complete persists onboarding values and creates the first account")
    func completePersistsValuesAndCreatesAccount() async throws {
        let defaultsContext = makeDefaults()
        defer { cleanup(defaultsContext) }
        let defaults = defaultsContext.defaults

        let repository = TestOnboardingAccountRepository()
        let vm = OnboardingViewModel(
            createAccountUseCase: CreateAccountUseCase(accountRepository: repository),
            userDefaults: defaults
        )
        let appState = AppState(isOnboardingComplete: false)

        vm.selectedCurrencyCode = "INR"
        vm.userName = "Rahul"
        vm.accountName = "Primary Wallet"
        vm.selectedAccountType = .digitalWallet
        vm.openingBalance = "2500"

        await vm.complete(appState: appState)

        #expect(vm.error == nil)
        #expect(appState.isOnboardingComplete == true)
        #expect(defaults.string(forKey: "vittora.currencyCode") == "INR")
        #expect(defaults.string(forKey: "vittora.userName") == "Rahul")
        #expect(defaults.bool(forKey: "vittora.onboardingComplete") == true)

        let accounts = await repository.accounts
        #expect(accounts.count == 1)
        #expect(accounts.first?.name == "Primary Wallet")
        #expect(accounts.first?.currencyCode == "INR")
        #expect(accounts.first?.type == .digitalWallet)
    }

    @Test("complete surfaces first account creation failures")
    func completeSurfacesAccountCreationFailures() async throws {
        let defaultsContext = makeDefaults()
        defer { cleanup(defaultsContext) }
        let defaults = defaultsContext.defaults

        let repository = TestOnboardingAccountRepository(shouldThrowOnCreate: true)
        let vm = OnboardingViewModel(
            createAccountUseCase: CreateAccountUseCase(accountRepository: repository),
            userDefaults: defaults
        )
        let appState = AppState(isOnboardingComplete: false)

        vm.accountName = "Primary Bank"
        vm.openingBalance = "500"

        await vm.complete(appState: appState)

        #expect(appState.isOnboardingComplete == false)
        #expect(vm.error != nil)
        #expect(defaults.bool(forKey: "vittora.onboardingComplete") == false)
        let accounts = await repository.accounts
        #expect(accounts.isEmpty)
    }

    private func makeDefaults() -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = "OnboardingViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return (suiteName, defaults)
    }

    private func cleanup(_ context: (suiteName: String, defaults: UserDefaults)) {
        context.defaults.removePersistentDomain(forName: context.suiteName)
    }
}

private actor TestOnboardingAccountRepository: AccountRepository {
    private(set) var accounts: [AccountEntity] = []
    private let shouldThrowOnCreate: Bool

    init(shouldThrowOnCreate: Bool = false) {
        self.shouldThrowOnCreate = shouldThrowOnCreate
    }

    func fetchAll() async throws -> [AccountEntity] {
        accounts
    }

    func fetchByID(_ id: UUID) async throws -> AccountEntity? {
        accounts.first { $0.id == id }
    }

    func create(_ entity: AccountEntity) async throws {
        if shouldThrowOnCreate {
            throw VittoraError.validationFailed("Unable to create first account")
        }
        accounts.append(entity)
    }

    func update(_ entity: AccountEntity) async throws {
        if let index = accounts.firstIndex(where: { $0.id == entity.id }) {
            accounts[index] = entity
        }
    }

    func delete(_ id: UUID) async throws {
        accounts.removeAll { $0.id == id }
    }

    func fetchByType(_ type: AccountType) async throws -> [AccountEntity] {
        accounts.filter { $0.type == type }
    }
}
