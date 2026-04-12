# Vittora Persistence & Sync Skill

Use this skill to implement SwiftData models, handle migrations, manage CloudKit synchronization, and maintain data integrity. Ensures proper offline-first architecture and conflict resolution.

## Overview
This skill covers SwiftData modeling, schema migrations, CloudKit integration, offline-first patterns, and repository layer implementation for data persistence.

---

## SwiftData Modeling

### Basic Model Structure
```swift
import SwiftData

@Model
final class UserEntity {
    @Attribute(.unique) var id: UUID
    @Attribute(.indexed) var email: String
    
    var firstName: String
    var lastName: String
    var phone: String?
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Relationships
    @Relationship(deleteRule: .cascade) var accounts: [AccountEntity]?
    
    init(id: UUID = UUID(), email: String, firstName: String, lastName: String, phone: String? = nil) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
    }
}
```

### Attribute Macros

#### #Unique
Applied to properties that must be unique across all model instances.

```swift
@Model
final class AccountEntity {
    @Attribute(.unique) var accountNumber: String
    @Attribute(.unique) var email: String
    
    var name: String
    var balance: Decimal
    var createdAt: Date = Date()
}
```

**When to Use:**
- User emails
- Account numbers
- External API identifiers
- Usernames
- Device identifiers

#### #Index
Applied to properties frequently used in queries for performance optimization.

```swift
@Model
final class TransactionEntity {
    @Attribute(.indexed) var id: UUID
    @Attribute(.indexed) var date: Date
    @Attribute(.indexed) var accountID: UUID
    @Attribute(.indexed) var status: TransactionStatus
    
    var amount: Decimal
    var description: String
    var createdAt: Date = Date()
}
```

**When to Use:**
- Date fields (frequently sorted/filtered)
- Account/owner IDs (relationship filtering)
- Status enums (state-based queries)
- Category fields (filtering by type)

### Relationships

#### One-to-Many
```swift
@Model
final class UserEntity {
    var id: UUID
    var email: String
    
    @Relationship(deleteRule: .cascade) var accounts: [AccountEntity]?
    @Relationship(deleteRule: .cascade) var transactions: [TransactionEntity]?
}

@Model
final class AccountEntity {
    var id: UUID
    var accountNumber: String
    var user: UserEntity? // Inverse relationship
}
```

#### Many-to-Many
SwiftData uses intermediate models for many-to-many relationships.

```swift
@Model
final class CategoryEntity {
    var id: UUID
    var name: String
    @Relationship(deleteRule: .cascade) var tags: [CategoryTagEntity]?
}

@Model
final class TagEntity {
    var id: UUID
    var name: String
    @Relationship(deleteRule: .cascade) var categories: [CategoryTagEntity]?
}

// Intermediate model
@Model
final class CategoryTagEntity {
    var category: CategoryEntity?
    var tag: TagEntity?
}
```

### Timestamps
Every persistent model should include timestamp tracking.

```swift
@Model
final class TransactionEntity {
    @Attribute(.unique) var id: UUID
    
    var amount: Decimal
    var description: String
    
    @Attribute(.indexed) var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // CloudKit sync state tracking
    var syncedAt: Date?
    var isSyncPending: Bool = true
}
```

**Checklist:**
- [ ] All @Model classes have #Unique properties when appropriate
- [ ] Frequently queried properties have #Index
- [ ] createdAt and updatedAt timestamps present
- [ ] Relationships defined with proper deleteRule
- [ ] No optional fields for required data
- [ ] Codable conformed for network serialization

---

## Model Container Configuration

### Development Configuration
```swift
import SwiftData

let container: ModelContainer

do {
    let config = ModelConfiguration(isStoredInMemoryOnly: false)
    container = try ModelContainer(for: UserEntity.self, AccountEntity.self, TransactionEntity.self, configurations: config)
} catch {
    fatalError("Could not initialize ModelContainer: \(error)")
}
```

### Testing Configuration (In-Memory)
```swift
let testContainer: ModelContainer

do {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    testContainer = try ModelContainer(for: UserEntity.self, AccountEntity.self, configurations: config)
} catch {
    fatalError("Could not initialize test ModelContainer: \(error)")
}
```

### CloudKit Integration
```swift
let container: ModelContainer

do {
    let cloudkitConfig = ModelConfiguration(
        schema: .init(entities: [UserEntity.self, AccountEntity.self, TransactionEntity.self]),
        url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("vittora.sqlite"),
        cloudKitDatabase: .automatic
    )
    
    container = try ModelContainer(for: UserEntity.self, configurations: cloudkitConfig)
} catch {
    fatalError("Could not initialize CloudKit ModelContainer: \(error)")
}
```

---

## Migration Strategy

### Version Tracking
```swift
enum SchemaVersion {
    static let current = SchemaVersion.v2
    
    enum v1 {
        static let models: [any Model.Type] = [
            UserEntity.self,
            AccountEntity.self
        ]
    }
    
    enum v2 {
        // Added TransactionEntity
        static let models: [any Model.Type] = [
            UserEntity.self,
            AccountEntity.self,
            TransactionEntity.self
        ]
    }
}
```

### Migration Example: Adding New Entity
```swift
@Model
final class TransactionEntity {
    @Attribute(.unique) var id: UUID
    var accountID: UUID
    var amount: Decimal
    var date: Date
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

// In AppDelegate or initialization:
do {
    let config = ModelConfiguration(
        schema: .init(entities: [
            UserEntity.self,
            AccountEntity.self,
            TransactionEntity.self  // New entity
        ])
    )
    container = try ModelContainer(for: configurations: config)
} catch {
    print("Migration failed: \(error)")
}
```

### Migration Example: Adding Property
```swift
@Model
final class AccountEntity {
    @Attribute(.unique) var id: UUID
    var accountNumber: String
    var balance: Decimal
    
    // New property - defaults to null initially
    var lastSyncedAt: Date?
}
```

### Migration Validation
```swift
@Test("validates migration from v1 to v2")
func testMigrationV1ToV2() async throws {
    // Create v1 data
    let oldContainer = try ModelContainer(
        for: UserEntity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    var user = UserEntity(email: "user@example.com", firstName: "John", lastName: "Doe")
    try oldContainer.mainContext.insert(user)
    
    // Simulate migration to v2
    let newContainer = try ModelContainer(
        for: UserEntity.self, AccountEntity.self, TransactionEntity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    // Verify data integrity
    let fetchDescriptor = FetchDescriptor<UserEntity>()
    let users = try newContainer.mainContext.fetch(fetchDescriptor)
    #expect(users.count == 1)
    #expect(users[0].email == "user@example.com")
}
```

---

## Query Patterns with #Predicate

### Basic Queries
```swift
import SwiftData

@Observable
class TransactionListViewModel {
    var transactions: [TransactionEntity] = []
    
    func loadTransactions(for accountID: UUID) {
        let predicate = #Predicate<TransactionEntity> { transaction in
            transaction.accountID == accountID
        }
        
        let fetchDescriptor = FetchDescriptor<TransactionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            transactions = try modelContext.fetch(fetchDescriptor)
        } catch {
            print("Failed to fetch transactions: \(error)")
        }
    }
}
```

### Complex Predicates
```swift
// Multiple conditions (AND)
let predicate = #Predicate<TransactionEntity> { transaction in
    transaction.accountID == accountID &&
    transaction.date >= startDate &&
    transaction.date <= endDate &&
    transaction.status == .completed
}

// OR conditions
let predicate = #Predicate<TransactionEntity> { transaction in
    transaction.status == .pending ||
    transaction.status == .failed
}

// Text contains
let predicate = #Predicate<TransactionEntity> { transaction in
    transaction.description.localizedCaseInsensitiveContains("grocery")
}
```

### Query with Limits
```swift
let fetchDescriptor = FetchDescriptor<TransactionEntity>(
    predicate: predicate,
    sortBy: [SortDescriptor(\.date, order: .reverse)]
)
fetchDescriptor.fetchLimit = 100

let transactions = try modelContext.fetch(fetchDescriptor)
```

**Predicate Checklist:**
- [ ] All filters use #Predicate (never manual filtering)
- [ ] Complex logic uses operators: &&, ||, !
- [ ] Predicates include type-safe property access
- [ ] Sorting specified with SortDescriptor
- [ ] Fetch limits applied for large datasets

---

## Conflict Resolution

### Concurrent Write Conflicts
```swift
@Observable
class TransactionViewModel {
    var transaction: TransactionEntity
    
    func saveTransaction() async throws {
        do {
            transaction.updatedAt = Date()
            try modelContext.save()
        } catch let error as SwiftDataError {
            switch error {
            case .versionMismatch:
                // Another process modified this record
                try await resolveVersionConflict()
            default:
                throw error
            }
        }
    }
    
    private func resolveVersionConflict() async throws {
        // Reload from database
        try modelContext.delete(model: TransactionEntity.self)
        
        // Refetch latest version
        let predicate = #Predicate<TransactionEntity> { $0.id == transaction.id }
        let fetchDescriptor = FetchDescriptor<TransactionEntity>(predicate: predicate)
        let latest = try modelContext.fetch(fetchDescriptor).first
        
        if let latest {
            self.transaction = latest
            // Notify user to retry
        }
    }
}
```

### Last-Write-Wins Strategy (Common)
```swift
@Model
final class TransactionEntity {
    @Attribute(.unique) var id: UUID
    var amount: Decimal
    var updatedAt: Date = Date()
    var deviceID: String = UIDevice.current.identifierForVendor?.uuidString ?? ""
    
    func merge(with remote: TransactionEntity) {
        // Remote write wins if more recent
        if remote.updatedAt > self.updatedAt {
            self.amount = remote.amount
            self.updatedAt = remote.updatedAt
            self.deviceID = remote.deviceID
        }
    }
}
```

### Sync State Tracking
```swift
enum SyncState: String, Codable {
    case synced
    case pending
    case failed
    case conflict
}

@Model
final class SyncAwareEntity {
    @Attribute(.unique) var id: UUID
    var syncState: SyncState = .pending
    var lastSyncError: String?
    var lastSyncAttempt: Date?
    var syncedAt: Date?
}
```

---

## Offline-First Architecture

### Model for Offline Sync
```swift
@Model
final class TransactionEntity {
    @Attribute(.unique) var id: UUID
    @Attribute(.indexed) var accountID: UUID
    
    var amount: Decimal
    var description: String
    var date: Date
    
    // Sync tracking
    @Attribute(.indexed) var syncState: String = "pending" // pending, synced, failed
    var syncedAt: Date?
    var lastSyncError: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    var isSyncPending: Bool {
        syncState == "pending"
    }
}
```

### Offline Queue Manager
```swift
@Observable
class OfflineSyncManager {
    var pendingTransactions: [TransactionEntity] = []
    var isSyncing: Bool = false
    
    @ObservationIgnored
    private let modelContext: ModelContext
    
    func syncPendingChanges() async throws {
        guard !isSyncing else { return }
        isSyncing = true
        
        defer { isSyncing = false }
        
        let predicate = #Predicate<TransactionEntity> { $0.syncState == "pending" }
        let fetchDescriptor = FetchDescriptor<TransactionEntity>(predicate: predicate)
        
        do {
            pendingTransactions = try modelContext.fetch(fetchDescriptor)
            
            for transaction in pendingTransactions {
                do {
                    try await syncTransaction(transaction)
                    transaction.syncState = "synced"
                    transaction.syncedAt = Date()
                } catch {
                    transaction.syncState = "failed"
                    transaction.lastSyncError = error.localizedDescription
                }
            }
            
            try modelContext.save()
        } catch {
            print("Sync failed: \(error)")
            throw error
        }
    }
    
    private func syncTransaction(_ transaction: TransactionEntity) async throws {
        // Call network API to sync
    }
}
```

### Offline-First Checklist
- [ ] All writes immediately saved to local database
- [ ] UI updated from local state (no waiting for network)
- [ ] Sync queue managed for offline changes
- [ ] Conflict resolution strategy defined
- [ ] User notified of sync status
- [ ] Retry logic for failed syncs
- [ ] Network connectivity monitoring

---

## CloudKit Synchronization

### CloudKit Setup
```swift
import CloudKit

@Observable
class CloudKitSyncManager {
    var isSyncing: Bool = false
    
    @ObservationIgnored
    private let container = CKContainer.default()
    
    func initializeCloudKitSync() async throws {
        // Request user permission
        try await container.userRecordID()
        
        // Configure zones if needed
        let zone = CKRecordZone(zoneName: "VittoraZone")
        _ = try await container.privateCloudDatabase.saveRecordZones([zone])
    }
    
    func syncLocalChangesToCloud() async throws {
        // Use SwiftData's CloudKit integration
        // or manually sync via CKDatabase
    }
}
```

### iCloud Documents Sync
For document-based data:
```swift
@Model
final class DocumentEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var content: String
    var fileURL: URL?
    
    var isSyncedToiCloud: Bool = false
    var lastCloudSync: Date?
}
```

### CloudKit Data Encryption
```swift
// SwiftData automatically encrypts sensitive fields in CloudKit
@Model
final class AccountEntity {
    @Attribute(.unique) var accountNumber: String // Auto-encrypted in CloudKit
    
    var balance: Decimal // Standard encryption
    var pin: String // Stored securely
}
```

---

## Repository Implementation

### Protocol Definition (Domain)
```swift
// Domain/Protocols/TransactionRepository.swift
protocol TransactionRepository: Sendable {
    func fetchTransactions(for accountID: UUID) async throws -> [TransactionEntity]
    func createTransaction(_ transaction: TransactionEntity) async throws -> TransactionEntity
    func updateTransaction(_ transaction: TransactionEntity) async throws
    func deleteTransaction(_ id: UUID) async throws
    func observeTransactionChanges(for accountID: UUID) -> AsyncStream<[TransactionEntity]>
}
```

### Implementation (Application/Infrastructure)
```swift
// Application/Repositories/TransactionRepository.swift
@MainActor
final class SwiftDataTransactionRepository: TransactionRepository {
    let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchTransactions(for accountID: UUID) async throws -> [TransactionEntity] {
        let predicate = #Predicate<TransactionEntity> { $0.accountID == accountID }
        let descriptor = FetchDescriptor<TransactionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func createTransaction(_ transaction: TransactionEntity) async throws -> TransactionEntity {
        modelContext.insert(transaction)
        try modelContext.save()
        return transaction
    }
    
    func updateTransaction(_ transaction: TransactionEntity) async throws {
        transaction.updatedAt = Date()
        try modelContext.save()
    }
    
    func deleteTransaction(_ id: UUID) async throws {
        let predicate = #Predicate<TransactionEntity> { $0.id == id }
        try modelContext.delete(model: TransactionEntity.self, where: predicate)
    }
    
    func observeTransactionChanges(for accountID: UUID) -> AsyncStream<[TransactionEntity]> {
        AsyncStream { continuation in
            Task {
                while true {
                    do {
                        let transactions = try await fetchTransactions(for: accountID)
                        continuation.yield(transactions)
                        try await Task.sleep(for: .seconds(1))
                    } catch {
                        continuation.finish()
                        break
                    }
                }
            }
        }
    }
}
```

### Repository Testing
```swift
@Suite("TransactionRepository Tests")
struct TransactionRepositoryTests {
    var repository: MockTransactionRepository!
    var testContainer: ModelContainer!
    
    init() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        testContainer = try ModelContainer(for: TransactionEntity.self, configurations: config)
        
        let modelContext = ModelContext(testContainer)
        repository = MockTransactionRepository(modelContext: modelContext)
    }
    
    @Test("creates transaction successfully")
    func testCreateTransaction() async throws {
        let transaction = TransactionEntity(
            id: UUID(),
            accountID: UUID(),
            amount: Decimal(100),
            date: Date()
        )
        
        let created = try await repository.createTransaction(transaction)
        #expect(created.id == transaction.id)
        #expect(created.amount == Decimal(100))
    }
}
```

---

## When to Use This Skill

- Designing new persistent models
- Implementing data migrations
- Setting up CloudKit synchronization
- Handling conflicts and sync errors
- Optimizing query performance
- Implementing offline functionality
- Validating data integrity
- Creating repository implementations

## Quick Reference

| Task | Command |
|------|---------|
| Add index to property | `@Attribute(.indexed)` |
| Mark unique property | `@Attribute(.unique)` |
| One-to-many relationship | `@Relationship(deleteRule: .cascade)` |
| Query with predicate | `#Predicate<EntityType> { ... }` |
| Fetch with sorting | `FetchDescriptor(..., sortBy: [SortDescriptor(...)])` |
| Save changes | `try modelContext.save()` |
| Delete entity | `try modelContext.delete(model: Type.self, where: predicate)` |

