import CloudKit
import Foundation
import OSLog
import VittoraCore

/// Owns the household zone and keeps it in sync (M3.4.1).
///
/// One household at a time. Its owner syncs the zone in their private
/// database; everyone they invite syncs the same zone through their shared
/// database. Either way it is one `CKSyncEngine`, which queues writes made
/// offline and sends them when the network returns — the household keeps the
/// app's offline-first behaviour rather than failing a save with no signal.
///
/// Local state is a JSON file, not SwiftData: the main store mirrors itself
/// to the private database, and household records must not land there.
@MainActor
@Observable
final class HouseholdStore {
    static let shared = HouseholdStore()

    private static let logger = Logger(subsystem: "com.vittora.app", category: "household")
    nonisolated static let containerIdentifier = "iCloud.com.enerjiktech.vittora"
    /// How household zones are told apart from the SwiftData mirror's zone.
    nonisolated static let zonePrefix = "Household-"

    private(set) var role: HouseholdRole = .none
    private(set) var ledger = HouseholdLedger()
    private(set) var share: CKShare?
    private(set) var isWorking = false
    var lastError: String?
    /// Set when an invitation is accepted, so the app can open the household.
    var presentsHousehold = false

    /// False on the simulator, in tests, and in unsigned builds — anywhere
    /// `CKContainer` would abort the process rather than fail.
    let isAvailable: Bool

    private var zoneID: CKRecordZone.ID?
    private var memberID: String?
    private var engineState: CKSyncEngine.State.Serialization?
    private var engine: CKSyncEngine?
    private var didStart = false
    private let isDemo: Bool

    private init() {
        let args = ProcessInfo.processInfo.arguments
        let isTesting = args.contains("--uitesting")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let seedsDemo = args.contains("--uitesting") && args.contains("--ui-test-seed-household")
        isAvailable = (CloudKitRuntimeSupport.isEnabled && !isTesting) || seedsDemo
        isDemo = seedsDemo
        if seedsDemo { seedDemoHousehold() }
    }

    /// UI tests and screenshots only: an owned household with no engine and no
    /// share, so nothing touches CloudKit (which the simulator build lacks).
    private func seedDemoHousehold() {
        let groceries = HouseholdBudget(
            id: "demo-groceries", name: "Groceries", amount: 600,
            currencyCode: "USD", createdAt: .now
        )
        role = .owner
        memberID = "demo-me"
        ledger = HouseholdLedger(budgets: [groceries], expenses: [
            HouseholdExpense(id: "demo-1", budgetID: groceries.id, amount: Decimal(string: "84.20") ?? 0,
                             note: "Weekly shop", date: .now, memberID: "demo-me", memberName: "Alex"),
            HouseholdExpense(id: "demo-2", budgetID: groceries.id, amount: Decimal(string: "42.75") ?? 0,
                             note: "Farmers market", date: .now, memberID: "demo-sam", memberName: "Sam"),
        ])
    }

    private var container: CKContainer { CKContainer(identifier: Self.containerIdentifier) }

    var canEdit: Bool {
        HouseholdAccess.canEdit(role: role, permission: share?.currentUserParticipant?.permission)
    }

    var householdName: String {
        (share?[CKShare.SystemFieldKey.title] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? String(localized: "Household")
    }

    /// Everyone on the share, owner first, then by name.
    var members: [HouseholdMember] {
        guard let share else { return [] }
        return share.participants.map { participant in
            HouseholdMember(
                id: participant.participantID,
                name: Self.displayName(of: participant),
                isOwner: participant.role == .owner,
                isCurrentUser: participant == share.currentUserParticipant,
                canEdit: participant.role == .owner || participant.permission == .readWrite,
                hasAccepted: participant.acceptanceStatus == .accepted
            )
        }
        .sorted { ($0.isOwner ? 0 : 1, $0.name) < ($1.isOwner ? 0 : 1, $1.name) }
    }

    // MARK: - Lifecycle

    /// Called once at launch. Restores the cached household so it shows
    /// offline, and restarts syncing where it left off.
    func start() {
        guard isAvailable, !didStart else { return }
        didStart = true
        guard let saved = HouseholdPersistence.load(), saved.role != .none else {
            Task { await discoverExistingHousehold() }
            return
        }
        role = saved.role
        ledger = saved.ledger
        zoneID = saved.zoneID
        memberID = saved.memberID
        engineState = saved.engineState
        share = saved.share
        if role != .none { startEngine() }
    }

    /// A household created or joined on another of this user's devices exists
    /// only in CloudKit until this device looks for it. Owners find it among
    /// their private zones; participants among the zones shared with them.
    private func discoverExistingHousehold() async {
        do {
            for (database, discoveredRole) in [
                (container.privateCloudDatabase, HouseholdRole.owner),
                (container.sharedCloudDatabase, HouseholdRole.participant),
            ] {
                let zones = try await database.allRecordZones()
                guard let zone = zones.first(where: { $0.zoneID.zoneName.hasPrefix(Self.zonePrefix) }) else { continue }
                let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zone.zoneID)
                let fetchedShare = try await database.record(for: shareID) as? CKShare
                guard role == .none else { return }
                memberID = try await container.userRecordID().recordName
                zoneID = zone.zoneID
                share = fetchedShare
                role = discoveredRole
                persist()
                startEngine()
                await refresh()
                return
            }
        } catch {
            // Offline, or not signed in: nothing to discover yet. Tried again
            // on the next launch.
            Self.logger.info("Household discovery skipped: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refresh() async {
        guard let engine else { return }
        do {
            try await engine.fetchChanges()
        } catch {
            Self.logger.error("Household fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Owner

    /// Creates the zone and its share up front, online. The share has to exist
    /// before anyone can be invited, and doing it here means the invite sheet
    /// never has to wait on the network.
    func createHousehold(name: String) async {
        guard isAvailable, role == .none else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let database = container.privateCloudDatabase
            let zoneID = CKRecordZone.ID(zoneName: Self.zonePrefix + UUID().uuidString, ownerName: CKCurrentUserDefaultName)
            _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])

            let newShare = CKShare(recordZoneID: zoneID)
            newShare[CKShare.SystemFieldKey.title] = name
            newShare.publicPermission = .none
            let (saved, _) = try await database.modifyRecords(saving: [newShare], deleting: [])
            guard case .success(let record)? = saved[newShare.recordID], let savedShare = record as? CKShare else {
                throw CKError(.internalError)
            }

            memberID = try await container.userRecordID().recordName
            self.zoneID = zoneID
            share = savedShare
            role = .owner
            ledger = HouseholdLedger()
            engineState = nil
            persist()
            startEngine()
        } catch {
            Self.logger.error("Create household failed: \(error.localizedDescription, privacy: .public)")
            lastError = String(localized: "We couldn't create the household. Check that you're signed in to iCloud and online, then try again.")
        }
    }

    /// Deleting the zone ends sharing for everyone and removes the data from
    /// every member's device on their next sync.
    func deleteHousehold() async {
        guard role == .owner, let zoneID else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await container.privateCloudDatabase.modifyRecordZones(saving: [], deleting: [zoneID])
            await reset()
        } catch {
            lastError = String(localized: "We couldn't delete the household. Check that you're online, then try again.")
        }
    }

    // MARK: - Participant

    func accept(_ metadata: CKShare.Metadata) async {
        guard isAvailable else { return }
        guard role == .none || zoneID == metadata.share.recordID.zoneID else {
            lastError = String(localized: "You're already in a household. Leave it before joining another.")
            presentsHousehold = true
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await container.accept(metadata)
            memberID = try await container.userRecordID().recordName
            zoneID = metadata.share.recordID.zoneID
            share = metadata.share
            role = .participant
            ledger = HouseholdLedger()
            engineState = nil
            persist()
            startEngine()
            presentsHousehold = true
            await refresh()
        } catch {
            Self.logger.error("Accept share failed: \(error.localizedDescription, privacy: .public)")
            lastError = String(localized: "We couldn't join the household. Ask for a new invitation and try again.")
            presentsHousehold = true
        }
    }

    /// A participant deleting the share from their shared database removes
    /// only themselves; the household carries on for everyone else.
    func leaveHousehold() async {
        guard role == .participant, let share else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await container.sharedCloudDatabase.modifyRecords(saving: [], deleting: [share.recordID])
            await reset()
        } catch {
            lastError = String(localized: "We couldn't leave the household. Check that you're online, then try again.")
        }
    }

    // MARK: - Editing (M3.4.2)

    func addBudget(name: String, amount: Decimal, currencyCode: String) {
        guard canEdit else { return }
        let budget = HouseholdBudget(
            id: UUID().uuidString, name: name, amount: amount,
            currencyCode: currencyCode, createdAt: .now
        )
        ledger.budgets.append(budget)
        enqueueSave(budget.id)
    }

    func deleteBudget(_ budget: HouseholdBudget) {
        guard canEdit else { return }
        let ids = [budget.id] + ledger.expenseIDs(belongingTo: budget.id)
        ledger.apply(modified: [], deletedRecordNames: ids)
        enqueueDelete(ids)
    }

    func addExpense(to budget: HouseholdBudget, amount: Decimal, note: String) {
        guard canEdit, let memberID else { return }
        let expense = HouseholdExpense(
            id: UUID().uuidString, budgetID: budget.id, amount: amount,
            note: note, date: .now, memberID: memberID,
            memberName: share?.currentUserParticipant.map(Self.displayName(of:)) ?? ""
        )
        ledger.expenses.append(expense)
        enqueueSave(expense.id)
    }

    func deleteExpense(_ expense: HouseholdExpense) {
        guard canEdit else { return }
        ledger.apply(modified: [], deletedRecordNames: [expense.id])
        enqueueDelete([expense.id])
    }

    // MARK: - Engine

    private func startEngine() {
        let database = role == .owner ? container.privateCloudDatabase : container.sharedCloudDatabase
        let configuration = CKSyncEngine.Configuration(
            database: database,
            stateSerialization: engineState,
            delegate: HouseholdSyncDelegate(store: self)
        )
        engine = CKSyncEngine(configuration)
    }

    private func enqueueSave(_ recordName: String) {
        persist()
        guard let engine, let zoneID else { return }
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(CKRecord.ID(recordName: recordName, zoneID: zoneID))])
    }

    private func enqueueDelete(_ recordNames: [String]) {
        persist()
        guard let engine, let zoneID else { return }
        engine.state.add(pendingRecordZoneChanges: recordNames.map {
            .deleteRecord(CKRecord.ID(recordName: $0, zoneID: zoneID))
        })
    }

    /// The zone this household syncs, so the private engine never downloads
    /// the SwiftData mirror's zone sitting in the same database.
    fileprivate var syncedZoneIDs: [CKRecordZone.ID] { zoneID.map { [$0] } ?? [] }

    /// The record to send for a pending save, or nil when it has since been
    /// deleted locally — the engine then drops the change.
    fileprivate func record(for recordID: CKRecord.ID) -> CKRecord? {
        guard let zoneID, recordID.zoneID == zoneID else { return nil }
        if let budget = ledger.budgets.first(where: { $0.id == recordID.recordName }) {
            return budget.makeRecord(in: zoneID)
        }
        if let expense = ledger.expenses.first(where: { $0.id == recordID.recordName }) {
            return expense.makeRecord(in: zoneID)
        }
        return nil
    }

    fileprivate func handle(_ event: CKSyncEngine.Event) async {
        switch event {
        case .stateUpdate(let update):
            engineState = update.stateSerialization
            persist()

        case .accountChange(let change):
            // Another iCloud account must never see this one's household.
            switch change.changeType {
            case .signIn: break
            case .signOut, .switchAccounts: await reset()
            @unknown default: break
            }

        case .fetchedDatabaseChanges(let changes):
            if let zoneID, changes.deletions.contains(where: { $0.zoneID == zoneID }) {
                // The owner deleted it, or removed this member.
                await reset()
                lastError = String(localized: "This household is no longer shared with you.")
            }

        case .fetchedRecordZoneChanges(let changes):
            let records = changes.modifications.map(\.record)
            if let fetchedShare = records.lazy.compactMap({ $0 as? CKShare }).first {
                share = fetchedShare
            }
            ledger.apply(
                modified: records,
                deletedRecordNames: changes.deletions.map(\.recordID.recordName)
            )
            persist()

        case .sentRecordZoneChanges(let sent):
            handleFailedSaves(sent.failedRecordSaves)

        default:
            break
        }
    }

    private func handleFailedSaves(_ failures: [CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave]) {
        guard !failures.isEmpty else { return }
        var rejected: [String] = []
        for failure in failures {
            switch failure.error.code {
            case .serverRecordChanged:
                // Already on the server — a retry after an interrupted send.
                continue
            case .permissionFailure:
                // View-only member; the server is the authority. Drop the
                // local copy so the screen stops showing what was refused.
                rejected.append(failure.record.recordID.recordName)
            case .zoneNotFound, .userDeletedZone:
                rejected.append(failure.record.recordID.recordName)
                lastError = String(localized: "This household no longer exists.")
            default:
                Self.logger.error("Household save failed: \(failure.error.code.rawValue, privacy: .public)")
            }
        }
        if !rejected.isEmpty {
            ledger.apply(modified: [], deletedRecordNames: rejected)
            if lastError == nil {
                lastError = String(localized: "You can view this household but not change it. Ask its owner for edit access.")
            }
            persist()
        }
    }

    private func reset() async {
        await engine?.cancelOperations()
        engine = nil
        role = .none
        ledger = HouseholdLedger()
        share = nil
        zoneID = nil
        engineState = nil
        HouseholdPersistence.clear()
    }

    private func persist() {
        guard !isDemo else { return }
        HouseholdPersistence.save(HouseholdPersistence.Snapshot(
            role: role, ledger: ledger, zoneID: zoneID, memberID: memberID,
            engineState: engineState, share: share
        ))
    }

    nonisolated static func displayName(of participant: CKShare.Participant) -> String {
        if let components = participant.userIdentity.nameComponents {
            let name = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
            if !name.isEmpty { return name }
        }
        return participant.userIdentity.lookupInfo?.emailAddress
            ?? String(localized: "Household member")
    }
}

struct HouseholdMember: Identifiable, Equatable {
    let id: String
    let name: String
    let isOwner: Bool
    let isCurrentUser: Bool
    let canEdit: Bool
    let hasAccepted: Bool
}

/// The engine's delegate, kept separate so the store's main-actor state is
/// only touched on the main actor. CKSyncEngine calls in from its own queue.
/// Holds the store strongly: the store is a process-lifetime singleton, so the
/// store → engine → delegate → store cycle costs nothing.
private nonisolated final class HouseholdSyncDelegate: CKSyncEngineDelegate {
    private let store: HouseholdStore

    init(store: HouseholdStore) { self.store = store }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        await store.handle(event)
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        guard !pending.isEmpty else { return nil }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { [store] recordID in
            await store.record(for: recordID)
        }
    }

    func nextFetchChangesOptions(
        _ context: CKSyncEngine.FetchChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.FetchChangesOptions {
        let zones = await store.syncedZoneIDs
        return CKSyncEngine.FetchChangesOptions(scope: .zoneIDs(zones))
    }
}

// MARK: - Persistence

/// The cached household, in the app's own container with full file
/// protection like the rest of the financial data at rest.
nonisolated enum HouseholdPersistence {
    struct Snapshot: Codable {
        var role: HouseholdRole
        var ledger: HouseholdLedger
        var zoneName: String?
        var zoneOwner: String?
        var memberID: String?
        var engineState: CKSyncEngine.State.Serialization?
        var shareData: Data?

        init(
            role: HouseholdRole, ledger: HouseholdLedger, zoneID: CKRecordZone.ID?,
            memberID: String?, engineState: CKSyncEngine.State.Serialization?, share: CKShare?
        ) {
            self.role = role
            self.ledger = ledger
            self.zoneName = zoneID?.zoneName
            self.zoneOwner = zoneID?.ownerName
            self.memberID = memberID
            self.engineState = engineState
            self.shareData = share.flatMap {
                try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)
            }
        }

        var zoneID: CKRecordZone.ID? {
            guard let zoneName, let zoneOwner else { return nil }
            return CKRecordZone.ID(zoneName: zoneName, ownerName: zoneOwner)
        }

        var share: CKShare? {
            shareData.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKShare.self, from: $0) }
        }
    }

    private static var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Household", isDirectory: true)
            .appendingPathComponent("household.json")
    }

    static func load() -> Snapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    static func save(_ snapshot: Snapshot) {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(snapshot)
            // UnlessOpen, not complete: CKSyncEngine can deliver changes
            // while the device is locked, and the write must not fail then.
            #if os(iOS)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            #else
            try data.write(to: fileURL, options: .atomic)
            #endif
        } catch {
            Logger(subsystem: "com.vittora.app", category: "household")
                .error("Household cache write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func clear() {
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
