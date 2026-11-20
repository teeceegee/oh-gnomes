import Foundation
import AVFoundation

public enum SoundEffectType: Sendable {
    case startingGun
    case raceBell
    case trumpetFanfare
    case mudSquelch
    case springBoing
    case crowdCheer
    case victoryCelebration
}

public final class AudioFXSynthesizer: @unchecked Sendable {
    private let sharedMixer: BroadcastAudioMixer?
    private let fallbackEngine: AVAudioEngine?
    private let fallbackPlayer: AVAudioPlayerNode?

    public init(mixer: BroadcastAudioMixer? = nil) {
        self.sharedMixer = mixer
        if mixer == nil {
            let eng = AVAudioEngine()
            let player = AVAudioPlayerNode()
            eng.attach(player)
            if let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) {
                eng.connect(player, to: eng.mainMixerNode, format: format)
                try? eng.start()
            }
            self.fallbackEngine = eng
            self.fallbackPlayer = player
        } else {
            self.fallbackEngine = nil
            self.fallbackPlayer = nil
        }
    }

    deinit {
        fallbackEngine?.stop()
    }

    /// Plays procedural synthesized broadcast sound effects
    public func playEffect(_ effect: SoundEffectType) {
        let sampleRate: Double = 44_100.0
        let duration: Double

        switch effect {
        case .startingGun: duration = 0.18
        case .raceBell: duration = 1.15
        case .trumpetFanfare: duration = 0.85
        case .mudSquelch: duration = 0.25
        case .springBoing: duration = 0.35
        case .crowdCheer: duration = 2.0
        case .victoryCelebration: duration = 1.3
        }

        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channels = buffer.floatChannelData?[0] else { return }

        buffer.frameLength = frameCount
        var b0 = 0.0, b1 = 0.0
        var rng: UInt64 = 0xCAFE_BABE_1234

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let sample: Float

            switch effect {
            case .startingGun:
                let noise = Float.random(in: -1.0...1.0)
                let decay = Float(exp(-t * 22.0))
                sample = noise * decay * 0.85

            case .raceBell:
                // Classic metallic horse-racing bell with rapid clapper strikes
                let strikePhase = (t * 14.0) - floor(t * 14.0)
                let strikeEnv = exp(-strikePhase * 8.0) * exp(-t * 1.4)
                let ring = sin(2.0 * .pi * 1180.0 * t) * 0.50
                    + sin(2.0 * .pi * 2370.0 * t) * 0.30
                    + sin(2.0 * .pi * 3540.0 * t) * 0.20
                sample = Float(ring * strikeEnv * 0.55)

            case .trumpetFanfare:
                let freq = (t < 0.2) ? 440.0 : ((t < 0.4) ? 554.37 : 659.25)
                let env = min(1.0, t * 20.0) * exp(-max(0.0, t - 0.55) * 4.5)
                let brass = sin(2.0 * .pi * freq * t) * 0.6 + sin(4.0 * .pi * freq * t) * 0.25 + sin(6.0 * .pi * freq * t) * 0.15
                sample = Float(brass * env * 0.42)

            case .mudSquelch:
                let freq = max(75.0, 310.0 - (t * 650.0))
                let env = exp(-t * 7.0)
                sample = Float(sin(2.0 * .pi * freq * t) * env * 0.5)

            case .springBoing:
                let freq = 200.0 + (t * 820.0) + (sin(t * 52.0) * 35.0)
                let env = exp(-t * 4.5)
                sample = Float(sin(2.0 * .pi * freq * t) * env * 0.48)

            case .crowdCheer:
                // Swelling stadium cheer burst (band-shaped noise with rise & decay)
                rng = rng &* 6364136223846793005 &+ 1442695040888963407
                let white = Double(Int64(bitPattern: rng)) / Double(Int64.max)
                b0 = 0.96 * b0 + white * 0.08
                b1 = 0.85 * b1 + b0 * 0.25
                let env = min(1.0, t * 3.5) * exp(-max(0.0, t - 0.8) * 1.4)
                sample = Float(b1 * env * 1.4)

            case .victoryCelebration:
                let env = min(1.0, t * 15.0) * exp(-max(0.0, t - 0.7) * 2.5)
                let tone1 = sin(2.0 * .pi * 523.25 * t)
                let tone2 = sin(2.0 * .pi * 659.25 * t)
                let tone3 = sin(2.0 * .pi * 783.99 * t)
                let tone4 = sin(2.0 * .pi * 1046.50 * t)
                sample = Float((tone1 + tone2 + tone3 + tone4) * 0.18 * env)
            }

            channels[i] = sample
        }

        if let mixer = sharedMixer {
            mixer.playFXBuffer(buffer)
        } else if let player = fallbackPlayer {
            player.scheduleBuffer(buffer, completionHandler: nil)
            if !player.isPlaying {
                player.play()
            }
        }
    }
}
