import Testing
import Foundation
@testable import GnomesCore
@testable import GnomesEconomy

@Suite("GnomesEconomy Tests")
struct GnomesEconomyTests {

    @Test("Banking Ledger Stake Reservation & Balance Safety")
    func testBankingLedgerSafety() async throws {
        let ledger = BankingLedger()
        let playerId = "player_alice"
        await ledger.registerPlayer(id: playerId)

        // Starting balance: £500 (50,000p)
        let balance = await ledger.getBalance(playerId: playerId)
        #expect(balance == 50_000)

        // Reserve £10 stake (1,000p)
        let remaining = try await ledger.reserveStake(playerId: playerId, betId: "bet_1", stakePennies: 1_000)
        #expect(remaining == 49_000)

        // Reject stake below £1 minimum (e.g. 50p)
        await #expect(throws: BankingError.minimumStakeNotMet(minimum: 100, requested: 50)) {
            try await ledger.reserveStake(playerId: playerId, betId: "bet_2", stakePennies: 50)
        }

        // Reject stake exceeding available balance (e.g. £1,000 / 100,000p)
        await #expect(throws: BankingError.insufficientFunds(available: 49_000, requested: 100_000)) {
            try await ledger.reserveStake(playerId: playerId, betId: "bet_3", stakePennies: 100_000)
        }
    }

    @Test("Bookmaker Service Generates Bounded Quotes for 8 Entrants")
    func testBookmakerOddsGeneration() {
        let bookmaker = BookmakerService()
        let entrants = (1...8).map { idx in
            Gnome(
                id: "gnome_\(idx)",
                name: "Runner \(idx)",
                archetype: "Archetype",
                portraitAsset: "portrait.png",
                biography: "Bio",
                traits: idx == 1 ? [GnomeTrait(id: "t_mud", displayName: "Mud Affinity", description: "", effectCategory: .mudAffinity)] : [],
                baselineAttributes: GnomeAttributes(
                    speed: 0.5 + Double(idx) * 0.05,
                    acceleration: 0.6,
                    stamina: 0.7,
                    balance: 0.7,
                    recovery: 0.7
                )
            )
        }

        let quotes = bookmaker.generateQuotes(raceId: "race_odds_test", entrants: entrants, mudRatio: 0.35)
        #expect(quotes.count == 8)

        for q in quotes {
            #expect(q.numerator > 0)
            #expect(q.denominator > 0)
            #expect(q.impliedProbability > 0.0 && q.impliedProbability < 1.0)
            #expect(!q.displayString.isEmpty)
        }
    }

    @Test("Settlement Service Enforces Stake + Profit & Idempotency")
    func testSettlementServiceExecution() async throws {
        let ledger = BankingLedger()
        let playerId = "player_bob"
        await ledger.registerPlayer(id: playerId) // 50,000p (£500)

        // Bob bets £20 (2,000p) on gnome_winner at 3/1
        _ = try await ledger.reserveStake(playerId: playerId, betId: "bet_win_1", stakePennies: 2_000)

        let quoteWinner = OddsQuote(
            raceId: "race_settle_1",
            gnomeId: "gnome_winner",
            numerator: 3,
            denominator: 1,
            impliedProbability: 0.25
        )

        let bet = Bet(
            id: "bet_win_1",
            raceId: "race_settle_1",
            playerId: playerId,
            gnomeId: "gnome_winner",
            stakePennies: 2_000,
            oddsQuoteId: quoteWinner.id,
            quoteNumerator: 3,
            quoteDenominator: 1
        )

        let settlementService = SettlementService()

        // 1st Settlement Call
        let settlements = try await settlementService.settleBets(
            raceId: "race_settle_1",
            bets: [bet],
            quotes: [quoteWinner],
            winningGnomeIds: ["gnome_winner"],
            ledger: ledger
        )

        #expect(settlements.count == 1)
        let s = settlements[0]
        #expect(s.result == .win)
        // 3/1 on £20: profit £60 + stake £20 = £80 (8,000p)
        #expect(s.payoutPennies == 8_000)
        #expect(s.balanceBeforePennies == 48_000)
        #expect(s.balanceAfterPennies == 56_000)

        // Verify balance in ledger
        let updatedBalance = await ledger.getBalance(playerId: playerId)
        #expect(updatedBalance == 56_000)

        // 2nd Settlement Call (IDEMPOTENCY TEST: must NOT double-credit!)
        let retrySettlements = try await settlementService.settleBets(
            raceId: "race_settle_1",
            bets: [bet],
            quotes: [quoteWinner],
            winningGnomeIds: ["gnome_winner"],
            ledger: ledger
        )

        #expect(retrySettlements.count == 1)
        #expect(retrySettlements[0].payoutPennies == 8_000)

        // Balance in ledger MUST still be exactly 56,000 pennies
        let idempotentBalance = await ledger.getBalance(playerId: playerId)
        #expect(idempotentBalance == 56_000)
    }

    @Test("Form Evolution Bounded Decay & Clamping")
    func testFormEvolution() {
        let formService = FormEvolutionService()
        let initialCareer = CareerRecord(racesRun: 5, wins: 1, podiums: 2, incidentsEncountered: 1, formRating: 0.50)

        // Win race: +0.25, 0 incidents
        let afterWin = formService.evolveForm(currentCareer: initialCareer, finishRank: 1, incidentsCount: 0)
        #expect(afterWin.racesRun == 6)
        #expect(afterWin.wins == 2)
        #expect(afterWin.podiums == 3)
        // Form: (0.50 * 0.85) + 0.25 = 0.425 + 0.25 = 0.675
        #expect(abs(afterWin.formRating - 0.675) < 0.001)

        // Clamp test: ensure form never exceeds +1.0
        var maxCareer = CareerRecord(formRating: 0.95)
        for _ in 0..<10 {
            maxCareer = formService.evolveForm(currentCareer: maxCareer, finishRank: 1, incidentsCount: 0)
        }
        #expect(maxCareer.formRating <= 1.0)

        // Clamp test: ensure form never drops below -1.0
        var minCareer = CareerRecord(formRating: -0.90)
        for _ in 0..<10 {
            minCareer = formService.evolveForm(currentCareer: minCareer, finishRank: 8, incidentsCount: 3)
        }
        #expect(minCareer.formRating >= -1.0)
    }
}
