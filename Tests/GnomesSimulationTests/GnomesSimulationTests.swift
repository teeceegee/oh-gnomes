import Testing
import Foundation
@testable import GnomesCore
@testable import GnomesSimulation

@Suite("Deterministic Simulation Engine Tests")
struct GnomesSimulationTests {

    private func createTestRoster() -> [Gnome] {
        return [
            Gnome(
                id: "gnome_speedy",
                name: "Barnaby Swiftbeard",
                archetype: "Sprinter",
                portraitAsset: "gnome_1.png",
                biography: "Can outrun a lawnmower on a good day.",
                traits: [GnomeTrait(id: "t_boost", displayName: "Start Boost", description: "Blasts off at the gate.", effectCategory: .startBoost)],
                baselineAttributes: GnomeAttributes(speed: 0.85, acceleration: 0.90, stamina: 0.50, balance: 0.60, recovery: 0.70)
            ),
            Gnome(
                id: "gnome_muddy",
                name: "Gimlet Bogtrotter",
                archetype: "Mud Specialist",
                portraitAsset: "gnome_2.png",
                biography: "Happiest when submerged in swampy turf.",
                traits: [GnomeTrait(id: "t_mud", displayName: "Mud Affinity", description: "Ignores mud drag.", effectCategory: .mudAffinity)],
                baselineAttributes: GnomeAttributes(speed: 0.65, acceleration: 0.60, stamina: 0.75, balance: 0.80, recovery: 0.65)
            ),
            Gnome(
                id: "gnome_steady",
                name: "Eldred Oakfoot",
                archetype: "Endurance",
                portraitAsset: "gnome_3.png",
                biography: "Never stumbles, rarely sprints.",
                traits: [GnomeTrait(id: "t_surge", displayName: "Stamina Surge", description: "Sprints at the end.", effectCategory: .staminaSurge)],
                baselineAttributes: GnomeAttributes(speed: 0.70, acceleration: 0.65, stamina: 0.95, balance: 0.90, recovery: 0.80)
            ),
            Gnome(
                id: "gnome_clumsy",
                name: "Pip Tumbleweed",
                archetype: "Wildcard",
                portraitAsset: "gnome_4.png",
                biography: "Prone to tripping over imaginary daisies.",
                traits: [GnomeTrait(id: "t_slip", displayName: "Slip Prone", description: "Loves falling down.", effectCategory: .slipProne)],
                baselineAttributes: GnomeAttributes(speed: 0.80, acceleration: 0.75, stamina: 0.60, balance: 0.30, recovery: 0.90)
            ),
            Gnome(
                id: "gnome_veteran",
                name: "Gideon Redcap",
                archetype: "All-Rounder",
                portraitAsset: "gnome_5.png",
                biography: "Decorated garden derby champion.",
                traits: [],
                baselineAttributes: GnomeAttributes(speed: 0.75, acceleration: 0.70, stamina: 0.75, balance: 0.75, recovery: 0.75)
            ),
            Gnome(
                id: "gnome_jumper",
                name: "Boffin Highstep",
                archetype: "Acrobat",
                portraitAsset: "gnome_6.png",
                biography: "Springs into action unexpectedly.",
                traits: [GnomeTrait(id: "t_jump", displayName: "Obstacle Springer", description: "Springs over hurdles.", effectCategory: .obstacleSpringer)],
                baselineAttributes: GnomeAttributes(speed: 0.72, acceleration: 0.80, stamina: 0.65, balance: 0.70, recovery: 0.85)
            ),
            Gnome(
                id: "gnome_heavy",
                name: "Rumble Stonebeard",
                archetype: "Brawler",
                portraitAsset: "gnome_7.png",
                biography: "Solid as granite, slow to turn.",
                traits: [],
                baselineAttributes: GnomeAttributes(speed: 0.60, acceleration: 0.50, stamina: 0.90, balance: 0.95, recovery: 0.50)
            ),
            Gnome(
                id: "gnome_lucky",
                name: "Felix Cloverleaf",
                archetype: "Chaos",
                portraitAsset: "gnome_8.png",
                biography: "Chaos seems to avoid him by inches.",
                traits: [GnomeTrait(id: "t_chaos", displayName: "Chaos Magnet", description: "Always in the thick of it.", effectCategory: .chaosMagnet)],
                baselineAttributes: GnomeAttributes(speed: 0.74, acceleration: 0.72, stamina: 0.70, balance: 0.65, recovery: 0.75)
            )
        ]
    }

    @Test("PRNG Reproducibility and Uniformity")
    func testPRNGReproducibility() {
        var prng1 = Xoshiro256StarStar(seed: 0xDEADBEEFCAFE1234)
        var prng2 = Xoshiro256StarStar(seed: 0xDEADBEEFCAFE1234)

        for _ in 0..<100 {
            #expect(prng1.nextUInt64() == prng2.nextUInt64())
            #expect(prng1.nextDouble() == prng2.nextDouble())
            #expect(prng1.nextInt(in: 1...100) == prng2.nextInt(in: 1...100))
        }
    }

    @Test("Single Race Execution Completes with 8 Finishers")
    func testSingleRaceExecution() {
        let gnomes = createTestRoster()
        let engine = SimulationEngine(
            raceId: "race_test_single",
            masterSeed: 123456789,
            course: Course.gardenGrandPrix,
            gnomes: gnomes
        )

        let result = engine.runToCompletion()

        #expect(engine.isComplete)
        #expect(result.finishOrder.count == 8)
        #expect(result.finishOrder.allSatisfy { $0.isFinished })

        // Check winner has rank 1
        let winner = result.finishOrder.first
        #expect(winner?.finishRank == 1)
        #expect(result.resultChecksum.count == 16)
        #expect(result.eventLog.count > 10)
    }

    @Test("Bit-Exact Determinism across 1,000 Runs (EVD-273 Gate)")
    func testDeterministicReplayContract() {
        let gnomes = createTestRoster()
        let masterSeed: UInt64 = 0xABCDEF0123456789

        // Baseline run
        let baselineEngine = SimulationEngine(
            raceId: "race_replay_test",
            masterSeed: masterSeed,
            course: Course.gardenGrandPrix,
            gnomes: gnomes
        )
        let baselineResult = baselineEngine.runToCompletion()
        let expectedChecksum = baselineResult.resultChecksum
        let expectedWinner = baselineResult.finishOrder.first?.gnomeId
        let expectedTicks = baselineResult.totalTicks
        let expectedEventCount = baselineResult.eventLog.count

        // Execute 1,000 runs and verify 100% byte-for-byte identical outcomes
        for runIdx in 1...1_000 {
            let engine = SimulationEngine(
                raceId: "race_replay_test",
                masterSeed: masterSeed,
                course: Course.gardenGrandPrix,
                gnomes: gnomes
            )
            let result = engine.runToCompletion()

            #expect(result.resultChecksum == expectedChecksum, "Failed on run \(runIdx)")
            #expect(result.finishOrder.first?.gnomeId == expectedWinner)
            #expect(result.totalTicks == expectedTicks)
            #expect(result.eventLog.count == expectedEventCount)
        }
    }

    @Test("Incident Limiter Prevents Cascading Depth Overflow")
    func testIncidentLimiterCaps() {
        var limiter = IncidentLimiter()

        // Tick 10: up to 3 incidents allowed at depth 1
        let allow1 = limiter.canTriggerIncident(atTick: 10, cascadeDepth: 1)
        #expect(allow1)
        let allow2 = limiter.canTriggerIncident(atTick: 10, cascadeDepth: 1)
        #expect(allow2)
        let allow3 = limiter.canTriggerIncident(atTick: 10, cascadeDepth: 1)
        #expect(allow3)

        // 4th incident on tick 10 MUST be rejected by budget
        let allow4 = limiter.canTriggerIncident(atTick: 10, cascadeDepth: 1)
        #expect(!allow4)

        // Cascade depth > 2 MUST be rejected
        let allowDepth3 = limiter.canTriggerIncident(atTick: 11, cascadeDepth: 3)
        #expect(!allowDepth3)

        // Tick 11: budget resets
        let allowTick11 = limiter.canTriggerIncident(atTick: 11, cascadeDepth: 1)
        #expect(allowTick11)
    }
}
