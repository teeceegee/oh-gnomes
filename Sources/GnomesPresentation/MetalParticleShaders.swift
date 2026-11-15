import Foundation
import SpriteKit

@MainActor
public struct MetalParticleShaders: Sendable {
    /// Custom Metal fragment shader for viscous mud droplets with specular gleam
    public static let mudParticleShaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct ParticleUniforms {
        float time;
        float mudViscosity;
    };

    fragment float4 mudFragmentShader(float4 color [[stage_in]],
                                       float2 coord [[point_coord]],
                                       constant ParticleUniforms& uniforms [[buffer(0)]]) {
        // Distance from point center
        float dist = length(coord - float2(0.5, 0.5));
        if (dist > 0.5) {
            discard_fragment();
        }

        // Deep rich earth-brown gradient
        float3 darkMud = float3(0.28, 0.16, 0.08);
        float3 lightMud = float3(0.42, 0.28, 0.16);
        float3 baseColor = mix(lightMud, darkMud, dist * 2.0);

        // Specular highlight gleam at top-left
        float spec = max(0.0, 1.0 - length(coord - float2(0.35, 0.35)) * 4.0);
        baseColor += float3(spec * 0.35);

        return float4(baseColor, 1.0);
    }
    """

    public init() {}

    /// Factory for creating mud splash particle emitter
    public static func makeMudSplashEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 40
        emitter.numParticlesToEmit = 15
        emitter.particleLifetime = 0.5
        emitter.particleSpeed = 120
        emitter.particleSpeedRange = 60
        emitter.emissionAngle = CGFloat.pi / 2.0
        emitter.emissionAngleRange = CGFloat.pi / 3.0
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1.5
        emitter.particleScale = 0.3
        emitter.particleColor = ColorType(red: 0.36, green: 0.22, blue: 0.12, alpha: 1.0)
        return emitter
    }

    /// Factory for creating spring launcher dust burst
    public static func makeSpringDustEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 60
        emitter.numParticlesToEmit = 25
        emitter.particleLifetime = 0.4
        emitter.particleSpeed = 160
        emitter.particleSpeedRange = 80
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = CGFloat.pi * 2.0
        emitter.particleAlpha = 0.7
        emitter.particleAlphaSpeed = -1.8
        emitter.particleScale = 0.4
        emitter.particleColor = ColorType(white: 0.85, alpha: 0.6)
        return emitter
    }
}
