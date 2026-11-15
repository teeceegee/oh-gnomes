import Foundation
import GnomesCore

public enum RunnerStatusEffect: String, Codable, Sendable {
    case running
    case stumbled           // Tripped or fallen, 0 velocity, recovering
    case airborneLaunch     // Leaping forward at high speed
    case mudStuck           // Heavily slowed in mud
    case sprinting          // Final stretch speed surge
    case finished           // Crossed the finish line
}

public struct RunnerState: Codable, Sendable, Equatable, Identifiable {
    public var id: String { gnomeId }
    public let gnomeId: String
    public let gnomeName: String
    public let lane: Int                    // 1..8
    public var distanceMeters: Double
    public var velocityMps: Double          // Meters per second
    public var stamina: Double              // 0.0 to 1.0
    public var balance: Double              // 0.0 to 1.0
    public var statusEffect: RunnerStatusEffect
    public var recoveryTimerTicks: Int      // Countdown while stumbled/recovering
    public var finishTick: Int?
    public var finishRank: Int?
    public var totalIncidents: Int

    public var isFinished: Bool {
        return finishTick != nil
    }

    public init(
        gnomeId: String,
        gnomeName: String,
        lane: Int,
        distanceMeters: Double = 0.0,
        velocityMps: Double = 0.0,
        stamina: Double = 1.0,
        balance: Double = 1.0,
        statusEffect: RunnerStatusEffect = .running,
        recoveryTimerTicks: Int = 0,
        finishTick: Int? = nil,
        finishRank: Int? = nil,
        totalIncidents: Int = 0
    ) {
        self.gnomeId = gnomeId
        self.gnomeName = gnomeName
        self.lane = lane
        self.distanceMeters = distanceMeters
        self.velocityMps = velocityMps
        self.stamina = stamina
        self.balance = balance
        self.statusEffect = statusEffect
        self.recoveryTimerTicks = recoveryTimerTicks
        self.finishTick = finishTick
        self.finishRank = finishRank
        self.totalIncidents = totalIncidents
    }
}
