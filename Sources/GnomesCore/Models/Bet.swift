import Foundation

public struct Bet: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let raceId: String
    public let playerId: String
    public let gnomeId: String
    public let stakePennies: Int
    public let betMode: BetMode
    public let oddsQuoteId: String
    public let quoteNumerator: Int
    public let quoteDenominator: Int
    public var status: BetStatus
    public let clientNonce: String
    public let acceptedAt: Date

    public static let minimumStakePennies: Int = 100 // £1.00

    public enum BetMode: String, Codable, Sendable {
        case win
        case place // Top 3 finish, pays 1/3 win profit + stake
    }

    public enum BetStatus: String, Codable, Sendable {
        case submitted
        case accepted
        case won
        case lost
        case deadHeatWon
        case voided
        case refunded
    }

    public var potentialReturnPennies: Int {
        guard quoteDenominator > 0 else { return stakePennies }
        let fullProfit = (stakePennies * quoteNumerator) / quoteDenominator
        switch betMode {
        case .win:
            return stakePennies + fullProfit
        case .place:
            let placeProfit = fullProfit / 3
            return stakePennies + max(1, placeProfit)
        }
    }

    public init(
        id: String = UUID().uuidString,
        raceId: String,
        playerId: String,
        gnomeId: String,
        stakePennies: Int,
        betMode: BetMode = .win,
        oddsQuoteId: String,
        quoteNumerator: Int,
        quoteDenominator: Int,
        status: BetStatus = .accepted,
        clientNonce: String = UUID().uuidString,
        acceptedAt: Date = Date()
    ) {
        self.id = id
        self.raceId = raceId
        self.playerId = playerId
        self.gnomeId = gnomeId
        self.stakePennies = stakePennies
        self.betMode = betMode
        self.oddsQuoteId = oddsQuoteId
        self.quoteNumerator = quoteNumerator
        self.quoteDenominator = quoteDenominator
        self.status = status
        self.clientNonce = clientNonce
        self.acceptedAt = acceptedAt
    }
}
