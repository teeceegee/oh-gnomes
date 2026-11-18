import Testing
import Foundation
import SceneKit
@testable import GnomesCore
@testable import GnomesContracts
@testable import GnomesSimulation
@testable import GnomesPresentation3D

@Suite("GnomesPresentation3D & Multi-Camera Tests (Phase 3)")
struct GnomesPresentation3DTests {

    @Test("All 48 Gnomes Have Unique Visual Profiles (EVD-311)")
    func testUnique48VisualProfiles() throws {
        let gnomes = try ContentLoader.loadGnomes()
        #expect(gnomes.count == 48)

        var signatures = Set<String>()
        for g in gnomes {
            let p = GnomeVisualProfile.profile(for: g)
            let sig = "\(p.hatStyle.rawValue)|\(p.beardStyle.rawValue)|\(p.accessory.rawValue)|\(p.hatColorHex)|\(p.tunicColorHex)"
            #expect(!signatures.contains(sig))
            signatures.insert(sig)
        }
        #expect(signatures.count == 48)
    }

    @Test("3D Course Spline & Multi-Hazard Geometry (EVD-312)")
    func testCourse3DSplineAndHazards() throws {
        let courses = try CourseLoader.loadCourses()
        #expect(courses.count == 3)

        for course in courses {
            let startPt = course.position3D(atDistanceMeters: 0, lane: 1)
            let midPt = course.position3D(atDistanceMeters: course.totalDistanceMeters / 2.0, lane: 4)
            let endPt = course.position3D(atDistanceMeters: course.totalDistanceMeters, lane: 8)
            #expect(endPt.x > startPt.x)
            #expect(midPt.y >= 0.0)
        }
    }

    @Test("3D Scene Setup, Multi-Camera Director & 3D Gem Attachment (EVD-307..EVD-310)")
    @MainActor
    func testRace3DSceneSetupAndCameras() throws {
        let gnomes = Array((try ContentLoader.loadGnomes()).prefix(8))
        let courses = try CourseLoader.loadCourses()
        let scene3D = RaceBroadcast3DScene(course: courses[0], gnomes: gnomes)

        #expect(scene3D.gnomeNodes.count == 8)

        // Attach 3D Gnome Gem
        let gem = GnomeGem.standardPalette[0]
        scene3D.attachGems([BackedGnomeGem(gnomeId: gnomes[0].id, gem: gem, playerDisplayName: "Alice")])

        // Test all 6 camera angles
        for angle in BroadcastCameraAngle.allCases {
            scene3D.setCameraAngle(angle)
            #expect(scene3D.cameraDirector.selectedMode == angle)
        }

        // Simulate a frame update & 3D incident particle FX
        let states = gnomes.enumerated().map { idx, g in
            RunnerState(gnomeId: g.id, gnomeName: g.name, lane: idx + 1, distanceMeters: 42.0, velocityMps: 6.5)
        }
        scene3D.updateScene(runners: states, dt: 1.0 / 30.0)
        scene3D.triggerIncidentEffect(gnomeId: gnomes[0].id, type: .mudSlideBowling)
        scene3D.triggerFinishConfetti()
    }
}
