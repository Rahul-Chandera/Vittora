import Foundation
import LocalAuthentication
import Testing
import VittoraCore
@testable import Vittora

@Suite("Mock Infrastructure Tests")
@MainActor
struct MockInfrastructureTests {

    // MARK: - Repository write failure controls

    @Test("failOnNextWrite fails once then succeeds")
    func failOnNextWriteFailsOnce() async throws {
        let repo = MockAccountRepository()
        repo.writeFailureControls.failOnNextWriteCount = 1
        let account = AccountEntity(name: "Test", type: .bank, balance: 0)

        await #expect(throws: VittoraError.self) {
            try await repo.create(account)
        }
        try await repo.create(account)
        #expect(repo.accounts.count == 1)
    }

    @Test("failForID fails only matching entity writes")
    func failForIDIsScoped() async throws {
        let repo = MockAccountRepository()
        let blocked = AccountEntity(name: "Blocked", type: .bank, balance: 0)
        let allowed = AccountEntity(name: "Allowed", type: .bank, balance: 0)
        repo.writeFailureControls.failForIDs = [blocked.id]

        await #expect(throws: VittoraError.self) {
            try await repo.create(blocked)
        }
        try await repo.create(allowed)
        #expect(repo.accounts.count == 1)
        #expect(repo.accounts.first?.id == allowed.id)
    }

    @Test("failOnNextWrite on account update surfaces use-case error")
    func updateUseCaseSurfacesAccountWriteFailure() async throws {
        let accountRepo = MockAccountRepository()
        let transactionRepo = MockTransactionRepository()
        let account = AccountEntity(name: "Bank", type: .bank, balance: Decimal(800))
        await accountRepo.seed(account)

        let original = TransactionEntity(amount: 200, type: .expense, accountID: account.id)
        await transactionRepo.seed(original)

        accountRepo.writeFailureControls.failOnNextWriteCount = 1

        var updated = original
        updated.amount = 100

        let useCase = UpdateTransactionUseCase(
            transactionRepository: transactionRepo,
            ledgerWriting: MockLedgerWriting(
                transactionRepository: transactionRepo,
                accountRepository: accountRepo
            )
        )

        await #expect(throws: VittoraError.self) {
            try await useCase.execute(updated)
        }

        let unchanged = accountRepo.accounts.first { $0.id == account.id }
        #expect(unchanged?.balance == 800)
    }

    // MARK: - Keychain access class recording

    @Test("MockKeychainService records access class per key on save and load")
    func keychainRecordsAccessClass() async throws {
        let keychain = MockKeychainService()
        let data = Data([0x01, 0x02])

        try await keychain.save(data, forKey: "test.standard", access: .standard)
        try await keychain.save(data, forKey: "test.biometric", access: .biometricBound)
        _ = try await keychain.load(forKey: "test.standard", access: .standard)
        _ = try await keychain.load(forKey: "test.biometric", access: .biometricBound)

        #expect(keychain.accessClassUsed(forKey: "test.standard") == .standard)
        #expect(keychain.accessClassUsed(forKey: "test.biometric") == .biometricBound)
        #expect(keychain.loadAccessClassUsed(forKey: "test.standard") == .standard)
        #expect(keychain.loadAccessClassUsed(forKey: "test.biometric") == .biometricBound)
    }

    @Test("EncryptionService stores key with biometricBound access class")
    func encryptionKeyUsesBiometricBoundAccess() async throws {
        let keychain = MockKeychainService()
        #if DEBUG
        let service = EncryptionService(keychainService: keychain, useLegacyKeyPathForTesting: true)
        #else
        let service = EncryptionService(keychainService: keychain)
        #endif

        try await service.generateKey()
        #expect(keychain.accessClassUsed(forKey: "com.vittora.encryption.key") == .biometricBound)
    }

    // MARK: - Biometric LAError variants

    @Test("LAError userCancel returns false without throwing")
    func laErrorUserCancelReturnsFalse() async throws {
        let mock = MockBiometricService()
        mock.simulatedLAErrorCode = .userCancel

        let result = try await mock.authenticate(reason: "Test", allowPasscodeFallback: true)

        #expect(result == false)
    }

    @Test("LAError biometryLockout falls back to passcode when allowed")
    func laErrorLockoutFallsBackToPasscode() async throws {
        let mock = MockBiometricService()
        mock.simulatedLAErrorCode = .biometryLockout
        mock.shouldSucceed = true

        let result = try await mock.authenticate(reason: "Test", allowPasscodeFallback: true)

        #expect(result == true)
        #expect(mock.passcodeAuthenticateCallCount == 1)
    }

    @Test("LAError biometryLockout does not fall back when passcode disabled")
    func laErrorLockoutWithoutPasscodeReturnsFalse() async throws {
        let mock = MockBiometricService()
        mock.simulatedLAErrorCode = .biometryLockout

        let result = try await mock.authenticate(reason: "Test", allowPasscodeFallback: false)

        #expect(result == false)
        #expect(mock.passcodeAuthenticateCallCount == 0)
    }

    @Test("LAError authenticationFailed throws VittoraError")
    func laErrorAuthenticationFailedThrows() async {
        let mock = MockBiometricService()
        mock.simulatedLAErrorCode = .authenticationFailed

        await #expect(throws: VittoraError.self) {
            try await mock.authenticate(reason: "Test", allowPasscodeFallback: true)
        }
    }

    @Test("LAError appCancel on passcode path returns false")
    func laErrorPasscodeCancelReturnsFalse() async throws {
        let mock = MockBiometricService()
        mock.simulatedPasscodeLAErrorCode = .appCancel

        let result = try await mock.authenticateWithPasscode(reason: "Test")

        #expect(result == false)
    }
}
