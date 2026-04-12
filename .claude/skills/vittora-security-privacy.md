# Vittora Security & Privacy Skill

Use this skill to implement security best practices for Vittora. Covers sensitive data handling, encryption, authentication, biometric security, and financial/privacy compliance.

## Overview
This skill ensures Vittora protects user data, handles sensitive information securely, and complies with privacy regulations.

---

## No Sensitive Logging

### Logging Rules
Never log:
- Passwords or PINs
- API keys or tokens
- Credit card numbers
- Account numbers
- Social security numbers
- Biometric data
- Private user information

### Secure Logging Pattern
```swift
import os

let logger = Logger(subsystem: "com.vittora.app", category: "auth")

// ❌ WRONG - Logs sensitive data
class LoginViewModel {
    func login(email: String, password: String) async throws {
        logger.debug("Logging in user: \(email) with password: \(password)")
        
        do {
            let result = try await authService.login(email: email, password: password)
            logger.debug("Login token: \(result.token)")
        } catch {
            logger.error("Login failed with error: \(error)")
        }
    }
}

// ✓ CORRECT - No sensitive data in logs
@Observable
class LoginViewModel {
    func login(email: String, password: String) async throws {
        logger.debug("Login attempt started")
        
        do {
            let result = try await authService.login(email: email, password: password)
            logger.debug("Login succeeded")
        } catch {
            logger.error("Login failed: user not found or invalid credentials")
        }
    }
}
```

### Debug vs Production Logging
```swift
#if DEBUG
    let logLevel = OSLogType.debug
#else
    let logLevel = OSLogType.info
#endif

let logger = Logger(subsystem: "com.vittora.app", category: "auth")

logger.log(level: logLevel, "Processing request")
```

### Redaction for Logs
```swift
// When logs might contain sensitive data, redact it
func logTransaction(_ transaction: TransactionEntity) {
    let redactedDescription = String(redacting: transaction.description)
    logger.debug("Transaction: \(redactedDescription)")
}
```

**Logging Checklist:**
- [ ] No passwords logged (ever)
- [ ] No tokens or API keys logged
- [ ] No account numbers or financial data logged
- [ ] No PII (personally identifiable information) logged
- [ ] Debug-only logs wrapped in #if DEBUG
- [ ] Production logs use generic error messages

---

## Keychain Usage

### Secure Token Storage
```swift
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.vittora.app"
    
    // Store authentication token
    func storeToken(_ token: String, forKey key: String) throws {
        let data = token.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete if exists
        SecItemDelete(query as CFDictionary)
        
        // Store new value
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }
    
    // Retrieve token
    func retrieveToken(forKey key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else {
            throw KeychainError.retrieveFailed(status)
        }
        
        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return token
    }
    
    // Delete token
    func deleteToken(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

enum KeychainError: Error {
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidData
}
```

### Using Keychain in Auth Service
```swift
@Observable
class AuthService {
    private let keychain = KeychainManager.shared
    private let tokenKey = "auth_token"
    
    var isAuthenticated: Bool {
        (try? keychain.retrieveToken(forKey: tokenKey)) != nil
    }
    
    func login(email: String, password: String) async throws -> AuthResult {
        let result = try await performLogin(email: email, password: password)
        
        // Store token securely
        try keychain.storeToken(result.token, forKey: tokenKey)
        
        return result
    }
    
    func logout() throws {
        try keychain.deleteToken(forKey: tokenKey)
    }
    
    func getStoredToken() throws -> String? {
        try keychain.retrieveToken(forKey: tokenKey)
    }
}
```

**Keychain Checklist:**
- [ ] All tokens stored in Keychain (not UserDefaults)
- [ ] Sensitive strings stored securely
- [ ] kSecAttrAccessibleWhenUnlockedThisDeviceOnly used
- [ ] Tokens cleared on logout
- [ ] No hardcoded service names
- [ ] Error handling for storage failures

---

## Document Encryption (AES-GCM)

### Encrypt Sensitive Documents
```swift
import CryptoKit

class DocumentEncryption {
    static let shared = DocumentEncryption()
    
    private let keychain = KeychainManager.shared
    private let encryptionKeyId = "document_encryption_key"
    
    // Generate and store encryption key
    func ensureKeyExists() throws {
        if (try? keychain.retrieveToken(forKey: encryptionKeyId)) == nil {
            let key = SymmetricKey(size: .bits256)
            let keyData = key.withUnsafeBytes { Data($0) }
            let keyString = keyData.base64EncodedString()
            try keychain.storeToken(keyString, forKey: encryptionKeyId)
        }
    }
    
    private func getEncryptionKey() throws -> SymmetricKey {
        guard let keyString = try keychain.retrieveToken(forKey: encryptionKeyId),
              let keyData = Data(base64Encoded: keyString) else {
            throw EncryptionError.keyNotFound
        }
        return SymmetricKey(data: keyData)
    }
    
    // Encrypt document content
    func encrypt(_ plaintext: String) throws -> String {
        try ensureKeyExists()
        
        let key = try getEncryptionKey()
        let plaintextData = plaintext.data(using: .utf8)!
        
        let sealedBox = try AES.GCM.seal(plaintextData, using: key)
        
        // Combine nonce + ciphertext + tag for storage
        guard let combined = sealedBox.combined else {
            throw EncryptionError.sealingFailed
        }
        
        return combined.base64EncodedString()
    }
    
    // Decrypt document content
    func decrypt(_ ciphertext: String) throws -> String {
        let key = try getEncryptionKey()
        
        guard let combinedData = Data(base64Encoded: ciphertext) else {
            throw EncryptionError.invalidFormat
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
        let plaintextData = try AES.GCM.open(sealedBox, using: key)
        
        guard let plaintext = String(data: plaintextData, encoding: .utf8) else {
            throw EncryptionError.decodingFailed
        }
        
        return plaintext
    }
}

enum EncryptionError: Error {
    case keyNotFound
    case sealingFailed
    case invalidFormat
    case decodingFailed
}
```

### Encrypting File Data
```swift
class DocumentFileManager {
    func saveEncryptedDocument(_ content: String, to url: URL) throws {
        let encrypted = try DocumentEncryption.shared.encrypt(content)
        try encrypted.write(to: url, atomically: true, encoding: .utf8)
    }
    
    func loadEncryptedDocument(from url: URL) throws -> String {
        let encrypted = try String(contentsOf: url, encoding: .utf8)
        return try DocumentEncryption.shared.decrypt(encrypted)
    }
}
```

**Encryption Checklist:**
- [ ] Sensitive documents encrypted with AES-GCM
- [ ] Encryption keys stored in Keychain
- [ ] Keys generated securely (not hardcoded)
- [ ] Nonce properly handled (included in output)
- [ ] Authentication tag verified (GCM provides this)
- [ ] Decryption failures handled gracefully

---

## Biometric Authentication

### Face ID / Touch ID Integration
```swift
import LocalAuthentication

@Observable
class BiometricAuthManager {
    var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        #if os(iOS)
        return context.biometryType == .faceID ? .faceID : .touchID
        #elseif os(macOS)
        return .touchID
        #else
        return .none
        #endif
    }
    
    func authenticate() async throws -> Bool {
        let context = LAContext()
        context.localizedReason = String(localized: "Authenticate to access your account")
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: context.localizedReason
            )
            return success
        } catch let error as LAError {
            switch error.code {
            case .userCancel:
                throw BiometricError.userCancelled
            case .biometryNotAvailable:
                throw BiometricError.notAvailable
            case .biometryLockout:
                throw BiometricError.lockout
            case .userFallback:
                throw BiometricError.fallbackRequired
            default:
                throw BiometricError.authenticationFailed
            }
        }
    }
    
    func authenticateWithFallback() async throws {
        do {
            _ = try await authenticate()
        } catch BiometricError.fallbackRequired {
            // Show PIN entry screen
        } catch {
            throw error
        }
    }
}

enum BiometricType {
    case faceID
    case touchID
    case none
}

enum BiometricError: Error, LocalizedError {
    case userCancelled
    case notAvailable
    case lockout
    case fallbackRequired
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return String(localized: "Authentication was cancelled")
        case .notAvailable:
            return String(localized: "Biometric authentication is not available")
        case .lockout:
            return String(localized: "Biometric authentication is locked. Use your PIN.")
        case .fallbackRequired:
            return String(localized: "Use your PIN to authenticate")
        case .authenticationFailed:
            return String(localized: "Authentication failed")
        }
    }
}
```

### Biometric with Session Management
```swift
@Observable
class AppAuthManager {
    var isAuthenticated: Bool = false
    private var sessionTimeoutDate: Date?
    private let sessionTimeout: TimeInterval = 5 * 60 // 5 minutes
    
    func initiateSession() async throws {
        let biometric = BiometricAuthManager()
        
        if biometric.isBiometricAvailable {
            try await biometric.authenticate()
        } else {
            // Fall back to PIN
            try await promptForPIN()
        }
        
        isAuthenticated = true
        sessionTimeoutDate = Date().addingTimeInterval(sessionTimeout)
        
        // Monitor for timeout
        Task {
            await monitorSession()
        }
    }
    
    func endSession() {
        isAuthenticated = false
        sessionTimeoutDate = nil
    }
    
    private func monitorSession() async {
        while isAuthenticated {
            if let timeoutDate = sessionTimeoutDate, Date() > timeoutDate {
                endSession()
                break
            }
            try? await Task.sleep(for: .seconds(30))
        }
    }
}
```

**Biometric Checklist:**
- [ ] Face ID / Touch ID available and working
- [ ] Proper error handling for failures/lockout
- [ ] Fallback to PIN or password
- [ ] Session timeout implemented
- [ ] User can disable biometric for specific actions
- [ ] Biometric data never logged or transmitted

---

## iCloud & Cloud Data Security

### CloudKit Data Privacy
```swift
@Model
final class AccountEntity {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var accountNumber: String // Encrypted in CloudKit
    
    var accountHolderName: String // Encrypted
    var balance: Decimal
    
    // Never sync sensitive data
    // var pin: String // Store locally only
    // var securityQuestionAnswers: [String] // Store locally only
}
```

### Marking Sensitive Data
```swift
// In CloudKit schema (if using manual setup)
// Mark sensitive fields as encrypted:
// - Account numbers
// - Routing numbers
// - Names
// - Contact information

// Public-readable fields only:
// - Account types
// - Currency
// - Public profile info
```

### Local-Only vs CloudKit Sync
```swift
@Model
final class UserEntity {
    @Attribute(.unique) var id: UUID
    var email: String // Synced
    var firstName: String // Synced
    var lastName: String // Synced
    
    // Local storage only
    @Transient var pin: String?
    @Transient var biometricEnabled: Bool = false
    @Transient var sessionToken: String?
}
```

### Privacy Settings Respect
```swift
@Observable
class CloudSyncManager {
    var userAllowsCloudSync: Bool = false
    
    func syncIfAllowed(entity: some Model) async throws {
        guard userAllowsCloudSync else {
            logger.debug("Cloud sync disabled by user")
            return
        }
        
        try await performCloudSync(entity: entity)
    }
    
    func requestCloudSyncPermission() {
        // Show privacy dialog
        // Respect user choice in settings
    }
}
```

**Cloud Security Checklist:**
- [ ] Sensitive fields encrypted in CloudKit
- [ ] PII never synced to iCloud
- [ ] Local-only sensitive data marked @Transient
- [ ] User can control cloud sync
- [ ] CloudKit data encrypted in transit
- [ ] Sync failures don't expose data

---

## Financial App Compliance

### PCI DSS Guidelines (Card Data)
Never store or process:
- Full card numbers (store last 4 only)
- CVV/CVC codes
- Card PINs
- Card holder names

```swift
// ❌ WRONG - Storing full card data
@Model
final class PaymentMethodEntity {
    var cardNumber: String // VIOLATION
    var cvv: String // VIOLATION
    var expiryDate: String
}

// ✓ CORRECT - Last 4 digits only
@Model
final class PaymentMethodEntity {
    @Attribute(.unique) var id: UUID
    var last4Digits: String // Just "1234"
    var cardBrand: String // "Visa", "Mastercard"
    var expiryMonth: Int
    var expiryYear: Int
}
```

### Account Lockout for Failed Attempts
```swift
@Observable
class LoginAttemptManager {
    private var failedAttempts: [String: (count: Int, lastAttempt: Date)] = [:]
    private let maxAttempts = 5
    private let lockoutDuration: TimeInterval = 15 * 60 // 15 minutes
    
    func recordFailedAttempt(for userID: String) {
        let now = Date()
        
        if let existing = failedAttempts[userID] {
            let timeSinceLastAttempt = now.timeIntervalSince(existing.lastAttempt)
            
            if timeSinceLastAttempt > lockoutDuration {
                // Reset counter after lockout period
                failedAttempts[userID] = (1, now)
            } else {
                failedAttempts[userID] = (existing.count + 1, now)
            }
        } else {
            failedAttempts[userID] = (1, now)
        }
    }
    
    func isLockedOut(for userID: String) -> Bool {
        guard let attempt = failedAttempts[userID] else { return false }
        
        let timeSinceLastAttempt = Date().timeIntervalSince(attempt.lastAttempt)
        
        if attempt.count >= maxAttempts && timeSinceLastAttempt < lockoutDuration {
            return true
        }
        
        if timeSinceLastAttempt > lockoutDuration {
            failedAttempts[userID] = nil
        }
        
        return false
    }
    
    func recordSuccessfulLogin(for userID: String) {
        failedAttempts[userID] = nil
    }
}
```

### Financial Data Disclaimers
```swift
struct FinancialDisclaimer: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Important Disclosure")
                .font(.headline)
            
            Text("""
            This application provides financial tracking and analysis tools only. \
            It is not a substitute for professional financial advice. \
            
            Vittora is not a bank and does not store, process, or transmit \
            sensitive financial information directly. All banking operations \
            must be performed through your financial institution's secure systems.
            """)
            .font(.body)
            .foregroundColor(.secondary)
            
            Checkbox(isChecked: .constant(true)) {
                Text("I understand and agree to these terms")
            }
        }
        .padding()
    }
}
```

**Financial Compliance Checklist:**
- [ ] No full card numbers stored
- [ ] CVV never stored
- [ ] Last 4 digits only for payment methods
- [ ] Failed login attempts tracked
- [ ] Account lockout after 5 failures
- [ ] Financial disclaimers displayed
- [ ] Data encrypted in transit and at rest
- [ ] Compliance documentation maintained

---

## User Privacy Settings

### Granular Permission Control
```swift
@Model
final class PrivacySettings {
    @Attribute(.unique) var userID: UUID
    
    var allowLocationTracking: Bool = false
    var allowCloudSync: Bool = false
    var allowAnalytics: Bool = false
    var dataRetentionDays: Int = 90
    var allowBiometric: Bool = false
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

@Observable
class PrivacySettingsViewModel {
    @ObservationIgnored
    private let repository: PrivacySettingsRepository
    
    var settings: PrivacySettings?
    
    func updateSetting(_ setting: PrivacySetting, to value: Bool) async throws {
        guard var settings = settings else { return }
        
        switch setting {
        case .cloudSync:
            settings.allowCloudSync = value
        case .biometric:
            settings.allowBiometric = value
        case .analytics:
            settings.allowAnalytics = value
        }
        
        try await repository.update(settings)
        self.settings = settings
    }
}

enum PrivacySetting {
    case cloudSync
    case biometric
    case analytics
}
```

**Privacy Checklist:**
- [ ] User can control data collection
- [ ] Privacy settings easily accessible
- [ ] Default to most private option
- [ ] Clear explanations of data use
- [ ] Ability to delete account and data
- [ ] Regular privacy audits

---

## When to Use This Skill

- Implementing authentication
- Storing sensitive data
- Adding encryption
- Implementing biometric auth
- Preparing for app store review
- Compliance audits
- Security incident response
- Privacy policy development

## Security Quick Reference

| Element | Standard | Implementation |
|---------|----------|-----------------|
| Tokens | Keychain | KeychainManager |
| Documents | AES-GCM | DocumentEncryption |
| Biometric | Face ID/Touch ID | BiometricAuthManager |
| Account Lockout | 5 attempts | LoginAttemptManager |
| Session Timeout | 5 minutes | AppAuthManager |
| Card Storage | Last 4 only | PaymentMethodEntity |
| Logging | No PII | Logger with redaction |

