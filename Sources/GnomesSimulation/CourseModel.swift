import Foundation

public enum SurfaceType: String, Codable, Sendable {
    case grass
    case mud
    case stone
    case water
}

public struct SurfaceZone: Codable, Sendable, Equatable {
    public let startMeter: Double
    public let endMeter: Double
    public let surfaceType: SurfaceType
    public let speedMultiplier: Double   // e.g. 0.6 for thick mud, 1.0 for grass, 1.1 for smooth stone
    public let slipRiskPerTick: Double    // chance of stumbling per tick on this surface

    public init(startMeter: Double, endMeter: Double, surfaceType: SurfaceType, speedMultiplier: Double, slipRiskPerTick: Double) {
        self.startMeter = startMeter
        self.endMeter = endMeter
        self.surfaceType = surfaceType
        self.speedMultiplier = speedMultiplier
        self.slipRiskPerTick = slipRiskPerTick
    }
}

public enum ObstacleType: String, Codable, Sendable {
    case springLauncher   // Launches gnome airborne with high velocity burst, but crash risk
    case mudPuddle        // Drastic speed reduction and balance check
    case lowHedge         // Jump check; stumble if balance is low
    case moleHill         // Random lateral deflection and stumble risk
    case waterSprinkler   // Temporary disorientation and balance reduction
}

public struct ObstacleZone: Codable, Sendable, Equatable {
    public let id: String
    public let locationMeter: Double
    public let triggerRadiusMeters: Double
    public let obstacleType: ObstacleType
    public let baseTriggerChance: Double

    public init(id: String, locationMeter: Double, triggerRadiusMeters: Double, obstacleType: ObstacleType, baseTriggerChance: Double = 0.5) {
        self.id = id
        self.locationMeter = locationMeter
        self.triggerRadiusMeters = triggerRadiusMeters
        self.obstacleType = obstacleType
        self.baseTriggerChance = baseTriggerChance
    }
}

public struct Course: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let totalDistanceMeters: Double
    public let surfaceZones: [SurfaceZone]
    public let obstacleZones: [ObstacleZone]

    public init(
        id: String,
        name: String,
        description: String,
        totalDistanceMeters: Double,
        surfaceZones: [SurfaceZone],
        obstacleZones: [ObstacleZone]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.totalDistanceMeters = totalDistanceMeters
        self.surfaceZones = surfaceZones
        self.obstacleZones = obstacleZones
    }

    /// Prototype course: Gnome Garden Grand Prix (300 meters)
    public static let gardenGrandPrix = Course(
        id: "course_garden_grand_prix",
        name: "Gnome Garden Grand Prix",
        description: "The classic backyard garden loop featuring lush lawns, a treacherous flowerbed mud pit, and a sprinkler jump.",
        totalDistanceMeters: 300.0,
        surfaceZones: [
            SurfaceZone(startMeter: 0.0, endMeter: 80.0, surfaceType: .grass, speedMultiplier: 1.0, slipRiskPerTick: 0.001),
            SurfaceZone(startMeter: 80.0, endMeter: 150.0, surfaceType: .mud, speedMultiplier: 0.65, slipRiskPerTick: 0.015),
            SurfaceZone(startMeter: 150.0, endMeter: 220.0, surfaceType: .stone, speedMultiplier: 1.15, slipRiskPerTick: 0.003),
            SurfaceZone(startMeter: 220.0, endMeter: 300.0, surfaceType: .grass, speedMultiplier: 1.0, slipRiskPerTick: 0.001)
        ],
        obstacleZones: [
            ObstacleZone(id: "obs_spring_1", locationMeter: 60.0, triggerRadiusMeters: 3.0, obstacleType: .springLauncher, baseTriggerChance: 0.4),
            ObstacleZone(id: "obs_mud_puddle_1", locationMeter: 110.0, triggerRadiusMeters: 4.0, obstacleType: .mudPuddle, baseTriggerChance: 0.6),
            ObstacleZone(id: "obs_sprinkler_1", locationMeter: 240.0, triggerRadiusMeters: 5.0, obstacleType: .waterSprinkler, baseTriggerChance: 0.5)
        ]
    )
}
