import Foundation
import GnomesCore

public struct BookmakerService: Sendable {
    public static let standardFractionalLadder: [(numerator: Int, denominator: Int, decimal: Double)] = [
        (1, 2, 1.50),
        (4, 5, 1.80),
        (1, 1, 2.00),
        (6, 5, 2.20),
        (6, 4, 2.50),
        (7, 4, 2.75),
        (2, 1, 3.00),
        (5, 2, 3.50),
        (3, 1, 4.00),
        (7, 2, 4.50),
        (4, 1, 5.00),
        (9, 2, 5.50),
        (5, 1, 6.00),
        (6, 1, 7.00),
        (7, 1, 8.00),
        (8, 1, 9.00),
        (10, 1, 11.00),
        (12, 1, 13.00),
        (14, 1, 15.00),
        (16, 1, 17.00),
        (20, 1, 21.00),
        (25, 1, 26.00),
        (33, 1, 34.00)
    ]

    public init() {}

    /// Generates explainable, bounded odds quotes for the 8 entrants of a race
    public func generateQuotes(
        raceId: String,
        entrants: [Gnome],
        mudRatio: Double = 0.25,
        weatherModifier: Double = 1.0
    ) -> [OddsQuote] {
        precondition(entrants.count == 8, "Odds generation requires exactly 8 entrants")

        // 1. Calculate raw power scores
        var rawScores: [Double] = []
        for gnome in entrants {
            let a = gnome.baselineAttributes
            var score = (a.speed * 0.35) + (a.acceleration * 0.20) + (a.stamina * 0.25) + (a.balance * 0.20)

            // Trait affinities
            if mudRatio > 0.2 && gnome.traits.contains(where: { $0.effectCategory == .mudAffinity }) {
                score += 0.15
            }
            if gnome.traits.contains(where: { $0.effectCategory == .startBoost }) {
                score += 0.10
            }
            if gnome.traits.contains(where: { $0.effectCategory == .slipProne }) {
                score -= 0.12
            }

            // Career form weighting (-1.0 to +1.0 clamped)
            score += (gnome.career.formRating * 0.12)

            rawScores.append(max(0.1, score))
        }

        // 2. Softmax-like probability conversion with temperature for competitive variety
        let temperature = 0.30
        let expScores = rawScores.map { exp($0 / temperature) }
        let totalExp = expScores.reduce(0.0, +)
        let fairProbabilities = expScores.map { $0 / totalExp }

        // 3. Apply standard bookmaker margin (~112% overround)
        let bookmakerMargin = 1.12
        var quotes: [OddsQuote] = []

        for (idx, gnome) in entrants.enumerated() {
            let fairProb = fairProbabilities[idx]
            let marginedProb = fairProb * bookmakerMargin
            let targetDecimal = max(1.20, 1.0 / max(0.02, marginedProb))

            // Find closest standard UK fractional odds on the ladder
            let ladderMatch = Self.standardFractionalLadder.min(by: { abs($0.decimal - targetDecimal) < abs($1.decimal - targetDecimal) })!

            let quote = OddsQuote(
                raceId: raceId,
                gnomeId: gnome.id,
                numerator: ladderMatch.numerator,
                denominator: ladderMatch.denominator,
                impliedProbability: fairProb
            )
            quotes.append(quote)
        }

        return quotes
    }
}
