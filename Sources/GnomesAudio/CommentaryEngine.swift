import Foundation
import AVFoundation

public final class CommentaryEngine: NSObject, @unchecked Sendable, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    public var onSubtitleEmitted: (@Sendable (String) -> Void)?
    private let voice: AVSpeechSynthesisVoice?

    override public init() {
        // Prefer enhanced British English neural voices (e.g. Daniel, Arthur, Martha)
        let voices = AVSpeechSynthesisVoice.speechVoices()
        self.voice = voices.first(where: { $0.language == "en-GB" && $0.quality == .enhanced })
            ?? AVSpeechSynthesisVoice(language: "en-GB")
            ?? AVSpeechSynthesisVoice(language: "en-US")
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks a commentary line and emits synchronized subtitles
    public func speak(_ text: String, pitchMultiplier: Float = 1.05, rateMultiplier: Float = 0.52) {
        onSubtitleEmitted?(text)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.pitchMultiplier = pitchMultiplier
        utterance.rate = rateMultiplier
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.1

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
