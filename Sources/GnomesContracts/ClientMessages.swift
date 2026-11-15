import Foundation
import GnomesCore

public enum ClientRole: String, Codable, Sendable {
    case phonePlayer
    case bigScreenBroadcast
    case hostControl
}

public struct JoinRequest: Codable, Sendable {
    public let joinCode: String
    public let displayName: String
    public let clientNonce: String

    public init(joinCode: String, displayName: String, clientNonce: String) {
        self.joinCode = joinCode
        self.displayName = displayName
        self.clientNonce = clientNonce
    }
}

public struct ReconnectRequest: Codable, Sendable {
    public let playerId: String
    public let deviceCredentialHash: String
    public let lastSeenSequence: Int

    public init(playerId: String, deviceCredentialHash: String, lastSeenSequence: Int = 0) {
        self.playerId = playerId
        self.deviceCredentialHash = deviceCredentialHash
        self.lastSeenSequence = lastSeenSequence
    }
}

public struct PlaceBetRequest: Codable, Sendable {
    public let raceId: String
    public let gnomeId: String
    public let stakePennies: Int
    public let oddsQuoteId: String
    public let clientNonce: String

    public init(raceId: String, gnomeId: String, stakePennies: Int, oddsQuoteId: String, clientNonce: String = UUID().uuidString) {
        self.raceId = raceId
        self.gnomeId = gnomeId
        self.stakePennies = stakePennies
        self.oddsQuoteId = oddsQuoteId
        self.clientNonce = clientNonce
    }
}

public enum HostCommandType: String, Codable, Sendable {
    case pause
    case resume
    case extendBetting
    case advanceToNextRace
    case triggerReplay
}

public struct HostActionRequest: Codable, Sendable {
    public let command: HostCommandType
    public let parameterInt: Int?
    public let adminSecret: String

    public init(command: HostCommandType, parameterInt: Int? = nil, adminSecret: String) {
        self.command = command
        self.parameterInt = parameterInt
        self.adminSecret = adminSecret
    }
}
