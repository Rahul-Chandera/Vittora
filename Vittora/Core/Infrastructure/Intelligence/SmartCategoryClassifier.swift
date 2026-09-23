import Foundation
import NaturalLanguage
import VittoraCore

/// On-device category classifier trained on the user's own transactions (M3.2.1).
///
/// # Why this shape
///
/// The plan asks for "a Core ML text classifier trained on user data
/// (on-device)". CreateML's `MLTextClassifier` can only *train* on macOS, so an
/// iOS app cannot fit one at runtime — and a model shipped in the bundle would
/// not be trained on the user's data, which is the part that matters here.
///
/// What does work on device is Apple's `NLEmbedding`: a neural sentence
/// embedding that ships with the OS. Each labelled transaction is embedded, a
/// centroid is computed per category, and a new description is classified by
/// cosine similarity to those centroids. The embedding is Apple's model; the
/// classifier on top is fitted entirely to this user's history and never leaves
/// the device.
///
/// Per the module's scope note this only ever *suggests* a category. Nothing
/// here decides anything on the user's behalf.
nonisolated struct SmartCategoryClassifier: Sendable {

    /// Below this, a category has too few examples for its centroid to mean
    /// anything — one transaction would make a category match its own wording
    /// and nothing else.
    nonisolated static let minimumExamplesPerCategory = 3

    /// Cosine similarity below this is not offered. Embeddings always return a
    /// nearest neighbour, so without a floor the classifier would confidently
    /// file "dentist" under Groceries because that is the least-bad match.
    nonisolated static let minimumConfidence = 0.45

    /// How much better the best match must be than the runner-up. Two categories
    /// scoring 0.61 and 0.60 is a coin toss, and presenting it as a suggestion
    /// would teach the user to distrust every suggestion.
    nonisolated static let minimumMargin = 0.05

    nonisolated struct Example: Sendable {
        nonisolated let text: String
        nonisolated let categoryID: UUID

        nonisolated init(text: String, categoryID: UUID) {
            self.text = text
            self.categoryID = categoryID
        }
    }

    nonisolated struct Prediction: Sendable, Equatable {
        nonisolated let categoryID: UUID
        /// Cosine similarity to the winning centroid, 0–1.
        nonisolated let confidence: Double
        /// How many of the user's transactions shaped that centroid, so a
        /// caller can say why it is suggesting this.
        nonisolated let supportingExamples: Int
    }

    /// Per-category centroid in embedding space. Fitting is cheap enough to do
    /// on demand; there is no model file and nothing to invalidate.
    nonisolated struct FittedModel: Sendable {
        nonisolated let centroids: [UUID: [Double]]
        nonisolated let exampleCounts: [UUID: Int]

        nonisolated var isEmpty: Bool { centroids.isEmpty }
    }

    /// Nil when the OS has no embedding for the current language, which is not
    /// an error — it means this device cannot offer the feature, and the caller
    /// falls back to the rule engine.
    nonisolated static func embedding(for language: NLLanguage = .english) -> NLEmbedding? {
        NLEmbedding.sentenceEmbedding(for: language)
    }

    /// Fits centroids from the user's labelled transactions.
    ///
    /// Categories with too few examples are dropped rather than included with a
    /// weak centroid: a category the model cannot represent should be absent,
    /// not quietly wrong.
    nonisolated func fit(examples: [Example], embedding: NLEmbedding) -> FittedModel {
        var sums: [UUID: [Double]] = [:]
        var counts: [UUID: Int] = [:]

        for example in examples {
            let text = Self.normalise(example.text)
            guard !text.isEmpty, let vector = embedding.vector(for: text) else { continue }
            if var running = sums[example.categoryID] {
                for index in running.indices { running[index] += vector[index] }
                sums[example.categoryID] = running
            } else {
                sums[example.categoryID] = vector
            }
            counts[example.categoryID, default: 0] += 1
        }

        var centroids: [UUID: [Double]] = [:]
        for (categoryID, sum) in sums {
            let count = counts[categoryID] ?? 0
            guard count >= Self.minimumExamplesPerCategory else { continue }
            centroids[categoryID] = sum.map { $0 / Double(count) }
        }
        return FittedModel(
            centroids: centroids,
            exampleCounts: counts.filter { centroids[$0.key] != nil }
        )
    }

    /// Nil rather than a low-confidence guess. A wrong suggestion costs more
    /// than no suggestion: the user has to notice it and undo it.
    nonisolated func predict(
        text: String,
        model: FittedModel,
        embedding: NLEmbedding
    ) -> Prediction? {
        let normalised = Self.normalise(text)
        guard !normalised.isEmpty,
              !model.isEmpty,
              let vector = embedding.vector(for: normalised)
        else { return nil }

        var scored: [(categoryID: UUID, score: Double)] = []
        for (categoryID, centroid) in model.centroids {
            scored.append((categoryID: categoryID, score: Self.cosineSimilarity(vector, centroid)))
        }
        // Sorted by score, then by UUID so equal scores resolve the same way on
        // every launch rather than following dictionary order.
        let ranked = scored.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.categoryID.uuidString < rhs.categoryID.uuidString
            }
            return lhs.score > rhs.score
        }

        guard let best = ranked.first, best.score >= Self.minimumConfidence else { return nil }
        if ranked.count > 1, best.score - ranked[1].score < Self.minimumMargin { return nil }

        return Prediction(
            categoryID: best.categoryID,
            confidence: best.score,
            supportingExamples: model.exampleCounts[best.categoryID] ?? 0
        )
    }

    // MARK: - Maths

    /// Cosine similarity, clamped to 0–1. Embeddings can produce small negative
    /// similarities; a negative "confidence" would be meaningless to show.
    nonisolated static func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        var dot = 0.0, lhsNorm = 0.0, rhsNorm = 0.0
        for index in lhs.indices {
            dot += lhs[index] * rhs[index]
            lhsNorm += lhs[index] * lhs[index]
            rhsNorm += rhs[index] * rhs[index]
        }
        guard lhsNorm > 0, rhsNorm > 0 else { return 0 }
        return max(0, min(1, dot / (lhsNorm.squareRoot() * rhsNorm.squareRoot())))
    }

    /// Lowercased, punctuation stripped, whitespace collapsed. Merchant strings
    /// arrive as "TESCO STORES 3411 LONDON" and "Tesco Stores, London" — the
    /// embedding handles wording, not formatting noise.
    nonisolated static func normalise(_ text: String) -> String {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
