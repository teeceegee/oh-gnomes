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
    @Published public var broadcastScene: RaceBroadcastScene

    public let sessionManager: SessionManager
    public let httpServer: GnomesHTTPServer
    public let commentaryEngine: CommentaryEngine
    public let commentaryGenerator: ProceduralCommentaryGenerator
    public let audioFX: AudioFXSynthesizer

    public let courses: [Course]
    public let allGnomes: [Gnome]
    private var playerPollTask: Task<Void, Never>?

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

    private var hasStarted = false

    public func start() {
        guard !hasStarted else { return }
        hasStarted = true

        Task {
            do {
                try await httpServer.start()
                let race = await sessionManager.prepareNextRace()
                await syncSceneToCurrentRace(race: race)
                self.currentPhaseName = race.phase.rawValue.capitalized
                self.commentaryEngine.speak("Welcome to Oh! Gnomes! Point your phones at the screen to join race number one!")

                // Poll connected players count
                playerPollTask = Task { [weak self] in
                    while !Task.isCancelled {
                        guard let self = self else { break }
                        let count = await self.sessionManager.players.count
                        await MainActor.run {
                            self.connectedPlayersCount = count
                        }
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }
            } catch {
                print("Failed to start HTTP server: \(error)")
            }
        }
    }

    private func syncSceneToCurrentRace(race: Race) async {
        let entrants = await sessionManager.currentEntrants
        let course = courses.first(where: { $0.id == race.courseId }) ?? courses[0]
        self.broadcastScene = RaceBroadcastScene(course: course, gnomes: entrants)
    }

    private func notifyClientsPhaseChanged() async {
        let envelope = ServerEnvelope(type: .phaseChanged, payloadJSON: "{\"refresh\":true}")
        await httpServer.wsGateway.broadcast(envelope: envelope)
    }

    public func advancePhase() {
        Task {
            guard let race = await sessionManager.currentRace else { return }
            let course = courses.first(where: { $0.id == race.courseId }) ?? courses[0]

            switch race.phase {
            case .preparing:
                try? await sessionManager.startIntroduction()
                self.currentPhaseName = "Introduction"
                self.audioFX.playEffect(.trumpetFanfare)
                self.commentaryEngine.speak("Welcome to the \(course.name)! Eight gnomes are stepping up to the starting line. Inspect their form on your phones!")
                await notifyClientsPhaseChanged()

            case .introduction:
                try? await sessionManager.openBetting()
                self.currentPhaseName = "Betting Open"
                self.commentaryEngine.speak("Betting is now open for race \(currentRaceIndex)! Place your stakes on your phone!")
                await notifyClientsPhaseChanged()

            case .bettingOpen:
                let backedGems = (try? await sessionManager.closeBetting()) ?? []
                self.currentPhaseName = "Betting Closed"
                self.broadcastScene.attachGems(backedGems)
                self.commentaryEngine.speak("Betting is closed! All bets are locked and the Gnome Gems are revealed on the track!")
                await notifyClientsPhaseChanged()

            case .bettingClosed:
                await runRace()

            case .published, .archived:
                let nextRace = await sessionManager.prepareNextRace()
                await syncSceneToCurrentRace(race: nextRace)
                self.currentRaceIndex += 1
                self.currentPhaseName = "Preparing"
                self.commentaryEngine.speak("Preparing race number \(currentRaceIndex)!")
                await notifyClientsPhaseChanged()

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

        let course = courses.first(where: { $0.id == race.courseId }) ?? courses[0]
        let seed = UInt64.random(in: 1...1_000_000)
        let entrants = await sessionManager.currentEntrants
        let trackBounds = CGRect(x: 0, y: 0, width: course.totalDistanceMeters * 25.0, height: 1080)

        self.audioFX.playEffect(.startingGun)
        let startSpeech = commentaryGenerator.commentaryForStart(courseName: course.name, entrantsCount: entrants.count, seed: Int(seed))
        self.commentaryEngine.speak(startSpeech)

        broadcastScene.cameraDirector.setMode(.packLead, trackBounds: trackBounds)

        let engine = SimulationEngine(
            raceId: race.id,
            masterSeed: seed,
            course: course,
            gnomes: entrants
        )

        let dt: CGFloat = 1.0 / 30.0
        var lastLeaderId: String? = nil
        var lastCommentaryTick = -90
        var lastIncidentCount = 0
        var announcedRanks: Set<Int> = []

        // Live 30Hz frame stepping
        while !engine.isComplete {
            engine.step()
            let updatedRunners = engine.runners
            broadcastScene.updateScene(runners: updatedRunners, dt: dt)

            // Immediate finish-line announcements for 1st, 2nd, and 3rd place
            let finishers = updatedRunners
                .filter { $0.isFinished }
                .sorted { ($0.finishRank ?? 99) < ($1.finishRank ?? 99) }

            for finisher in finishers {
                guard let rank = finisher.finishRank, rank <= 3, !announcedRanks.contains(rank) else { continue }
                announcedRanks.insert(rank)
                if rank == 1 {
                    audioFX.playEffect(.trumpetFanfare)
                    let winLine = commentaryGenerator.commentaryForWinner(winnerName: finisher.gnomeName, seed: Int(seed))
                    commentaryEngine.speak(winLine, interrupt: true)
                } else if rank == 2 {
                    commentaryEngine.speak("Second place goes to \(finisher.gnomeName)!", interrupt: false)
                } else if rank == 3 {
                    commentaryEngine.speak("And \(finisher.gnomeName) claims third place on the podium!", interrupt: false)
                }
            }

            // Live incident commentary (throttled, only before winner finishes)
            if !announcedRanks.contains(1), engine.incidents.count > lastIncidentCount {
                let newIncident = engine.incidents[lastIncidentCount]
                lastIncidentCount = engine.incidents.count
                if !commentaryEngine.isSpeaking && (engine.currentTick - lastCommentaryTick) >= 75 {
                    lastCommentaryTick = engine.currentTick
                    let line = commentaryGenerator.commentaryForIncident(
                        runnerName: newIncident.runnerName,
                        incidentType: newIncident.incidentType,
                        reason: newIncident.description,
                        seed: engine.currentTick
                    )
                    commentaryEngine.speak(line, interrupt: false)
                }
            }

            // Dynamic camera director & overtake commentary
            if let leader = updatedRunners.max(by: { $0.distanceMeters < $1.distanceMeters }) {
                if !announcedRanks.contains(1),
                   let prevId = lastLeaderId, prevId != leader.gnomeId,
                   !commentaryEngine.isSpeaking, (engine.currentTick - lastCommentaryTick) >= 90 {
                    lastCommentaryTick = engine.currentTick
                    let prevName = entrants.first(where: { $0.id == prevId })?.name ?? "the leader"
                    let overtakeLine = commentaryGenerator.commentaryForOvertake(leaderName: leader.gnomeName, chaserName: prevName, seed: engine.currentTick)
                    commentaryEngine.speak(overtakeLine, interrupt: false)
                }
                lastLeaderId = leader.gnomeId

                if leader.distanceMeters >= course.totalDistanceMeters - 25.0 {
                    broadcastScene.cameraDirector.setMode(.finishLine, trackBounds: trackBounds)
                }
            }

            try? await Task.sleep(nanoseconds: 33_333_333) // ~30 FPS physics delay
        }

        // Finish line & settlement
        _ = try? await sessionManager.runSimulationAndSettle(course: course, seed: seed)

        let podium = engine.runners
            .filter { $0.isFinished }
            .sorted { ($0.finishRank ?? 99) < ($1.finishRank ?? 99) }
            .prefix(3)
        if podium.count == 3 {
            self.subtitleText = "🏆 1st: \(podium[0].gnomeName)  •  🥈 2nd: \(podium[1].gnomeName)  •  🥉 3rd: \(podium[2].gnomeName)"
        }

        self.currentPhaseName = "Race Finished (Settled)"
        isRunningRace = false
        await notifyClientsPhaseChanged()
    }
}
