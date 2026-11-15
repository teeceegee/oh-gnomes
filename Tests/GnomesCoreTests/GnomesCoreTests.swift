import Testing
import Foundation
@testable import GnomesCore

@Suite("GnomesCore Domain Tests")
struct GnomesCoreTests {

    @Test("Gnome Gems Palette Integrity (20 Unique Gems)")
    func testGnomeGemsIntegrity() {
        let gems = GnomeGem.standardPalette
        #expect(gems.count == 20)

        let uniqueIds = Set(gems.map { $0.id })
        #expect(uniqueIds.count == 20)

        let uniqueNames = Set(gems.map { $0.name })
        #expect(uniqueNames.count == 20)

        // Verify shape redundancy exists
        let uniqueShapes = Set(gems.map { $0.shape })
        #expect(uniqueShapes.count >= 8)
    }

    @Test("Player Balance & Elimination Rules")
    func testPlayerBalanceRules() {
        var player = Player(
            sessionId: "session_1",
            displayName: "BettorBob",
            gemId: "gem_01",
            deviceCredentialHash: "hash123"
        )

        #expect(player.balancePennies == 50_000)
        #expect(player.balanceFormattedPounds == "£500.00")
        #expect(!player.isEliminated)

        player.balancePennies = 100 // £1.00
        #expect(!player.isEliminated)

        player.balancePennies = 0
        #expect(player.isEliminated)
    }

    @Test("Stake + Profit Payout Formula (ADR-001)")
    func testStakePlusProfitPayoutFormula() {
        // Test 1: 3/1 odds with £10 stake (1,000 pennies) -> should return £40 (4,000 pennies)
        let quote3to1 = OddsQuote(
            raceId: "race_1",
            gnomeId: "gnome_1",
            numerator: 3,
            denominator: 1,
            impliedProbability: 0.25
        )
        let return3to1 = quote3to1.calculateReturnPennies(forStakePennies: 1_000)
        #expect(return3to1 == 4_000)

        // Test 2: 7/2 odds with £20 stake (2,000 pennies) -> profit £70 (7,000p) -> total £90 (9,000p)
        let quote7to2 = OddsQuote(
            raceId: "race_1",
            gnomeId: "gnome_2",
            numerator: 7,
            denominator: 2,
            impliedProbability: 0.22
        )
        let return7to2 = quote7to2.calculateReturnPennies(forStakePennies: 2_000)
        #expect(return7to2 == 9_000)

        // Test 3: Odds-on 1/2 with £10 stake (1,000 pennies) -> profit £5 (500p) -> total £15 (1,500p)
        let quote1to2 = OddsQuote(
            raceId: "race_1",
            gnomeId: "gnome_3",
            numerator: 1,
            denominator: 2,
            impliedProbability: 0.67
        )
        let return1to2 = quote1to2.calculateReturnPennies(forStakePennies: 1_000)
        #expect(return1to2 == 1_500)
    }

    @Test("Race Lifecycle Monotonic Progression")
    func testRaceLifecycleTransitions() {
        #expect(RacePhase.preparing.canTransition(to: .introduction))
        #expect(RacePhase.introduction.canTransition(to: .bettingOpen))
        #expect(RacePhase.bettingOpen.canTransition(to: .bettingClosed))
        #expect(RacePhase.bettingClosed.canTransition(to: .simulating))
        #expect(RacePhase.simulating.canTransition(to: .presentationFinished))
        #expect(RacePhase.presentationFinished.canTransition(to: .settling))
        #expect(RacePhase.settling.canTransition(to: .published))
        #expect(RacePhase.published.canTransition(to: .archived))

        // Invalid transitions
        #expect(!RacePhase.bettingOpen.canTransition(to: .published))
        #expect(!RacePhase.simulating.canTransition(to: .bettingOpen))
    }

    @Test("Session Lifecycle & Interruption Recovery")
    func testSessionLifecycleTransitions() {
        #expect(SessionPhase.lobby.canTransition(to: .registrationClosed))
        #expect(SessionPhase.registrationClosed.canTransition(to: .inProgress))
        #expect(SessionPhase.inProgress.canTransition(to: .pausedBetweenRaces))
        #expect(SessionPhase.pausedBetweenRaces.canTransition(to: .inProgress))
        #expect(SessionPhase.inProgress.canTransition(to: .interrupted))
        #expect(SessionPhase.interrupted.canTransition(to: .inProgress))
    }
}
