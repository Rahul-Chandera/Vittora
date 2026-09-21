import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// M2.7.5. The queue is the only thing standing between a widget tap and a lost expense,
/// so its failure modes matter more than its happy path.
@Suite("Quick Log Queue Tests")
struct QuickLogQueueTests {

    private func freshQueue() -> (QuickLogQueue, UserDefaults) {
        let suite = "quicklog-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        return (QuickLogQueue(defaults: defaults), defaults)
    }

    @Test("an enqueued tap comes back out")
    func roundTrip() {
        let (queue, _) = freshQueue()
        let entry = QuickLogEntry(amount: 120, categoryID: UUID(), note: "Coffee")

        #expect(queue.enqueue(entry))
        let pending = queue.pending()
        #expect(pending.count == 1)
        #expect(pending.first?.amount == 120)
        #expect(pending.first?.note == "Coffee")
    }

    /// The reason there is one key per entry rather than one shared array: a
    /// read-modify-write from two processes loses whichever tap interleaved badly.
    @Test("many entries all survive, in order")
    func manyEntriesSurvive() {
        let (queue, _) = freshQueue()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for index in 0..<25 {
            queue.enqueue(
                QuickLogEntry(
                    amount: Decimal(index + 1),
                    createdAt: base.addingTimeInterval(Double(index))
                )
            )
        }

        let pending = queue.pending()
        #expect(pending.count == 25)
        #expect(pending.map(\.amount) == (1...25).map { Decimal($0) })
        #expect(queue.pendingCount == 25)
    }

    @Test("removing one entry leaves the rest")
    func removeIsSurgical() {
        let (queue, _) = freshQueue()
        let keep = QuickLogEntry(amount: 10)
        let drop = QuickLogEntry(amount: 20)
        queue.enqueue(keep)
        queue.enqueue(drop)

        queue.remove(id: drop.id)

        #expect(queue.pending().map(\.id) == [keep.id])
    }

    @Test("a zero or negative amount is refused rather than queued")
    func nonPositiveAmountsAreRefused() {
        let (queue, _) = freshQueue()
        #expect(queue.enqueue(QuickLogEntry(amount: 0)) == false)
        #expect(queue.enqueue(QuickLogEntry(amount: -5)) == false)
        #expect(queue.pending().isEmpty)
    }

    /// One unreadable value must not block every other pending expense from reaching the
    /// ledger.
    @Test("a corrupt entry is skipped, not fatal")
    func corruptEntryIsSkipped() {
        let (queue, defaults) = freshQueue()
        let good = QuickLogEntry(amount: 99)
        queue.enqueue(good)
        defaults.set(Data("not json".utf8), forKey: QuickLogQueue.keyPrefix + UUID().uuidString)

        let pending = queue.pending()
        #expect(pending.map(\.id) == [good.id])
    }

    @Test("unrelated defaults keys are untouched")
    func unrelatedKeysAreIgnored() {
        let (queue, defaults) = freshQueue()
        defaults.set("something", forKey: "vittora.unrelated")
        queue.enqueue(QuickLogEntry(amount: 5))

        #expect(queue.pendingCount == 1)
        queue.removeAll()
        #expect(queue.pendingCount == 0)
        #expect(defaults.string(forKey: "vittora.unrelated") == "something")
    }
}
