import Foundation
import GnomesCore

public struct JoinSuccessPayload: Codable, Sendable {
    public let playerId: String
    public let displayName: String
    public let gem: GnomeGem
    public let balancePennies: Int
    public let sessionJoinCode: String
    public let mode: ChampionshipMode
    public let deviceCredentialHash: String

    public init(
        playerId: String,
        displayName: String,
        gem: GnomeGem,
        balancePennies: Int,
        sessionJoinCode: String,
        mode: ChampionshipMode,
        deviceCredentialHash: String
    ) {
        self.playerId = playerId
        self.displayName = displayName
        self.gem = gem
        self.balancePennies = balancePennies
        self.sessionJoinCode = sessionJoinCode
        self.mode = mode
        self.deviceCredentialHash = deviceCredentialHash
    }
}

public struct PhaseChangedPayload: Codable, Sendable {
    public let raceId: String
    public let phase: RacePhase
    public let secondsRemaining: Int?
    public let serverTimestamp: Date

    public init(raceId: String, phase: RacePhase, secondsRemaining: Int? = nil, serverTimestamp: Date = Date()) {
        self.raceId = raceId
        self.phase = phase
        self.secondsRemaining = secondsRemaining
        self.serverTimestamp = serverTimestamp
    }
}

public struct BettingClosedPayload: Codable, Sendable {
    public let raceId: String
    public let backedGems: [BackedGnomeGem]

    public init(raceId: String, backedGems: [BackedGnomeGem]) {
        self.raceId = raceId
        self.backedGems = backedGems
    }
}

public struct SettlementPayload: Codable, Sendable {
    public let raceId: String
    public let winningGnomeId: String
    public let winningGnomeName: String
    public let myPayoutPennies: Int
    public let myNewBalancePennies: Int
    public let isWinner: Bool

    public init(
        raceId: String,
        winningGnomeId: String,
        winningGnomeName: String,
        myPayoutPennies: Int,
        myNewBalancePennies: Int,
        isWinner: Bool
    ) {
        self.raceId = raceId
        self.winningGnomeId = winningGnomeId
        self.winningGnomeName = winningGnomeName
        self.myPayoutPennies = myPayoutPennies
        self.myNewBalancePennies = myNewBalancePennies
        self.isWinner = isWinner
    }
}

public struct ServerEnvelope: Codable, Sendable {
    public let type: MessageType
    public let payloadJSON: String
    public let timestamp: Date

    public enum MessageType: String, Codable, Sendable {
        case joinSuccess
        case joinError
        case reconnectSuccess
        case phaseChanged
        case bettingClosed
        case raceEventBatch
        case settlementAnnounced
        case standingsUpdated
        case hostStatus
        case error
    }

    public init(type: MessageType, payloadJSON: String, timestamp: Date = Date()) {
        self.type = type
        self.payloadJSON = payloadJSON
        self.timestamp = timestamp
    }
}
