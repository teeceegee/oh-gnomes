import Foundation
import AVFoundation

public enum VoiceDramaLevel: Sendable {
    case calm
    case normal
    case excited
    case chaotic
    case triumph
}

public final class CommentaryEngine: NSObject, @unchecked Sendable, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    public var onSubtitleEmitted: (@Sendable (String) -> Void)?
    private let voice: AVSpeechSynthesisVoice?

    override public init() {
        // Select highest-quality British English voice available on macOS (premium > enhanced > default)
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let gbVoices = voices.filter { $0.language.hasPrefix("en-GB") }
        self.voice = gbVoices.first(where: { $0.quality == .premium })
            ?? gbVoices.first(where: { $0.quality == .enhanced })
            ?? gbVoices.first(where: { $0.name.contains("Arthur") || $0.name.contains("Daniel") || $0.name.contains("Martha") })
            ?? AVSpeechSynthesisVoice(language: "en-GB")
            ?? AVSpeechSynthesisVoice(language: "en-US")
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks a commentary line with expressive broadcast cadence matched to the drama level
    public func speak(
        _ text: String,
        drama: VoiceDramaLevel = .normal,
        interrupt: Bool = true
    ) {
        if interrupt {
            stopSpeaking()
        }
        onSubtitleEmitted?(text)

        let (pitch, rate, preDelay): (Float, Float, TimeInterval)
        switch drama {
        case .calm:
            pitch = 0.98
            rate = 0.48
            preDelay = 0.08
        case .normal:
            pitch = 1.03
            rate = 0.51
            preDelay = 0.04
        case .excited:
            pitch = 1.10
            rate = 0.55
            preDelay = 0.02
        case .chaotic:
            pitch = 1.15
            rate = 0.57
            preDelay = 0.01
        case .triumph:
            pitch = 1.08
            rate = 0.50
            preDelay = 0.05
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.pitchMultiplier = pitch
        utterance.rate = rate
        utterance.preUtteranceDelay = preDelay
        utterance.postUtteranceDelay = 0.08

        synthesizer.speak(utterance)
    }

    /// Compatibility overload for explicit pitch/rate callers
    public func speak(_ text: String, pitchMultiplier: Float, rateMultiplier: Float = 0.52, interrupt: Bool = true) {
        if interrupt {
            stopSpeaking()
        }
        onSubtitleEmitted?(text)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.pitchMultiplier = pitchMultiplier
        utterance.rate = rateMultiplier
        utterance.preUtteranceDelay = 0.04
        utterance.postUtteranceDelay = 0.08

        synthesizer.speak(utterance)
    }

    public func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    public var isSpeaking: Bool {
        return synthesizer.isSpeaking
    }
}
