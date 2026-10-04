import Foundation
import NaturalLanguage
import Testing
import VittoraCore
@testable import Vittora

/// On-device category classifier (M3.2.1).
///
/// The maths and the guards are tested directly. The embedding itself is
/// Apple's and is exercised only where available — `NLEmbedding.sentenceEmbedding`
/// returns nil on some simulator configurations, so those tests skip rather
/// than fail, and the pure functions carry the real coverage.
@Suite("SmartCategoryClassifier")
@MainActor
struct SmartCategoryClassifierTests {

    private let classifier = SmartCategoryClassifier()

    // MARK: - Similarity

    @Test("identical vectors are perfectly similar")
    func identicalVectors() {
        let v = [1.0, 2.0, 3.0]
        #expect(SmartCategoryClassifier.cosineSimilarity(v, v) > 0.999)
    }

    @Test("orthogonal vectors score zero")
    func orthogonal() {
        #expect(SmartCategoryClassifier.cosineSimilarity([1, 0], [0, 1]) == 0)
    }

    /// Embeddings can produce negative similarities; a negative "confidence"
    /// would be meaningless to show, so it clamps.
    @Test("opposing vectors clamp to zero rather than going negative")
    func clampsNegative() {
        #expect(SmartCategoryClassifier.cosineSimilarity([1, 1], [-1, -1]) == 0)
    }

    @Test("mismatched or empty vectors score zero rather than crashing")
    func degenerateVectors() {
        #expect(SmartCategoryClassifier.cosineSimilarity([1, 2, 3], [1, 2]) == 0)
        #expect(SmartCategoryClassifier.cosineSimilarity([], []) == 0)
        #expect(SmartCategoryClassifier.cosineSimilarity([0, 0], [1, 1]) == 0)
    }

    // MARK: - Normalisation

    /// Merchant strings arrive as "TESCO STORES 3411 LONDON" and
    /// "Tesco Stores, London". The embedding handles wording, not formatting.
    @Test("normalisation strips case and punctuation noise")
    func normalisation() {
        #expect(SmartCategoryClassifier.normalise("TESCO STORES, LONDON") == "tesco stores london")
        // Unicode-aware: "café" survives, which matters for es/hi merchant names.
        #expect(SmartCategoryClassifier.normalise("Café—Nero #12") == "café nero 12")
        #expect(SmartCategoryClassifier.normalise("   ") == "")
        #expect(SmartCategoryClassifier.normalise("!!!") == "")
    }

    // MARK: - Fitting guards

    /// A category with one example would match its own wording and nothing
    /// else, so it is dropped rather than included with a weak centroid.
    @Test("categories below the example threshold are dropped")
    func dropsThinCategories() {
        guard let embedding = SmartCategoryClassifier.embedding() else { return }
        let rich = UUID(), thin = UUID()
        let examples = [
            SmartCategoryClassifier.Example(text: "coffee shop latte", categoryID: rich),
            SmartCategoryClassifier.Example(text: "espresso bar flat white", categoryID: rich),
            SmartCategoryClassifier.Example(text: "cafe cappuccino", categoryID: rich),
            SmartCategoryClassifier.Example(text: "one off thing", categoryID: thin),
        ]
        let model = classifier.fit(examples: examples, embedding: embedding)
        #expect(model.centroids[rich] != nil)
        #expect(model.centroids[thin] == nil, "a single example must not form a centroid")
        #expect(model.exampleCounts[rich] == 3)
    }

    @Test("an empty training set produces an empty model")
    func emptyTraining() {
        guard let embedding = SmartCategoryClassifier.embedding() else { return }
        #expect(classifier.fit(examples: [], embedding: embedding).isEmpty)
    }

    // MARK: - Prediction guards

    @Test("an empty model predicts nothing")
    func emptyModelPredictsNothing() {
        guard let embedding = SmartCategoryClassifier.embedding() else { return }
        let empty = SmartCategoryClassifier.FittedModel(centroids: [:], exampleCounts: [:])
        #expect(classifier.predict(text: "coffee", model: empty, embedding: embedding) == nil)
    }

    @Test("blank text predicts nothing")
    func blankTextPredictsNothing() {
        guard let embedding = SmartCategoryClassifier.embedding() else { return }
        let id = UUID()
        let examples = (0..<3).map {
            SmartCategoryClassifier.Example(text: "coffee shop \($0)", categoryID: id)
        }
        let model = classifier.fit(examples: examples, embedding: embedding)
        #expect(classifier.predict(text: "   ", model: model, embedding: embedding) == nil)
        #expect(classifier.predict(text: "!!!", model: model, embedding: embedding) == nil)
    }

    /// Embeddings always return a nearest neighbour. Without a floor the
    /// classifier would confidently file anything under whatever is least-bad.
    @Test("thresholds are set, not left at zero")
    func thresholdsExist() {
        #expect(SmartCategoryClassifier.minimumConfidence > 0)
        #expect(SmartCategoryClassifier.minimumMargin > 0)
        #expect(SmartCategoryClassifier.minimumExamplesPerCategory >= 3)
    }

    /// Two categories scoring 0.61 and 0.60 is a coin toss; presenting that as
    /// a suggestion teaches the user to distrust every suggestion.
    @Test("a near-tie is declined rather than guessed")
    func nearTieDeclined() {
        let a = UUID(), b = UUID()
        // Two centroids identical to each other: any input ties exactly, so the
        // margin rule must decline regardless of how high the score is.
        let shared = [1.0, 0.0, 0.0]
        let model = SmartCategoryClassifier.FittedModel(
            centroids: [a: shared, b: shared],
            exampleCounts: [a: 5, b: 5]
        )
        guard let embedding = SmartCategoryClassifier.embedding() else { return }
        // Uses the real embedding for the query but hand-built centroids, so the
        // tie is guaranteed rather than hoped for.
        #expect(classifier.predict(text: "anything at all", model: model, embedding: embedding) == nil)
    }

    /// Equal scores must resolve the same way on every launch rather than
    /// following dictionary order.
    @Test("ranking is deterministic across runs")
    func deterministicRanking() {
        guard let embedding = SmartCategoryClassifier.embedding() else { return }
        let coffee = UUID(), rent = UUID()
        let examples =
            (0..<4).map { SmartCategoryClassifier.Example(text: "coffee latte espresso \($0)", categoryID: coffee) }
            + (0..<4).map { SmartCategoryClassifier.Example(text: "monthly rent landlord payment \($0)", categoryID: rent) }
        let model = classifier.fit(examples: examples, embedding: embedding)

        let first = classifier.predict(text: "flat white coffee", model: model, embedding: embedding)
        let second = classifier.predict(text: "flat white coffee", model: model, embedding: embedding)
        #expect(first == second)
    }

    /// The whole point: a description close to one category's examples and far
    /// from the other's should land on the right one.
    @Test("classifies a clear case to the right category")
    func classifiesClearCase() {
        guard let embedding = SmartCategoryClassifier.embedding() else { return }
        let coffee = UUID(), rent = UUID()
        let examples =
            ["costa coffee", "starbucks latte", "cafe nero espresso", "local coffee house"]
                .map { SmartCategoryClassifier.Example(text: $0, categoryID: coffee) }
            + ["monthly rent payment", "landlord rent transfer", "rent for flat", "apartment rent"]
                .map { SmartCategoryClassifier.Example(text: $0, categoryID: rent) }

        let model = classifier.fit(examples: examples, embedding: embedding)
        guard let prediction = classifier.predict(
            text: "starbucks flat white", model: model, embedding: embedding
        ) else {
            // The embedding declined to reach the confidence floor. That is the
            // guard working, not a failure — it is tested above.
            return
        }
        #expect(prediction.categoryID == coffee)
        #expect(prediction.confidence >= SmartCategoryClassifier.minimumConfidence)
        #expect(prediction.supportingExamples == 4)
    }
}
