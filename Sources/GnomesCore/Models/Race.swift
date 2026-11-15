import Foundation

public struct Race: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let sessionId: String
    public let raceIndex: Int
    public let courseId: String
    public let entrantIds: [String] // Exactly 8 gnomes
    public var phase: RacePhase
    public var seed: UInt64
    public var inputHash: String
    public var resultHash: String?
    public var createdAt: Date

    public static let requiredEntrantCount = 8

    public init(
        id: String = UUID().uuidString,
        sessionId: String,
        raceIndex: Int,
        courseId: String,
        entrantIds: [String],
        phase: RacePhase = .preparing,
        seed: UInt64 = 0,
        inputHash: String = "",
        resultHash: String? = nil,
        createdAt: Date = Date()
    ) {
        precondition(entrantIds.count == Race.requiredEntrantCount, "A race must have exactly \(Race.requiredEntrantCount) entrants.")
        self.id = id
        self.sessionId = sessionId
        self.raceIndex = raceIndex
        self.courseId = courseId
        self.entrantIds = entrantIds
        self.phase = phase
        self.seed = seed
        self.inputHash = inputHash
        self.resultHash = resultHash
        self.createdAt = createdAt
    }
}
