import Foundation
import GnomesCore

public actor SettlementService {
    private var settlementsByBetId: [String: Settlement] = [:]

    public init() {}

    /// Executes idempotent settlement for all accepted bets on a finished race
    public func settleBets(
        raceId: String,
        bets: [Bet],
        quotes: [OddsQuote],
        winningGnomeIds: [String],
        ledger: BankingLedger
    ) async throws -> [Settlement] {
        precondition(!winningGnomeIds.isEmpty, "Settlement requires at least one winning gnome")
        var results: [Settlement] = []

        let quoteMap = Dictionary(uniqueKeysWithValues: quotes.map { ($0.gnomeId, $0) })
        let isDeadHeat = winningGnomeIds.count > 1

        for bet in bets {
            // Idempotency check: if bet already settled, return existing settlement
            if let existing = settlementsByBetId[bet.id] {
                results.append(existing)
                continue
            }

            guard let quote = quoteMap[bet.gnomeId] else {
                continue
            }

            let isWinner = winningGnomeIds.contains(bet.gnomeId)

            if isWinner {
                let payoutPennies: Int
                let resultType: Settlement.SettlementResult

                if isDeadHeat {
                    // Fractional dead-heat rule: stake is divided by number of dead-heat winners
                    let dividedStake = max(1, bet.stakePennies / winningGnomeIds.count)
                    payoutPennies = quote.calculateReturnPennies(forStakePennies: dividedStake)
                    resultType = .deadHeatWin
                } else {
                    // Full Stake + Profit payout
                    payoutPennies = quote.calculateReturnPennies(forStakePennies: bet.stakePennies)
                    resultType = .win
                }

                let (before, after) = try await ledger.creditPayout(
                    playerId: bet.playerId,
                    betId: bet.id,
                    payoutPennies: payoutPennies
                )

                let settlement = Settlement(
                    raceId: raceId,
                    playerId: bet.playerId,
                    betId: bet.id,
                    result: resultType,
                    payoutPennies: payoutPennies,
                    balanceBeforePennies: before,
                    balanceAfterPennies: after
                )
                settlementsByBetId[bet.id] = settlement
                results.append(settlement)

            } else {
                // Losing bet: 0 payout
                let currentBal = await ledger.closeLosingBet(playerId: bet.playerId, betId: bet.id) ?? 0

                let settlement = Settlement(
                    raceId: raceId,
                    playerId: bet.playerId,
                    betId: bet.id,
                    result: .loss,
                    payoutPennies: 0,
                    balanceBeforePennies: currentBal,
                    balanceAfterPennies: currentBal
                )
                settlementsByBetId[bet.id] = settlement
                results.append(settlement)
            }
        }

        return results
    }

    /// Checks if a bet has already been settled
    public func getSettlement(betId: String) -> Settlement? {
        return settlementsByBetId[betId]
    }
}
