import Foundation
import AVFoundation

public enum SoundEffectType: Sendable {
    case startingGun
    case trumpetFanfare
    case mudSquelch
    case springBoing
    case victoryCelebration
}

public final class AudioFXSynthesizer: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    public init() {
        engine.attach(playerNode)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        if let format = format {
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
            try? engine.start()
        }
    }

    deinit {
        engine.stop()
    }

    /// Plays procedural synthesized audio tones for sound effects
    public func playEffect(_ effect: SoundEffectType) {
        let sampleRate: Double = 44100.0
        let duration: Double

        switch effect {
        case .startingGun: duration = 0.15
        case .trumpetFanfare: duration = 0.8
        case .mudSquelch: duration = 0.25
        case .springBoing: duration = 0.35
        case .victoryCelebration: duration = 1.2
        }

        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount
        let channels = buffer.floatChannelData?[0]

        // Generate synthetic waveform
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let sample: Float

            switch effect {
            case .startingGun:
                // White noise burst with rapid decay
                let noise = Float.random(in: -1.0...1.0)
                let decay = Float(exp(-t * 25.0))
                sample = noise * decay * 0.8

            case .trumpetFanfare:
                // Brass harmonic triad (440Hz A4, 554Hz C#5, 659Hz E5)
                let freq = (t < 0.2) ? 440.0 : ((t < 0.4) ? 554.0 : 659.0)
                let tone = sin(2.0 * .pi * freq * t)
                sample = Float(tone * 0.4)

            case .mudSquelch:
                // Low pitch frequency sweep downward
                let freq = max(80.0, 300.0 - (t * 600.0))
                let tone = sin(2.0 * .pi * freq * t)
                sample = Float(tone * 0.5)

            case .springBoing:
                // Upward frequency sweep with wobble
                let freq = 200.0 + (t * 800.0) + (sin(t * 50.0) * 30.0)
                let tone = sin(2.0 * .pi * freq * t)
                sample = Float(tone * 0.45)

            case .victoryCelebration:
                // Bright high-energy fanfare chord
                let tone1 = sin(2.0 * .pi * 523.25 * t) // C5
                let tone2 = sin(2.0 * .pi * 659.25 * t) // E5
                let tone3 = sin(2.0 * .pi * 783.99 * t) // G5
                sample = Float((tone1 + tone2 + tone3) * 0.2)
            }

            channels?[i] = sample
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }
}
