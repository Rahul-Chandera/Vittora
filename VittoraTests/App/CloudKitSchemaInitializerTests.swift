#if DEBUG
import CloudKit
import Foundation
import Testing
@testable import Vittora

/// The household record types are raw CloudKit, so no SwiftData schema bump
/// flags a new field and `initializeCloudKitSchema` never sees them. The
/// initializer creates them by saving one sample of each through `makeRecord`;
/// a field reaches the Development schema — and so the Production deploy —
/// only if that sample's record carries a value for it.
///
/// So: every stored property of each sample, bar `id` (the record name), must
/// be a key on the record it makes. A new optional property the sample leaves
/// nil fails here; give the sample a value. A new property `makeRecord` does not
/// write fails too, since it would never sync. If `makeRecord` ever stores a
/// property under a different key, map it here.
@Suite("CloudKit schema initializer")
@MainActor
struct CloudKitSchemaInitializerTests {

    private let zoneID = CKRecordZone.ID(zoneName: "ckschema-test", ownerName: CKCurrentUserDefaultName)

    private func fieldsMissing(from record: CKRecord, for sample: Any) -> [String] {
        let keys = Set(record.allKeys())
        return Mirror(reflecting: sample).children
            .compactMap(\.label)
            .filter { $0 != "id" && !keys.contains($0) }
    }

    @Test("the household budget sample writes every field")
    func budgetSampleCoversEveryField() {
        let sample = CloudKitSchemaInitializer.householdBudget
        #expect(fieldsMissing(from: sample.makeRecord(in: zoneID), for: sample) == [])
    }

    @Test("the household expense sample writes every field")
    func expenseSampleCoversEveryField() {
        let sample = CloudKitSchemaInitializer.householdExpense
        #expect(fieldsMissing(from: sample.makeRecord(in: zoneID), for: sample) == [])
    }
}
#endif
