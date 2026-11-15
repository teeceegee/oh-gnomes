import Foundation

public struct Player: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let sessionId: String
    public var displayName: String
    public let gemId: String
    public var balancePennies: Int
    public var status: PlayerStatus
    public let deviceCredentialHash: String
    public var joinedAt: Date

    public static let initialStartingBalancePennies: Int = 50_000 // £500.00

    public enum PlayerStatus: String, Codable, Sendable {
        case active
        case eliminated // Reached £0 balance
        case disconnected
    }

    public var isEliminated: Bool {
        return balancePennies <= 0
    }

    public var balanceFormattedPounds: String {
        let pounds = Double(balancePennies) / 100.0
        return String(format: "£%.2f", pounds)
    }

    public init(
        id: String = UUID().uuidString,
        sessionId: String,
        displayName: String,
        gemId: String,
        balancePennies: Int = initialStartingBalancePennies,
        status: PlayerStatus = .active,
        deviceCredentialHash: String,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.displayName = displayName
        self.gemId = gemId
        self.balancePennies = balancePennies
        self.status = status
        self.deviceCredentialHash = deviceCredentialHash
        self.joinedAt = joinedAt
    }
}
