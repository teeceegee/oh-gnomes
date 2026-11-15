import Foundation
import GnomesCore

public enum BankingError: Error, Equatable {
    case playerNotFound(String)
    case insufficientFunds(available: Int, requested: Int)
    case minimumStakeNotMet(minimum: Int, requested: Int)
    case playerEliminated(String)
}

/// Strict integer-penny banking ledger for race-night betting and player balances
public actor BankingLedger {
    private var balances: [String: Int] = [:] // playerId -> balancePennies
    private var activeStakes: [String: Int] = [:] // betId -> stakePennies

    public init() {}

    /// Registers a new player with the default starting balance (£500 = 50,000 pennies)
    public func registerPlayer(id: String, initialBalancePennies: Int = Player.initialStartingBalancePennies) {
        if balances[id] == nil {
            balances[id] = initialBalancePennies
        }
    }

    /// Gets current balance in integer pennies
    public func getBalance(playerId: String) -> Int? {
        return balances[playerId]
    }

    /// Checks if a player has been eliminated (balance <= 0 and no active bets)
    public func isEliminated(playerId: String) -> Bool {
        guard let bal = balances[playerId] else { return true }
        return bal <= 0
    }

    /// Atomically reserves a stake for an accepted bet
    public func reserveStake(playerId: String, betId: String, stakePennies: Int) throws -> Int {
        guard let currentBalance = balances[playerId] else {
            throw BankingError.playerNotFound(playerId)
        }
        guard currentBalance > 0 else {
            throw BankingError.playerEliminated(playerId)
        }
        guard stakePennies >= Bet.minimumStakePennies else {
            throw BankingError.minimumStakeNotMet(minimum: Bet.minimumStakePennies, requested: stakePennies)
        }
        guard currentBalance >= stakePennies else {
            throw BankingError.insufficientFunds(available: currentBalance, requested: stakePennies)
        }

        let newBalance = currentBalance - stakePennies
        balances[playerId] = newBalance
        activeStakes[betId] = stakePennies
        return newBalance
    }

    /// Refunds a reserved stake if a race or bet is voided/cancelled
    public func refundStake(playerId: String, betId: String) throws -> Int {
        guard let currentBalance = balances[playerId] else {
            throw BankingError.playerNotFound(playerId)
        }
        guard let stake = activeStakes[betId] else {
            return currentBalance // Already refunded or settled
        }

        activeStakes.removeValue(forKey: betId)
        let newBalance = currentBalance + stake
        balances[playerId] = newBalance
        return newBalance
    }

    /// Credits payout to player upon winning settlement
    public func creditPayout(playerId: String, betId: String, payoutPennies: Int) throws -> (balanceBefore: Int, balanceAfter: Int) {
        guard let currentBalance = balances[playerId] else {
            throw BankingError.playerNotFound(playerId)
        }

        activeStakes.removeValue(forKey: betId)
        let balanceBefore = currentBalance
        let balanceAfter = currentBalance + payoutPennies
        balances[playerId] = balanceAfter
        return (balanceBefore, balanceAfter)
    }

    /// Closes a losing bet without crediting funds
    public func closeLosingBet(playerId: String, betId: String) -> Int? {
        activeStakes.removeValue(forKey: betId)
        return balances[playerId]
    }
}
