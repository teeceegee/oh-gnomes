import Testing
import Foundation
@testable import GnomesCore
@testable import GnomesSimulation
@testable import GnomesAudio

@Suite("Content Authoring Tests (M6)")
struct ContentTests {

    @Test("48-Gnome Persistent Roster Verification (EVD-293)")
    func test48GnomesRoster() throws {
        let gnomes = try ContentLoader.loadGnomes()
        #expect(gnomes.count == 48)

        var ids = Set<String>()
        var names = Set<String>()

        for gnome in gnomes {
            // Unique IDs
            #expect(!ids.contains(gnome.id))
            ids.insert(gnome.id)

            // Unique Names
            #expect(!names.contains(gnome.name))
            names.insert(gnome.name)

            // Identity integrity
            #expect(!gnome.archetype.isEmpty)
            #expect(!gnome.biography.isEmpty)
            #expect(gnome.portraitAsset.hasSuffix(".svg"))

            // Baseline attribute sanity [0.0, 1.0]
            let attr = gnome.baselineAttributes
            #expect(attr.speed > 0.3 && attr.speed <= 1.0)
            #expect(attr.acceleration > 0.3 && attr.acceleration <= 1.0)
            #expect(attr.stamina > 0.3 && attr.stamina <= 1.0)
            #expect(attr.balance > 0.2 && attr.balance <= 1.0)
            #expect(attr.recovery > 0.3 && attr.recovery <= 1.0)

            // Traits
            #expect(!gnome.traits.isEmpty)
            for trait in gnome.traits {
                #expect(!trait.displayName.isEmpty)
                #expect(!trait.description.isEmpty)
            }
        }
    }

    @Test("3 Race Courses Specification & Contiguity (EVD-294)")
    func test3Courses() throws {
        let courses = try CourseLoader.loadCourses()
        #expect(courses.count == 3)

        let expectedIds = ["course_garden_grand_prix", "course_allotment_derby", "course_rockery_rally"]
        for expId in expectedIds {
            #expect(courses.contains(where: { $0.id == expId }))
        }

        for course in courses {
            #expect(course.totalDistanceMeters >= 200.0)
            #expect(!course.surfaceZones.isEmpty)
            #expect(!course.obstacleZones.isEmpty)

            // Contiguity check: surface zones must start at 0, be ordered, contiguous, and end at totalDistance
            var currentMeter = 0.0
            for zone in course.surfaceZones {
                #expect(zone.startMeter == currentMeter)
                #expect(zone.endMeter > zone.startMeter)
                #expect(zone.speedMultiplier > 0.2 && zone.speedMultiplier <= 1.5)
                #expect(zone.slipRiskPerTick >= 0.0 && zone.slipRiskPerTick < 0.1)
                currentMeter = zone.endMeter
            }
            #expect(currentMeter == course.totalDistanceMeters)

            // Obstacle bounds
            for obs in course.obstacleZones {
                #expect(obs.locationMeter >= 0.0 && obs.locationMeter <= course.totalDistanceMeters)
                #expect(obs.triggerRadiusMeters > 0.0)
                #expect(obs.baseTriggerChance > 0.0 && obs.baseTriggerChance <= 1.0)
            }
        }
    }

    @Test("Commentary Corpus & Dynamic Templating (EVD-295)")
    func testCommentaryCorpus() throws {
        let corpus = try ContentLoader.loadCommentaryCorpus()
        #expect(corpus.openings.count >= 4)
        #expect(corpus.overtakes.count >= 4)
        #expect(corpus.stumbles.count >= 4)
        #expect(corpus.springLaunchers.count >= 3)
        #expect(corpus.mudSplashes.count >= 3)
        #expect(corpus.sprinklers.count >= 3)
        #expect(corpus.collisions.count >= 3)
        #expect(corpus.photoFinishes.count >= 3)
        #expect(corpus.winnerCelebrations.count >= 3)

        let generator = ProceduralCommentaryGenerator(corpus: corpus)

        let startLine = generator.commentaryForStart(courseName: "Allotment Derby", entrantsCount: 8, seed: 1)
        #expect(startLine.contains("Allotment Derby") || startLine.contains("glorious") || startLine.contains("garden") || startLine.contains("clapper") || startLine.contains("turf") || startLine.contains("Pointy"))

        let overtakeLine = generator.commentaryForOvertake(leaderName: "Barnaby", chaserName: "Gnorman", seed: 0)
        #expect(overtakeLine.contains("Barnaby"))
        #expect(overtakeLine.contains("Gnorman"))

        let incidentLine = generator.commentaryForIncident(runnerName: "Bumble", incidentType: .mudSplash, reason: "puddle", seed: 0)
        #expect(incidentLine.contains("Bumble"))

        let winnerLine = generator.commentaryForWinner(winnerName: "Lord Pipsqueak", seed: 0)
        #expect(winnerLine.contains("Lord Pipsqueak"))
    }

    @Test("SVG Portrait Assets Generation")
    func testSVGPortraits() throws {
        let gnomes = try ContentLoader.loadGnomes()
        let fm = FileManager.default
        let portraitsDir = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("Content/Portraits")

        for gnome in gnomes {
            let svgFile = portraitsDir.appendingPathComponent("\(gnome.id).svg")
            #expect(fm.fileExists(atPath: svgFile.path))

            let svgContent = try String(contentsOf: svgFile, encoding: .utf8)
            #expect(svgContent.contains("<svg"))
            #expect(svgContent.contains("</svg>"))
        }
    }
}
