import Foundation

public struct GnomeAttributes: Codable, Sendable, Equatable {
    public var speed: Double         // Baseline top speed (0.0 - 1.0)
    public var acceleration: Double  // How quickly top speed is reached
    public var stamina: Double       // Endurance before fatigue sets in
    public var balance: Double       // Resistance to stumbles and trips
    public var recovery: Double      // Speed of getting back up after an incident

    public init(speed: Double, acceleration: Double, stamina: Double, balance: Double, recovery: Double) {
        self.speed = speed
        self.acceleration = acceleration
        self.stamina = stamina
        self.balance = balance
        self.recovery = recovery
    }
}

public struct GnomeTrait: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let description: String
    public let effectCategory: TraitCategory

    public enum TraitCategory: String, Codable, Sendable {
        case startBoost
        case mudAffinity
        case slipProne
        case obstacleSpringer
        case staminaSurge
        case chaosMagnet
    }

    public init(id: String, displayName: String, description: String, effectCategory: TraitCategory) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.effectCategory = effectCategory
    }
}

public struct CareerRecord: Codable, Sendable, Equatable {
    public var racesRun: Int
    public var wins: Int
    public var podiums: Int
    public var incidentsEncountered: Int
    public var formRating: Double  // Bounded latent form (-1.0 to +1.0)

    public init(racesRun: Int = 0, wins: Int = 0, podiums: Int = 0, incidentsEncountered: Int = 0, formRating: Double = 0.0) {
        self.racesRun = racesRun
        self.wins = wins
        self.podiums = podiums
        self.incidentsEncountered = incidentsEncountered
        self.formRating = formRating
    }
}

public struct Gnome: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let archetype: String
    public let portraitAsset: String
    public let biography: String
    public let traits: [GnomeTrait]
    public let baselineAttributes: GnomeAttributes
    public var career: CareerRecord

    public init(
        id: String,
        name: String,
        archetype: String,
        portraitAsset: String,
        biography: String,
        traits: [GnomeTrait],
        baselineAttributes: GnomeAttributes,
        career: CareerRecord = CareerRecord()
    ) {
        self.id = id
        self.name = name
        self.archetype = archetype
        self.portraitAsset = portraitAsset
        self.biography = biography
        self.traits = traits
        self.baselineAttributes = baselineAttributes
        self.career = career
    }
}
