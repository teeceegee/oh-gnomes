import Foundation
import SwiftUI
import GnomesCore
import GnomesContracts
import GnomesSimulation
import GnomesEconomy
import GnomesPersistence
import GnomesServer
import GnomesPresentation3D
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
    @Published public var broadcastScene: RaceBroadcast3DScene
    @Published public var selectedCameraAngle: BroadcastCameraAngle = .auto
    @Published public var bettingSecondsRemaining: Int? = nil
    @Published public var isMysteryMode: Bool = true
    @Published public var lastRacePodium: [RunnerState] = []
    @Published public var finaleStandings: [PlayerStanding]? = nil

    public let sessionManager: SessionManager
    public let httpServer: GnomesHTTPServer
    public let commentaryEngine: CommentaryEngine
    public let commentaryGenerator: ProceduralCommentaryGenerator
    public let audioFX: AudioFXSynthesizer
    public let gnomeRepository: GnomeRepository?

    public let courses: [Course]
    public let allGnomes: [Gnome]
    private var playerPollTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?

    public init() {
        // 1. Load content & SQLite career persistence (internal SSD Application Support)
        var loadedGnomes = (try? ContentLoader.loadGnomes()) ?? (1...48).map { idx in
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

        var repo: GnomeRepository? = nil
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dbDir = appSupport.appendingPathComponent("OhGnomes")
            try? FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
            let dbPath = dbDir.appendingPathComponent("gnomes.sqlite").path
            if let db = try? SQLiteDatabase(path: dbPath) {
                let gnomeRepo = GnomeRepository(database: db)
                if let persisted = try? gnomeRepo.loadAllGnomes(), !persisted.isEmpty {
                    let careerMap = Dictionary(uniqueKeysWithValues: persisted.map { ($0.id, $0.career) })
                    for i in loadedGnomes.indices {
                        if let savedCareer = careerMap[loadedGnomes[i].id] {
                            loadedGnomes[i].career = savedCareer
                        }
                    }
                } else {
                    for g in loadedGnomes {
                        try? gnomeRepo.upsertGnome(g)
                    }
                }
                repo = gnomeRepo
            }
        }
        self.gnomeRepository = repo
        self.allGnomes = loadedGnomes

        let courses = (try? CourseLoader.loadCourses()) ?? [Course.gardenGrandPrix]
        self.courses = courses

        let activeCourse = courses[0]
        let raceEntrants = Array(loadedGnomes.prefix(8))

        // 2. Setup presentation & audio engines
        self.broadcastScene = RaceBroadcast3DScene(course: activeCourse, gnomes: raceEntrants)
        self.commentaryEngine = CommentaryEngine()
        self.commentaryGenerator = ProceduralCommentaryGenerator()
        self.audioFX = AudioFXSynthesizer()

        // 3. Setup server on verified port 8778 (overrideable via OH_GNOMES_PORT)
        let portOverride = ProcessInfo.processInfo.environment["OH_GNOMES_PORT"].flatMap { UInt16($0) } ?? 8778
        self.serverPort = portOverride
        let manager = SessionManager(
            joinCode: "GNOM",
            mode: .mystery,
            allGnomes: loadedGnomes,
            courses: courses,
            gnomeRepository: repo
        )
        self.sessionManager = manager
        self.httpServer = GnomesHTTPServer(port: portOverride, sessionManager: manager)

        // 4. Hook subtitle synchronization
        self.commentaryEngine.onSubtitleEmitted = { [weak self] subtitle in
            Task { @MainActor in
                self?.subtitleText = subtitle
            }
        }
    }

    public func setCameraAngle(_ angle: BroadcastCameraAngle) {
        self.selectedCameraAngle = angle
        self.broadcastScene.setCameraAngle(angle)
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
        self.broadcastScene = RaceBroadcast3DScene(course: course, gnomes: entrants)
        self.broadcastScene.setCameraAngle(selectedCameraAngle)
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
                self.startBettingCountdown(seconds: 45)
                self.commentaryEngine.speak("Betting is now open for race \(currentRaceIndex)! You have 45 seconds to place your stakes!")
                await notifyClientsPhaseChanged()

            case .bettingOpen:
                await closeBettingAndLock()

            case .bettingClosed:
                await runRace()

            case .published, .archived:
                self.lastRacePodium = []
                self.finaleStandings = nil
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

    private func startBettingCountdown(seconds: Int) {
        countdownTask?.cancel()
        self.bettingSecondsRemaining = seconds
        countdownTask = Task { [weak self] in
            var remaining = seconds
            while remaining > 0 && !Task.isCancelled {
                await self?.sessionManager.setBettingSecondsRemaining(remaining)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                remaining -= 1
                await MainActor.run {
                    self?.bettingSecondsRemaining = remaining
                }
            }
            if !Task.isCancelled {
                await self?.closeBettingAndLock()
            }
        }
    }

    private func closeBettingAndLock() async {
        countdownTask?.cancel()
        countdownTask = nil
        self.bettingSecondsRemaining = nil
        await sessionManager.setBettingSecondsRemaining(nil)
        guard let race = await sessionManager.currentRace, race.phase == .bettingOpen else { return }
        let backedGems = (try? await sessionManager.closeBetting()) ?? []
        self.currentPhaseName = "Betting Closed"
        self.broadcastScene.attachGems(backedGems)
        self.commentaryEngine.speak("Betting is closed! All bets are locked and the Gnome Gems are revealed on the track!")
        await notifyClientsPhaseChanged()
    }

    public func toggleMysteryMode() {
        Task {
            let newMystery = !isMysteryMode
            self.isMysteryMode = newMystery
            await sessionManager.setChampionshipMode(newMystery ? .mystery : .open)
            self.commentaryEngine.speak(newMystery ? "Mystery Mode enabled! Balances are hidden until the Grand Finale!" : "Open Mode enabled! Live standings are now visible!")
        }
    }

    public func showGrandFinale() {
        Task {
            // Bypass Mystery Mode masking for the official TV Grand Finale reveal
            let projection = await sessionManager.getStandingsProjection(forRole: .bigScreenBroadcast)
            if let standings = projection.standings {
                self.finaleStandings = standings
            } else {
                // Temporarily reveal standings if triggered early before totalRaces
                await sessionManager.setChampionshipMode(.open)
                let revealed = await sessionManager.getStandingsProjection(forRole: .bigScreenBroadcast)
                self.finaleStandings = revealed.standings ?? []
                if isMysteryMode {
                    await sessionManager.setChampionshipMode(.mystery)
                }
            }
            if let champ = self.finaleStandings?.first {
                self.audioFX.playEffect(.trumpetFanfare)
                self.commentaryEngine.speak("Ladies and gentlemen, the Grand Finale reveal! Tonight's champion is \(champ.displayName) with \(String(format: "£%.2f", Double(champ.balancePennies) / 100.0))!")
            }
        }
    }

    public func resetSession() {
        Task {
            countdownTask?.cancel()
            countdownTask = nil
            self.bettingSecondsRemaining = nil
            self.lastRacePodium = []
            self.finaleStandings = nil
            await sessionManager.resetSession()
            let race = await sessionManager.prepareNextRace()
            await syncSceneToCurrentRace(race: race)
            self.currentRaceIndex = 1
            self.currentPhaseName = "Preparing"
            self.commentaryEngine.speak("Session reset! Welcome back to Oh! Gnomes, Race number one!")
            await notifyClientsPhaseChanged()
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

        self.audioFX.playEffect(.startingGun)
        let startSpeech = commentaryGenerator.commentaryForStart(courseName: course.name, entrantsCount: entrants.count, seed: Int(seed))
        self.commentaryEngine.speak(startSpeech, drama: .excited)

        let engine = SimulationEngine(
            raceId: race.id,
            masterSeed: seed,
            course: course,
            gnomes: entrants
        )

        let dt: Double = 1.0 / 30.0
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
                    broadcastScene.triggerFinishConfetti()
                    let winLine = commentaryGenerator.commentaryForWinner(winnerName: finisher.gnomeName, seed: Int(seed))
                    commentaryEngine.speak(winLine, drama: .triumph, interrupt: true)
                } else if rank == 2 {
                    commentaryEngine.speak("Second place goes to \(finisher.gnomeName)!", drama: .excited, interrupt: false)
                } else if rank == 3 {
                    commentaryEngine.speak("And \(finisher.gnomeName) claims third place on the podium!", drama: .normal, interrupt: false)
                }
            }

            // Live incident particle FX + throttled commentary (only before winner finishes)
            if engine.incidents.count > lastIncidentCount {
                let newIncident = engine.incidents[lastIncidentCount]
                lastIncidentCount = engine.incidents.count
                broadcastScene.triggerIncidentEffect(gnomeId: newIncident.runnerId, type: newIncident.incidentType)
                if !announcedRanks.contains(1),
                   !commentaryEngine.isSpeaking && (engine.currentTick - lastCommentaryTick) >= 75 {
                    lastCommentaryTick = engine.currentTick
                    let line = commentaryGenerator.commentaryForIncident(
                        runnerName: newIncident.runnerName,
                        incidentType: newIncident.incidentType,
                        reason: newIncident.description,
                        seed: engine.currentTick
                    )
                    commentaryEngine.speak(line, drama: .chaotic, interrupt: false)
                }
            }

            // Dynamic overtake commentary
            if let leader = updatedRunners.max(by: { $0.distanceMeters < $1.distanceMeters }) {
                if !announcedRanks.contains(1),
                   let prevId = lastLeaderId, prevId != leader.gnomeId,
                   !commentaryEngine.isSpeaking, (engine.currentTick - lastCommentaryTick) >= 90 {
                    lastCommentaryTick = engine.currentTick
                    let prevName = entrants.first(where: { $0.id == prevId })?.name ?? "the leader"
                    let overtakeLine = commentaryGenerator.commentaryForOvertake(leaderName: leader.gnomeName, chaserName: prevName, seed: engine.currentTick)
                    commentaryEngine.speak(overtakeLine, drama: .excited, interrupt: false)
                }
                lastLeaderId = leader.gnomeId
            }

            try? await Task.sleep(nanoseconds: 33_333_333) // ~30 FPS physics delay
        }

        // Finish line & settlement
        _ = try? await sessionManager.runSimulationAndSettle(course: course, seed: seed)

        let podium = engine.runners
            .filter { $0.isFinished }
            .sorted { ($0.finishRank ?? 99) < ($1.finishRank ?? 99) }
            .prefix(3)
        self.lastRacePodium = Array(podium)
        if podium.count == 3 {
            self.subtitleText = "🏆 1st: \(podium[0].gnomeName)  •  🥈 2nd: \(podium[1].gnomeName)  •  🥉 3rd: \(podium[2].gnomeName)"
        }

        self.currentPhaseName = "Race Finished (Settled)"
        isRunningRace = false
        await notifyClientsPhaseChanged()
    }
}
