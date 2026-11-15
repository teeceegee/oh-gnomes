import Foundation

public struct RaceEvent: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let raceId: String
    public let sequence: Int
    public let tick: Int
    public let eventType: RaceEventType
    public let payloadJSON: String
    public let checksum: String
    public let idempotencyKey: String
    public let timestamp: Date

    public enum RaceEventType: String, Codable, Sendable {
        case raceStarted
        case tickUpdate
        case positionChange
        case obstacleTriggered
        case incidentOccurred
        case staminaDepleted
        case speedSurge
        case photoFinishTriggered
        case runnerCrossedFinish
        case raceCompleted
    }

    public init(
        id: String = UUID().uuidString,
        raceId: String,
        sequence: Int,
        tick: Int,
        eventType: RaceEventType,
        payloadJSON: String,
        checksum: String,
        idempotencyKey: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.raceId = raceId
        self.sequence = sequence
        self.tick = tick
        self.eventType = eventType
        self.payloadJSON = payloadJSON
        self.checksum = checksum
        self.idempotencyKey = idempotencyKey
        self.timestamp = timestamp
    }
}
