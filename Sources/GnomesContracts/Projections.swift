import Foundation
import GnomesCore

public struct GnomeCardProjection: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let archetype: String
    public let portraitAsset: String
    public let biography: String
    public let traits: [GnomeTrait]
    public let oddsDisplay: String
    public let oddsQuoteId: String
    public let careerFormSummary: String

    public init(
        id: String,
        name: String,
        archetype: String,
        portraitAsset: String,
        biography: String,
        traits: [GnomeTrait],
        oddsDisplay: String,
        oddsQuoteId: String,
        careerFormSummary: String
    ) {
        self.id = id
        self.name = name
        self.archetype = archetype
        self.portraitAsset = portraitAsset
        self.biography = biography
        self.traits = traits
        self.oddsDisplay = oddsDisplay
        self.oddsQuoteId = oddsQuoteId
        self.careerFormSummary = careerFormSummary
    }
}

public struct BackedGnomeGem: Codable, Sendable, Identifiable {
    public var id: String { "\(gnomeId)_\(gem.id)" }
    public let gnomeId: String
    public let gem: GnomeGem
    public let playerDisplayName: String

    public init(gnomeId: String, gem: GnomeGem, playerDisplayName: String) {
        self.gnomeId = gnomeId
        self.gem = gem
        self.playerDisplayName = playerDisplayName
    }
}

public struct BetTicketProjection: Codable, Sendable {
    public let betId: String
    public let gnomeId: String
    public let gnomeName: String
    public let stakePennies: Int
    public let oddsDisplay: String
    public let potentialReturnPennies: Int
    public let acceptedAt: Date

    public init(
        betId: String,
        gnomeId: String,
        gnomeName: String,
        stakePennies: Int,
        oddsDisplay: String,
        potentialReturnPennies: Int,
        acceptedAt: Date
    ) {
        self.betId = betId
        self.gnomeId = gnomeId
        self.gnomeName = gnomeName
        self.stakePennies = stakePennies
        self.oddsDisplay = oddsDisplay
        self.potentialReturnPennies = potentialReturnPennies
        self.acceptedAt = acceptedAt
    }
}

public struct PlayerStanding: Codable, Sendable, Identifiable {
    public var id: String { playerId }
    public let playerId: String
    public let displayName: String
    public let gem: GnomeGem
    public let balancePennies: Int
    public let rank: Int

    public init(playerId: String, displayName: String, gem: GnomeGem, balancePennies: Int, rank: Int) {
        self.playerId = playerId
        self.displayName = displayName
        self.gem = gem
        self.balancePennies = balancePennies
        self.rank = rank
    }
}

public struct StandingsProjection: Codable, Sendable {
    public let isMysteryMode: Bool
    public let isFinale: Bool
    /// Standings are strictly nil in Mystery Mode until the Grand Finale
    public let standings: [PlayerStanding]?

    public init(isMysteryMode: Bool, isFinale: Bool, standings: [PlayerStanding]?) {
        self.isMysteryMode = isMysteryMode
        self.isFinale = isFinale
        if isMysteryMode && !isFinale {
            self.standings = nil
        } else {
            self.standings = standings
        }
    }
}

public struct CurrentRaceViewPayload: Codable, Sendable {
    public let raceId: String
    public let raceIndex: Int
    public let phase: RacePhase
    public let courseName: String
    public let entrants: [GnomeCardProjection]
    public let myBet: BetTicketProjection?
    public let myBalancePennies: Int
    public let secondsRemaining: Int?
    public let mySettlement: SettlementPayload?

    public init(
        raceId: String,
        raceIndex: Int,
        phase: RacePhase,
        courseName: String,
        entrants: [GnomeCardProjection],
        myBet: BetTicketProjection?,
        myBalancePennies: Int,
        secondsRemaining: Int? = nil,
        mySettlement: SettlementPayload? = nil
    ) {
        self.raceId = raceId
        self.raceIndex = raceIndex
        self.phase = phase
        self.courseName = courseName
        self.entrants = entrants
        self.myBet = myBet
        self.myBalancePennies = myBalancePennies
        self.secondsRemaining = secondsRemaining
        self.mySettlement = mySettlement
    }
}
