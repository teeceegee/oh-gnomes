import Testing
import Foundation
@testable import GnomesCore
@testable import GnomesContracts
@testable import GnomesEconomy
@testable import GnomesSimulation
@testable import GnomesServer

@Suite("GnomesServer & Session Lifecycle Tests")
struct GnomesServerTests {

    private func createTestRoster() -> [Gnome] {
        return (1...8).map { idx in
            Gnome(
                id: "gnome_\(idx)",
                name: "Gnome \(idx)",
                archetype: "Archetype",
                portraitAsset: "portrait.png",
                biography: "Biography",
                traits: [],
                baselineAttributes: GnomeAttributes(speed: 0.7, acceleration: 0.7, stamina: 0.7, balance: 0.7, recovery: 0.7)
            )
        }
    }

    @Test("Player Join & 20-Gnome Gem Allocation (D-01, D-05)")
    func testPlayerJoinAndGemAllocation() async throws {
        let gnomes = createTestRoster()
        let manager = SessionManager(joinCode: "GNOM", mode: .mystery, allGnomes: gnomes)

        var allocatedGemIds = Set<String>()

        // Join 20 players
        for i in 1...20 {
            let req = JoinRequest(joinCode: "GNOM", displayName: "Player_\(i)", clientNonce: "nonce_\(i)")
            let res = try await manager.join(request: req, credentialHash: "hash_\(i)")

            #expect(res.displayName == "Player_\(i)")
            #expect(res.balancePennies == 50_000) // £500.00
            #expect(!allocatedGemIds.contains(res.gem.id))
            allocatedGemIds.insert(res.gem.id)
        }

        #expect(allocatedGemIds.count == 20)

        // 21st player must be rejected (Session Full)
        let req21 = JoinRequest(joinCode: "GNOM", displayName: "Player_21", clientNonce: "nonce_21")
        await #expect(throws: SessionError.sessionFull(max: 20)) {
            try await manager.join(request: req21, credentialHash: "hash_21")
        }
    }

    @Test("Reconnection Preserves Balance & Gem Without Duplicate Grant (D-10)")
    func testReconnectionPreservesBalance() async throws {
        let gnomes = createTestRoster()
        let manager = SessionManager(joinCode: "GNOM", mode: .mystery, allGnomes: gnomes)

        let initialJoin = try await manager.join(
            request: JoinRequest(joinCode: "GNOM", displayName: "Charlie", clientNonce: "nonce_c"),
            credentialHash: "device_mac_charlie"
        )
        let initialGemId = initialJoin.gem.id

        // Reconnect via join with identical credential hash
        let reconnectJoin = try await manager.join(
            request: JoinRequest(joinCode: "GNOM", displayName: "Charlie", clientNonce: "nonce_c2"),
            credentialHash: "device_mac_charlie"
        )

        #expect(reconnectJoin.playerId == initialJoin.playerId)
        #expect(reconnectJoin.gem.id == initialGemId)
        #expect(reconnectJoin.balancePennies == 50_000)

        // Total registered players must still be exactly 1
        let count = await manager.players.count
        #expect(count == 1)
    }

    @Test("Full Betting Flow, Atomic Lock & Reveal (D-02, D-05, D-06)")
    func testBettingFlowAndGemReveal() async throws {
        let gnomes = createTestRoster()
        let manager = SessionManager(joinCode: "GNOM", mode: .mystery, allGnomes: gnomes)

        let player = try await manager.join(
            request: JoinRequest(joinCode: "GNOM", displayName: "Dan", clientNonce: "n_d"),
            credentialHash: "hash_dan"
        )

        // 1. Prepare race, start introduction & open betting
        let race = await manager.prepareNextRace()
        #expect(race.entrantIds.count == 8)
        try await manager.startIntroduction()
        try await manager.openBetting()

        let quotes = await manager.currentQuotes
        #expect(quotes.count == 8)
        let quote = quotes[0]

        // 2. Place bet: £50 (5,000 pennies)
        let betReq = PlaceBetRequest(
            raceId: race.id,
            gnomeId: quote.gnomeId,
            stakePennies: 5_000,
            oddsQuoteId: quote.id
        )
        let ticket = try await manager.placeBet(request: betReq, playerId: player.playerId)
        #expect(ticket.stakePennies == 5_000)
        #expect(ticket.gnomeId == quote.gnomeId)

        // 3. Second bet MUST be rejected
        await #expect(throws: SessionError.alreadyBet(player.playerId)) {
            try await manager.placeBet(request: betReq, playerId: player.playerId)
        }

        // 4. Close betting atomically -> reveal backed gems
        let backedGems = try await manager.closeBetting()
        #expect(backedGems.count == 1)
        #expect(backedGems[0].gnomeId == quote.gnomeId)
        #expect(backedGems[0].playerDisplayName == "Dan")
        #expect(backedGems[0].gem.id == player.gem.id)
    }

    @Test("Mystery Mode Server-Side Masking Filter")
    func testMysteryModeServerProjection() async throws {
        let gnomes = createTestRoster()
        let manager = SessionManager(joinCode: "GNOM", mode: .mystery, allGnomes: gnomes)

        _ = try await manager.join(
            request: JoinRequest(joinCode: "GNOM", displayName: "Eve", clientNonce: "n_eve"),
            credentialHash: "h_eve"
        )

        // Mid-game: Standings MUST be nil over the wire
        let midGameStandings = await manager.getStandingsProjection(forRole: .phonePlayer)
        #expect(midGameStandings.isMysteryMode)
        #expect(!midGameStandings.isFinale)
        #expect(midGameStandings.standings == nil)
    }

    @Test("Live HTTP Server Spin-Up & Endpoint Verification")
    func testLiveHTTPServerEndpoints() async throws {
        let gnomes = createTestRoster()
        let manager = SessionManager(joinCode: "TEST", mode: .mystery, allGnomes: gnomes)
        let testPort: UInt16 = 8795

        let server = GnomesHTTPServer(port: testPort, sessionManager: manager)
        try await server.start()

        // Wait brief moment for socket to bind
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Query /health
        let url = URL(string: "http://127.0.0.1:\(testPort)/health")!
        let (data, response) = try await URLSession.shared.data(from: url)

        let httpRes = response as? HTTPURLResponse
        #expect(httpRes?.statusCode == 200)

        let jsonStr = String(decoding: data, as: UTF8.self)
        #expect(jsonStr.contains("\"status\":\"ok\""))
        #expect(jsonStr.contains("\"port\":8795"))

        await server.stop()
    }
}
