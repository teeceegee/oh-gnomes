import Foundation

public struct Settlement: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let raceId: String
    public let playerId: String
    public let betId: String
    public let result: SettlementResult
    public let payoutPennies: Int
    public let balanceBeforePennies: Int
    public let balanceAfterPennies: Int
    public let settledAt: Date

    public enum SettlementResult: String, Codable, Sendable {
        case win
        case loss
        case deadHeatWin
        case voidRefund
    }

    public init(
        id: String = UUID().uuidString,
        raceId: String,
        playerId: String,
        betId: String,
        result: SettlementResult,
        payoutPennies: Int,
        balanceBeforePennies: Int,
        balanceAfterPennies: Int,
        settledAt: Date = Date()
    ) {
        self.id = id
        self.raceId = raceId
        self.playerId = playerId
        self.betId = betId
        self.result = result
        self.payoutPennies = payoutPennies
        self.balanceBeforePennies = balanceBeforePennies
        self.balanceAfterPennies = balanceAfterPennies
        self.settledAt = settledAt
    }
}
