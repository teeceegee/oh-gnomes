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
    case catapultTrap     // High-arcing garden trowel catapult!
    case movingSprinkler  // Sweeping jet of cold water across lanes
    case snailDistraction // Giant prize snail blocks the lane, causing comical swerves
    case flowerpotDomino  // Knocking over terracotta pots triggers a chain-reaction stumble
}

public struct CourseWaypoint: Codable, Sendable, Equatable {
    public let distanceMeter: Double
    public let x: Double
    public let yElevation: Double
    public let zLateral: Double

    public init(distanceMeter: Double, x: Double, yElevation: Double, zLateral: Double) {
        self.distanceMeter = distanceMeter
        self.x = x
        self.yElevation = yElevation
        self.zLateral = zLateral
    }
}

public struct CoursePoint3D: Sendable {
    public let x: Double
    public let y: Double
    public let z: Double
    public let headingRadians: Double
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
    public let waypoints: [CourseWaypoint]?

    public init(
        id: String,
        name: String,
        description: String,
        totalDistanceMeters: Double,
        surfaceZones: [SurfaceZone],
        obstacleZones: [ObstacleZone],
        waypoints: [CourseWaypoint]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.totalDistanceMeters = totalDistanceMeters
        self.surfaceZones = surfaceZones
        self.obstacleZones = obstacleZones
        self.waypoints = waypoints
    }

    /// Computes 3D world position and track tangent heading at a given race distance and lane (1..8)
    public func position3D(atDistanceMeters dist: Double, lane: Int) -> CoursePoint3D {
        let clampedDist = max(0.0, min(totalDistanceMeters, dist))
        let laneOffset = (Double(lane) - 4.5) * 1.1 // 1.1m per lane centered around 0

        if let pts = waypoints, pts.count >= 2 {
            // Find segment
            var idx = 0
            while idx < pts.count - 2 && pts[idx + 1].distanceMeter < clampedDist {
                idx += 1
            }
            let p0 = pts[idx]
            let p1 = pts[idx + 1]
            let span = max(0.001, p1.distanceMeter - p0.distanceMeter)
            let t = max(0.0, min(1.0, (clampedDist - p0.distanceMeter) / span))
            // Smoothstep interpolation
            let s = t * t * (3.0 - 2.0 * t)
            let cx = p0.x + (p1.x - p0.x) * s
            let cy = p0.yElevation + (p1.yElevation - p0.yElevation) * s
            let cz = p0.zLateral + (p1.zLateral - p0.zLateral) * s

            let dx = p1.x - p0.x
            let dz = p1.zLateral - p0.zLateral
            let heading = atan2(-dz, dx)
            let nx = -sin(heading)
            let nz = cos(heading)
            return CoursePoint3D(x: cx + nx * laneOffset, y: cy, z: cz + nz * laneOffset, headingRadians: heading)
        }

        // Default gentle undulating garden spline
        let waveZ = sin(clampedDist * 0.045) * 3.5
        let waveY = sin(clampedDist * 0.06) * 0.55 + (clampedDist > 100 && clampedDist < 200 ? 0.6 : 0.0)
        let dz = cos(clampedDist * 0.045) * 3.5 * 0.045
        let heading = atan2(-dz, 1.0)
        let nx = -sin(heading)
        let nz = cos(heading)
        return CoursePoint3D(x: clampedDist + nx * laneOffset, y: waveY, z: waveZ + nz * laneOffset, headingRadians: heading)
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
