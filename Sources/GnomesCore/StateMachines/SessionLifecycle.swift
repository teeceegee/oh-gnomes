import Foundation

public enum ChampionshipMode: String, Codable, Sendable {
    case open
    case mystery
}

public enum SessionPhase: String, Codable, Sendable, CaseIterable {
    case lobby
    case registrationClosed
    case inProgress
    case pausedBetweenRaces
    case completed
    case interrupted

    public func canTransition(to next: SessionPhase) -> Bool {
        switch (self, next) {
        case (.lobby, .registrationClosed): return true
        case (.registrationClosed, .inProgress): return true
        case (.inProgress, .pausedBetweenRaces): return true
        case (.pausedBetweenRaces, .inProgress): return true
        case (.inProgress, .completed): return true
        case (.pausedBetweenRaces, .completed): return true
        // Interrupted can happen from any active state and recover
        case (.inProgress, .interrupted): return true
        case (.pausedBetweenRaces, .interrupted): return true
        case (.interrupted, .inProgress): return true
        case (.interrupted, .pausedBetweenRaces): return true
        default: return false
        }
    }
}

public struct GameSession: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let joinCode: String
    public var mode: ChampionshipMode
    public var phase: SessionPhase
    public var currentRaceId: String?
    public var currentRaceIndex: Int
    public let totalRaces: Int
    public let rulesetVersion: String
    public let createdAt: Date

    public static let defaultTotalRaces = 6

    public init(
        id: String = UUID().uuidString,
        joinCode: String,
        mode: ChampionshipMode = .open,
        phase: SessionPhase = .lobby,
        currentRaceId: String? = nil,
        currentRaceIndex: Int = 0,
        totalRaces: Int = defaultTotalRaces,
        rulesetVersion: String = "1.0.0",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.joinCode = joinCode
        self.mode = mode
        self.phase = phase
        self.currentRaceId = currentRaceId
        self.currentRaceIndex = currentRaceIndex
        self.totalRaces = totalRaces
        self.rulesetVersion = rulesetVersion
        self.createdAt = createdAt
    }
}
