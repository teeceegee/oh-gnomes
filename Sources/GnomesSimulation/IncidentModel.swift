import Foundation
import GnomesCore

public enum IncidentType: String, Codable, Sendable {
    case stumble
    case airborneLaunch
    case mudSplash
    case sprinklerDaze
    case sprintSurge
    case gnomeCollision
    case gnomePileup
    case hedgeShortcut
    case snailDistraction
    case hatSteal
    case mudSlideBowling
}

public struct IncidentRecord: Codable, Sendable {
    public let tick: Int
    public let runnerId: String
    public let runnerName: String
    public let incidentType: IncidentType
    public let description: String
    public let distanceMeter: Double
    public let cascadeDepth: Int

    public init(
        tick: Int,
        runnerId: String,
        runnerName: String,
        incidentType: IncidentType,
        description: String,
        distanceMeter: Double,
        cascadeDepth: Int = 0
    ) {
        self.tick = tick
        self.runnerId = runnerId
        self.runnerName = runnerName
        self.incidentType = incidentType
        self.description = description
        self.distanceMeter = distanceMeter
        self.cascadeDepth = cascadeDepth
    }
}

/// Strict limiter preventing runaway cascading crashes
public struct IncidentLimiter: Sendable {
    public static let maxCascadeDepth: Int = 2
    public static let maxIncidentsPerTick: Int = 3

    private var currentTick: Int = -1
    private var incidentsThisTick: Int = 0

    public init() {}

    public mutating func canTriggerIncident(atTick tick: Int, cascadeDepth: Int) -> Bool {
        if cascadeDepth > Self.maxCascadeDepth {
            return false
        }
        if tick != currentTick {
            currentTick = tick
            incidentsThisTick = 0
        }
        if incidentsThisTick >= Self.maxIncidentsPerTick {
            return false
        }
        incidentsThisTick += 1
        return true
    }
}
