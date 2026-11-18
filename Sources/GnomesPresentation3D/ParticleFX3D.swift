import Foundation
import SceneKit
import AppKit

@MainActor
public enum ParticleFX3D {
    /// 3D mud clods splashing upward with gravity
    public static func makeMudSplash3D() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.birthRate = 90
        ps.emissionDuration = 0.35
        ps.loops = false
        ps.particleLifeSpan = 0.75
        ps.particleSize = 0.08
        ps.particleSizeVariation = 0.04
        ps.particleVelocity = 4.2
        ps.particleVelocityVariation = 1.8
        ps.spreadingAngle = 55
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.acceleration = SCNVector3(0, -11.0, 0)
        ps.particleColor = NSColor(red: 0.36, green: 0.21, blue: 0.10, alpha: 1.0)
        ps.isAffectedByGravity = true
        return ps
    }

    /// 3D water sprinkler mist & droplets
    public static func makeWaterSpray3D() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.birthRate = 140
        ps.emissionDuration = 0.5
        ps.loops = false
        ps.particleLifeSpan = 0.65
        ps.particleSize = 0.06
        ps.particleVelocity = 5.0
        ps.particleVelocityVariation = 2.0
        ps.spreadingAngle = 70
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.acceleration = SCNVector3(0, -8.5, 0)
        ps.particleColor = NSColor(red: 0.55, green: 0.85, blue: 1.0, alpha: 0.85)
        return ps
    }

    /// 3D spring launcher / catapult golden dust burst
    public static func makeSpringBurst3D() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.birthRate = 120
        ps.emissionDuration = 0.3
        ps.loops = false
        ps.particleLifeSpan = 0.6
        ps.particleSize = 0.10
        ps.particleVelocity = 4.5
        ps.spreadingAngle = 85
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.acceleration = SCNVector3(0, -2.5, 0)
        ps.particleColor = NSColor(red: 0.98, green: 0.85, blue: 0.35, alpha: 0.85)
        return ps
    }

    /// 3D celebration confetti at the finish gantry
    public static func makeFinishConfetti3D() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.birthRate = 180
        ps.emissionDuration = 3.0
        ps.loops = false
        ps.particleLifeSpan = 2.5
        ps.particleSize = 0.12
        ps.particleSizeVariation = 0.06
        ps.particleVelocity = 6.5
        ps.particleVelocityVariation = 2.5
        ps.spreadingAngle = 75
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.acceleration = SCNVector3(0, -4.0, 0)
        ps.particleColor = NSColor(red: 1.0, green: 0.82, blue: 0.2, alpha: 1.0)
        ps.particleColorVariation = SCNVector4(0.8, 0.8, 0.8, 0.0)
        return ps
    }
}
