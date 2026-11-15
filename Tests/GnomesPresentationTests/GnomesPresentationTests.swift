import Testing
import Foundation
import SpriteKit
@testable import GnomesCore
@testable import GnomesContracts
@testable import GnomesSimulation
@testable import GnomesPresentation

@Suite("GnomesPresentation & Metal Scene Tests")
struct GnomesPresentationTests {

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

    @Test("RaceBroadcastScene 1080p Geometry & 8-Runner Setup")
    @MainActor
    func testRaceSceneSetup() {
        let gnomes = createTestRoster()
        let scene = RaceBroadcastScene(course: Course.gardenGrandPrix, gnomes: gnomes)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        view.presentScene(scene)

        #expect(scene.size.width == 1920)
        #expect(scene.size.height == 1080)
        #expect(scene.runnerNodes.count == 8)

        for (idx, node) in scene.runnerNodes.enumerated() {
            #expect(node.lane == idx + 1)
            #expect(node.gnomeId == "gnome_\(idx + 1)")
        }
    }

    @Test("Floating Gnome Gem Attachment to RunnerNode")
    @MainActor
    func testGnomeGemAttachment() {
        let gnomes = createTestRoster()
        let scene = RaceBroadcastScene(course: Course.gardenGrandPrix, gnomes: gnomes)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        view.presentScene(scene)

        let backedGems = [
            BackedGnomeGem(gnomeId: "gnome_1", gem: GnomeGem.standardPalette[0], playerDisplayName: "Alice")
        ]
        scene.attachGems(backedGems)

        let runner1 = scene.runnerNodes[0]
        #expect(runner1.gemNode != nil)
        #expect(runner1.gemNode?.playerDisplayName == "Alice")
        #expect(runner1.gemNode?.gem.name == "Ruby Star")

        let runner2 = scene.runnerNodes[1]
        #expect(runner2.gemNode == nil)
    }

    @Test("Scene Update & Camera Director Tracking")
    @MainActor
    func testSceneUpdateAndCamera() {
        let gnomes = createTestRoster()
        let scene = RaceBroadcastScene(course: Course.gardenGrandPrix, gnomes: gnomes)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        view.presentScene(scene)

        let runnerStates = gnomes.enumerated().map { idx, g in
            RunnerState(gnomeId: g.id, gnomeName: g.name, lane: idx + 1, distanceMeters: 50.0, velocityMps: 7.0)
        }

        scene.updateScene(runners: runnerStates, dt: 1.0 / 30.0)

        // First runner node position should be updated to world coordinates
        let expectedX = 100.0 + CGFloat(50.0 * 25.0)
        #expect(scene.runnerNodes[0].position.x == expectedX)

        // Photo finish trigger
        scene.triggerPhotoFinish()
        #expect(scene.isPhotoFinishFrozen)
    }

    @Test("Metal Particle Shader Emitter Creation")
    @MainActor
    func testParticleEmitters() {
        let mudEmitter = MetalParticleShaders.makeMudSplashEmitter()
        #expect(mudEmitter.numParticlesToEmit == 15)

        let springEmitter = MetalParticleShaders.makeSpringDustEmitter()
        #expect(springEmitter.numParticlesToEmit == 25)
    }
}
