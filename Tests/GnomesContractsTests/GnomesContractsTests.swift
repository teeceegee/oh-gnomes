import Testing
import Foundation
@testable import GnomesCore
@testable import GnomesContracts

@Suite("GnomesContracts Wire & Projection Tests")
struct GnomesContractsTests {

    @Test("Mystery Mode Server-Side Projection Filter")
    func testMysteryModeProjectionMasking() {
        let standings = [
            PlayerStanding(playerId: "p1", displayName: "Alice", gem: GnomeGem.standardPalette[0], balancePennies: 60_000, rank: 1),
            PlayerStanding(playerId: "p2", displayName: "Bob", gem: GnomeGem.standardPalette[1], balancePennies: 45_000, rank: 2)
        ]

        // Mid-game Mystery Mode -> MUST be strictly nil over the wire
        let midGameMystery = StandingsProjection(isMysteryMode: true, isFinale: false, standings: standings)
        #expect(midGameMystery.isMysteryMode)
        #expect(!midGameMystery.isFinale)
        #expect(midGameMystery.standings == nil)

        // Finale Mystery Mode -> MUST be revealed
        let finaleMystery = StandingsProjection(isMysteryMode: true, isFinale: true, standings: standings)
        #expect(finaleMystery.standings != nil)
        #expect(finaleMystery.standings?.count == 2)

        // Open Mode -> MUST always be visible
        let openMode = StandingsProjection(isMysteryMode: false, isFinale: false, standings: standings)
        #expect(openMode.standings != nil)
        #expect(openMode.standings?.first?.displayName == "Alice")
    }

    @Test("ServerEnvelope JSON Serialization Roundtrip")
    func testServerEnvelopeJSONSerialization() throws {
        let payload = PhaseChangedPayload(
            raceId: "race_test_100",
            phase: .bettingOpen,
            secondsRemaining: 60
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payloadData = try encoder.encode(payload)
        let payloadString = String(decoding: payloadData, as: UTF8.self)

        let envelope = ServerEnvelope(type: .phaseChanged, payloadJSON: payloadString)
        let envelopeData = try encoder.encode(envelope)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedEnvelope = try decoder.decode(ServerEnvelope.self, from: envelopeData)

        #expect(decodedEnvelope.type == .phaseChanged)

        let decodedPayload = try decoder.decode(PhaseChangedPayload.self, from: Data(decodedEnvelope.payloadJSON.utf8))
        #expect(decodedPayload.raceId == "race_test_100")
        #expect(decodedPayload.phase == .bettingOpen)
        #expect(decodedPayload.secondsRemaining == 60)
    }
}
