import Foundation
import SwiftUI
import SpriteKit
import GnomesCore
import GnomesContracts
import GnomesSimulation
import GnomesEconomy
import GnomesPersistence
import GnomesServer
import GnomesPresentation
import GnomesAudio

@MainActor
public final class HostViewModel: ObservableObject {
    @Published public var joinCode: String = "GNOM"
    @Published public var serverPort: UInt16 = 8778
    @Published public var lanAddress: String = "192.168.1.2"
    @Published public var connectedPlayersCount: Int = 0
    @Published public var currentPhaseName: String = "Preparing"
    @Published public var subtitleText: String = "Welcome to Oh! Gnomes — Connect on your mobile to join!"
    @Published public var currentRaceIndex: Int = 1
    @Published public var isRunningRace: Bool = false

    public let sessionManager: SessionManager
    public let httpServer: GnomesHTTPServer
    public let commentaryEngine: CommentaryEngine
    public let commentaryGenerator: ProceduralCommentaryGenerator
    public let audioFX: AudioFXSynthesizer

    public var broadcastScene: RaceBroadcastScene
    public let courses: [Course]
    public let allGnomes: [Gnome]

    public init() {
        // 1. Load content
        let gnomes = (try? ContentLoader.loadGnomes()) ?? (1...48).map { idx in
            Gnome(
                id: "gnome_\(idx)",
                name: "Gnome \(idx)",
                archetype: "Strider",
                portraitAsset: "portraits/gnome_\(idx).svg",
                biography: "Garden veteran",
                traits: [],
                baselineAttributes: GnomeAttributes(speed: 0.7, acceleration: 0.7, stamina: 0.7, balance: 0.7, recovery: 0.7)
            )
        }
        self.allGnomes = gnomes

        let courses = (try? CourseLoader.loadCourses()) ?? [Course.gardenGrandPrix]
        self.courses = courses

        let activeCourse = courses[0]
        let raceEntrants = Array(gnomes.prefix(8))

        // 2. Setup presentation & audio engines
        self.broadcastScene = RaceBroadcastScene(course: activeCourse, gnomes: raceEntrants)
        self.commentaryEngine = CommentaryEngine()
        self.commentaryGenerator = ProceduralCommentaryGenerator()
        self.audioFX = AudioFXSynthesizer()

        // 3. Setup server on verified port 8778 (overrideable via OH_GNOMES_PORT)
        let portOverride = ProcessInfo.processInfo.environment["OH_GNOMES_PORT"].flatMap { UInt16($0) } ?? 8778
        self.serverPort = portOverride
        let manager = SessionManager(joinCode: "GNOM", mode: .mystery, allGnomes: gnomes, courses: courses)
        self.sessionManager = manager
        self.httpServer = GnomesHTTPServer(port: portOverride, sessionManager: manager)

        // 4. Hook subtitle synchronization
        self.commentaryEngine.onSubtitleEmitted = { [weak self] subtitle in
            Task { @MainActor in
                self?.subtitleText = subtitle
                self?.broadcastScene.setSubtitleText(subtitle)
            }
        }
    }

    public func start() {
        Task {
            do {
                try await httpServer.start()
                let race = await sessionManager.prepareNextRace()
                self.currentPhaseName = race.phase.rawValue.capitalized
                self.commentaryEngine.speak("Welcome to Oh! Gnomes! Point your phones at the screen to join race number one!")
            } catch {
                print("Failed to start HTTP server: \(error)")
            }
        }
    }

    public func advancePhase() {
        Task {
            guard let race = await sessionManager.currentRace else { return }

            switch race.phase {
            case .preparing:
                try? await sessionManager.startIntroduction()
                self.currentPhaseName = "Introduction"
                self.audioFX.playEffect(.trumpetFanfare)
                let introSpeech = commentaryGenerator.commentaryForStart(courseName: courses[0].name, entrantsCount: 8)
                self.commentaryEngine.speak(introSpeech)

            case .introduction:
                try? await sessionManager.openBetting()
                self.currentPhaseName = "Betting Open"
                self.commentaryEngine.speak("Betting is now open! Place your stakes on your phone!")

            case .bettingOpen:
                let backedGems = (try? await sessionManager.closeBetting()) ?? []
                self.currentPhaseName = "Betting Closed"
                self.broadcastScene.attachGems(backedGems)
                self.commentaryEngine.speak("Betting is closed! Gems are revealed, runners take your marks!")

            case .bettingClosed:
                await runRace()

            case .published, .archived:
                _ = await sessionManager.prepareNextRace()
                self.currentRaceIndex += 1
                self.currentPhaseName = "Preparing"
                self.commentaryEngine.speak("Prepare for the next race!")

            default:
                break
            }
        }
    }

    public func runRace() async {
        guard !isRunningRace else { return }
        guard let race = await sessionManager.currentRace else { return }
        isRunningRace = true
        self.currentPhaseName = "Racing"

        self.audioFX.playEffect(.startingGun)
        self.commentaryEngine.speak("And they're off!")

        let course = courses[0]
        let seed = UInt64.random(in: 1...1_000_000)
        let entrants = await sessionManager.currentEntrants

        let engine = SimulationEngine(
            raceId: race.id,
            masterSeed: seed,
            course: course,
            gnomes: entrants
        )

        let dt: CGFloat = 1.0 / 30.0

        // Live 30Hz frame stepping
        while !engine.isComplete {
            engine.step()
            let updatedRunners = engine.runners
            broadcastScene.updateScene(runners: updatedRunners, dt: dt)

            // Dynamic camera director tracking leader
            if let leader = updatedRunners.max(by: { $0.distanceMeters < $1.distanceMeters }) {
                if leader.distanceMeters >= course.totalDistanceMeters - 20.0 {
                    broadcastScene.cameraDirector.setMode(.finishLine, trackBounds: CGRect(x: 0, y: 0, width: course.totalDistanceMeters * 25.0, height: 1080))
                }
            }

            try? await Task.sleep(nanoseconds: 33_333_333) // ~30 FPS physics delay
        }

        // Finish line & settlement
        _ = try? await sessionManager.runSimulationAndSettle(course: course, seed: seed)

        if let winner = engine.runners.filter({ $0.isFinished }).min(by: { ($0.finishRank ?? 99) < ($1.finishRank ?? 99) }) {
            let winLine = commentaryGenerator.commentaryForWinner(winnerName: winner.gnomeName, seed: Int(seed))
            commentaryEngine.speak(winLine)
        }

        self.currentPhaseName = "Race Finished (Settled)"
        isRunningRace = false
    }
}
