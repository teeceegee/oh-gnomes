import Foundation

public struct OddsQuote: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let raceId: String
    public let gnomeId: String
    public let numerator: Int
    public let denominator: Int
    public let impliedProbability: Double
    public let rulesetVersion: String
    public let quotedAt: Date

    public var displayString: String {
        return "\(numerator)/\(denominator)"
    }

    public var decimalOdds: Double {
        return 1.0 + (Double(numerator) / Double(denominator))
    }

    /// Calculates return for a winning bet under the Stake + Profit rule (ADR-001)
    /// Formula: Total Return = Stake + Profit = Stake + (Stake * Numerator / Denominator)
    public func calculateReturnPennies(forStakePennies stake: Int) -> Int {
        guard denominator > 0 else { return stake }
        let profitPennies = (stake * numerator) / denominator
        return stake + profitPennies
    }

    public init(
        id: String = UUID().uuidString,
        raceId: String,
        gnomeId: String,
        numerator: Int,
        denominator: Int,
        impliedProbability: Double,
        rulesetVersion: String = "1.0.0",
        quotedAt: Date = Date()
    ) {
        self.id = id
        self.raceId = raceId
        self.gnomeId = gnomeId
        self.numerator = numerator
        self.denominator = denominator
        self.impliedProbability = impliedProbability
        self.rulesetVersion = rulesetVersion
        self.quotedAt = quotedAt
    }
}
