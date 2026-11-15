import Foundation
import GnomesCore
import GnomesContracts
import GnomesEconomy
import GnomesSimulation

public enum SessionError: Error, Equatable {
    case sessionFull(max: Int)
    case invalidJoinCode(String)
    case playerAlreadyJoined(String)
    case bettingClosed
    case alreadyBet(String)
    case invalidPhase(current: RacePhase, expected: RacePhase)
    case unauthorizedHost
}

/// Actor orchestrating the authoritative race-night session lifecycle, players, gem allocation, and race transitions
public actor SessionManager {
    public static let maxPlayers: Int = 20

    public private(set) var session: GameSession
    public private(set) var players: [String: Player] = [:] // playerId -> Player
    public private(set) var allocatedGems: [String: String] = [:] // gemId -> playerId
    public private(set) var currentRace: Race?
    public private(set) var currentEntrants: [Gnome] = []
    public private(set) var currentQuotes: [OddsQuote] = []
    public private(set) var currentBets: [String: Bet] = [:] // playerId -> Bet
    public private(set) var currentSettlements: [Settlement] = []

    public let ledger: BankingLedger
    public let bookmaker: BookmakerService
    public let settlementService: SettlementService
    public let formEvolutionService: FormEvolutionService
    public let allGnomes: [Gnome]
    public let courses: [Course]
    public let adminSecret: String

    public init(
        joinCode: String = "GNOM",
        mode: ChampionshipMode = .mystery,
        allGnomes: [Gnome],
        courses: [Course] = [Course.gardenGrandPrix],
        adminSecret: String = "admin-secret-gnomes"
    ) {
        self.session = GameSession(joinCode: joinCode, mode: mode)
        self.allGnomes = allGnomes
        self.courses = courses
        self.adminSecret = adminSecret
        self.ledger = BankingLedger()
        self.bookmaker = BookmakerService()
        self.settlementService = SettlementService()
        self.formEvolutionService = FormEvolutionService()
    }

    // MARK: - Player Connection & Reconnection (D-01, D-05, D-10)

    /// Registers a new player or reconnects an existing player with their unique gem
    public func join(request: JoinRequest, credentialHash: String) async throws -> JoinSuccessPayload {
        guard request.joinCode.uppercased() == session.joinCode.uppercased() else {
            throw SessionError.invalidJoinCode(request.joinCode)
        }

        // 1. Check for reconnecting player with matching credential hash
        if let existing = players.values.first(where: { $0.deviceCredentialHash == credentialHash }) {
            let gem = GnomeGem.standardPalette.first(where: { $0.id == existing.gemId }) ?? GnomeGem.standardPalette[0]
            let balance = await ledger.getBalance(playerId: existing.id) ?? existing.balancePennies
            return JoinSuccessPayload(
                playerId: existing.id,
                displayName: existing.displayName,
                gem: gem,
                balancePennies: balance,
                sessionJoinCode: session.joinCode,
                mode: session.mode,
                deviceCredentialHash: credentialHash
            )
        }

        // 2. Capacity check (Max 20 players)
        guard players.count < Self.maxPlayers else {
            throw SessionError.sessionFull(max: Self.maxPlayers)
        }

        // 3. Allocate next available unique Gnome Gem
        let availableGem = GnomeGem.standardPalette.first { gem in
            allocatedGems[gem.id] == nil
        } ?? GnomeGem.standardPalette[players.count % GnomeGem.standardPalette.count]

        let newPlayerId = "p_\(UUID().uuidString.prefix(8))"
        let player = Player(
            id: newPlayerId,
            sessionId: session.id,
            displayName: request.displayName,
            gemId: availableGem.id,
            deviceCredentialHash: credentialHash
        )

        players[newPlayerId] = player
        allocatedGems[availableGem.id] = newPlayerId
        await ledger.registerPlayer(id: newPlayerId)

        return JoinSuccessPayload(
            playerId: newPlayerId,
            displayName: player.displayName,
            gem: availableGem,
            balancePennies: Player.initialStartingBalancePennies,
            sessionJoinCode: session.joinCode,
            mode: session.mode,
            deviceCredentialHash: credentialHash
        )
    }

    /// Reconnects a player using their saved device credentials
    public func reconnect(request: ReconnectRequest) async -> JoinSuccessPayload? {
        guard let player = players[request.playerId],
              player.deviceCredentialHash == request.deviceCredentialHash else {
            return nil
        }
        let gem = GnomeGem.standardPalette.first(where: { $0.id == player.gemId }) ?? GnomeGem.standardPalette[0]
        let balance = await ledger.getBalance(playerId: player.id) ?? player.balancePennies

        return JoinSuccessPayload(
            playerId: player.id,
            displayName: player.displayName,
            gem: gem,
            balancePennies: balance,
            sessionJoinCode: session.joinCode,
            mode: session.mode,
            deviceCredentialHash: player.deviceCredentialHash
        )
    }

    // MARK: - Race Lifecycle (Preparing -> Introduction -> BettingOpen)

    /// Prepares the next race: selects 8 entrants and generates odds quotes
    public func prepareNextRace() -> Race {
        let raceIndex = session.currentRaceIndex + 1
        session.currentRaceIndex = raceIndex
        session.phase = .inProgress

        // Select 8 entrants (first 8 or sliced from catalogue)
        let entrants = Array(allGnomes.prefix(8))
        self.currentEntrants = entrants
        self.currentBets = [:]
        self.currentSettlements = []

        let course = courses[(raceIndex - 1) % courses.count]
        let raceId = "race_\(session.joinCode)_\(raceIndex)"

        // Generate quotes
        let quotes = bookmaker.generateQuotes(raceId: raceId, entrants: entrants)
        self.currentQuotes = quotes

        let race = Race(
            id: raceId,
            sessionId: session.id,
            raceIndex: raceIndex,
            courseId: course.id,
            entrantIds: entrants.map { $0.id },
            phase: .preparing
        )
        self.currentRace = race
        self.session.currentRaceId = raceId
        return race
    }

    /// Advances race phase to Introduction
    public func startIntroduction() throws {
        guard var race = currentRace else { return }
        guard race.phase.canTransition(to: .introduction) else {
            throw SessionError.invalidPhase(current: race.phase, expected: .preparing)
        }
        race.phase = .introduction
        self.currentRace = race
    }

    /// Advances race phase to BettingOpen
    public func openBetting() throws {
        guard var race = currentRace else { return }
        guard race.phase.canTransition(to: .bettingOpen) else {
            throw SessionError.invalidPhase(current: race.phase, expected: .introduction)
        }
        race.phase = .bettingOpen
        self.currentRace = race
    }

    // MARK: - Betting (D-02, D-06)

    /// Places a single virtual-money bet for an eligible player
    public func placeBet(request: PlaceBetRequest, playerId: String) async throws -> BetTicketProjection {
        guard let race = currentRace, race.phase == .bettingOpen else {
            throw SessionError.bettingClosed
        }
        guard currentBets[playerId] == nil else {
            throw SessionError.alreadyBet(playerId)
        }
        guard let quote = currentQuotes.first(where: { $0.id == request.oddsQuoteId && $0.gnomeId == request.gnomeId }) else {
            throw BankingError.minimumStakeNotMet(minimum: 100, requested: request.stakePennies)
        }

        let betId = "bet_\(race.id)_\(playerId)"
        _ = try await ledger.reserveStake(playerId: playerId, betId: betId, stakePennies: request.stakePennies)

        let bet = Bet(
            id: betId,
            raceId: race.id,
            playerId: playerId,
            gnomeId: request.gnomeId,
            stakePennies: request.stakePennies,
            oddsQuoteId: quote.id,
            quoteNumerator: quote.numerator,
            quoteDenominator: quote.denominator,
            clientNonce: request.clientNonce
        )
        currentBets[playerId] = bet

        let gnomeName = currentEntrants.first(where: { $0.id == request.gnomeId })?.name ?? "Gnome"
        return BetTicketProjection(
            betId: bet.id,
            gnomeId: bet.gnomeId,
            gnomeName: gnomeName,
            stakePennies: bet.stakePennies,
            oddsDisplay: quote.displayString,
            potentialReturnPennies: bet.potentialReturnPennies,
            acceptedAt: bet.acceptedAt
        )
    }

    /// Locks betting atomically and generates the public Gnome Gem reveal mapping (D-05)
    public func closeBetting() throws -> [BackedGnomeGem] {
        guard var race = currentRace, race.phase == .bettingOpen else {
            throw SessionError.bettingClosed
        }
        race.phase = .bettingClosed
        self.currentRace = race

        // Map backed gems
        var backedGems: [BackedGnomeGem] = []
        for (playerId, bet) in currentBets {
            if let player = players[playerId],
               let gem = GnomeGem.standardPalette.first(where: { $0.id == player.gemId }) {
                backedGems.append(BackedGnomeGem(
                    gnomeId: bet.gnomeId,
                    gem: gem,
                    playerDisplayName: player.displayName
                ))
            }
        }
        return backedGems
    }

    // MARK: - Simulation & Settlement (D-08, D-11)

    /// Executes the deterministic race simulation and settles all placed bets
    public func runSimulationAndSettle(course: Course, seed: UInt64) async throws -> (SimulationResult, [Settlement]) {
        guard var race = currentRace, race.phase == .bettingClosed else {
            throw SessionError.invalidPhase(current: currentRace?.phase ?? .preparing, expected: .bettingClosed)
        }
        race.phase = .simulating
        race.seed = seed
        self.currentRace = race

        // 1. Run deterministic simulation
        let engine = SimulationEngine(
            raceId: race.id,
            masterSeed: seed,
            course: course,
            gnomes: currentEntrants
        )
        let simResult = engine.runToCompletion()

        race.phase = .settling
        race.resultHash = simResult.resultChecksum
        self.currentRace = race

        // 2. Determine winners (rank 1)
        let winningGnomes = simResult.finishOrder.filter { $0.finishRank == 1 }
        let winningGnomeIds = winningGnomes.map { $0.gnomeId }

        // 3. Settle bets idempotently
        let settlements = try await settlementService.settleBets(
            raceId: race.id,
            bets: Array(currentBets.values),
            quotes: currentQuotes,
            winningGnomeIds: winningGnomeIds,
            ledger: ledger
        )
        self.currentSettlements = settlements

        race.phase = .published
        self.currentRace = race

        return (simResult, settlements)
    }

    // MARK: - Projection & Mystery Mode Masking (D-04, Section 12)

    /// Generates role-projected standings adhering to Mystery Mode privacy constraints
    public func getStandingsProjection(forRole role: ClientRole) async -> StandingsProjection {
        let isFinale = session.currentRaceIndex >= session.totalRaces
        let isMystery = session.mode == .mystery

        var playerList: [PlayerStanding] = []
        for p in players.values {
            let bal = await ledger.getBalance(playerId: p.id) ?? p.balancePennies
            let gem = GnomeGem.standardPalette.first(where: { $0.id == p.gemId }) ?? GnomeGem.standardPalette[0]
            playerList.append(PlayerStanding(
                playerId: p.id,
                displayName: p.displayName,
                gem: gem,
                balancePennies: bal,
                rank: 1
            ))
        }

        // Sort by balance descending
        playerList.sort { $0.balancePennies > $1.balancePennies }
        let rankedStandings = playerList.enumerated().map { idx, standing in
            PlayerStanding(
                playerId: standing.playerId,
                displayName: standing.displayName,
                gem: standing.gem,
                balancePennies: standing.balancePennies,
                rank: idx + 1
            )
        }

        return StandingsProjection(
            isMysteryMode: isMystery,
            isFinale: isFinale,
            standings: rankedStandings
        )
    }
}
