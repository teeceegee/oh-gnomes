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
    private let fallbackVoice: AVSpeechSynthesisVoice?
    private let kokoroClient: KokoroTTSClient?
    private let audioMixer: BroadcastAudioMixer?

    private let stateLock = NSLock()
    private let dispatchQueue = DispatchQueue(label: "com.echopost.ohgnomes.commentary.dispatch", qos: .userInitiated)
    private var speechGeneration: UInt64 = 0
    private var _pendingKokoroTasks: Int = 0
    private var _selectedVoice: CommentatorVoice = .george

    public var onSubtitleEmitted: (@Sendable (String) -> Void)?

    public var selectedVoice: CommentatorVoice {
        get { stateLock.withLock { _selectedVoice } }
        set { stateLock.withLock { _selectedVoice = newValue } }
    }

    public var isUsingStudioNeuralVoice: Bool {
        return kokoroClient?.isAvailable ?? false
    }

    public init(
        mixer: BroadcastAudioMixer? = nil,
        enableKokoro: Bool = true
    ) {
        self.audioMixer = mixer
        self.kokoroClient = enableKokoro ? KokoroTTSClient(autoStart: true) : nil

        // Fallback British voice if Kokoro ONNX is unavailable on host
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let gbVoices = voices.filter { $0.language.hasPrefix("en-GB") }
        self.fallbackVoice = gbVoices.first(where: { $0.quality == .premium })
            ?? gbVoices.first(where: { $0.quality == .enhanced })
            ?? gbVoices.first(where: { $0.name.contains("Arthur") || $0.name.contains("Daniel") || $0.name.contains("Martha") })
            ?? AVSpeechSynthesisVoice(language: "en-GB")
            ?? AVSpeechSynthesisVoice(language: "en-US")

        super.init()
        synthesizer.delegate = self
    }

    deinit {
        kokoroClient?.shutdown()
    }

    /// Speaks a commentary line with studio Kokoro ONNX British neural voice (falling back to AVSpeechSynthesizer).
    public func speak(
        _ text: String,
        drama: VoiceDramaLevel = .normal,
        interrupt: Bool = true
    ) {
        if interrupt {
            stopSpeaking()
        }
        onSubtitleEmitted?(text)

        let voice = selectedVoice
        let kokoroSpeed: Double
        let fallbackPitch: Float
        let fallbackRate: Float

        switch drama {
        case .calm:
            kokoroSpeed = 0.98
            fallbackPitch = 0.98
            fallbackRate = 0.48
        case .normal:
            kokoroSpeed = 1.05
            fallbackPitch = 1.03
            fallbackRate = 0.51
        case .excited:
            kokoroSpeed = 1.13
            fallbackPitch = 1.10
            fallbackRate = 0.55
        case .chaotic:
            kokoroSpeed = 1.18
            fallbackPitch = 1.15
            fallbackRate = 0.57
        case .triumph:
            kokoroSpeed = 1.07
            fallbackPitch = 1.08
            fallbackRate = 0.50
        }

        guard let kokoro = kokoroClient, let mixer = audioMixer else {
            speakFallback(text, pitch: fallbackPitch, rate: fallbackRate)
            return
        }

        let currentGen: UInt64 = stateLock.withLock {
            _pendingKokoroTasks += 1
            return speechGeneration
        }

        dispatchQueue.async { [weak self] in
            guard let self = self else { return }
            defer {
                self.stateLock.withLock {
                    self._pendingKokoroTasks = max(0, self._pendingKokoroTasks - 1)
                }
            }

            // Skip if an interrupting line superseded this request
            let isStillValid = self.stateLock.withLock { self.speechGeneration == currentGen }
            guard isStillValid else { return }

            if let pcm = kokoro.synthesize(text: text, voice: voice, speed: kokoroSpeed) {
                let stillValidAfterSynth = self.stateLock.withLock { self.speechGeneration == currentGen }
                guard stillValidAfterSynth else { return }
                mixer.playVoicePCM(pcm, interrupt: interrupt)
            } else {
                // Graceful fallback to AVSpeechSynthesizer
                let stillValidAfterFail = self.stateLock.withLock { self.speechGeneration == currentGen }
                guard stillValidAfterFail else { return }
                self.speakFallback(text, pitch: fallbackPitch, rate: fallbackRate)
            }
        }
    }

    /// Compatibility overload for explicit pitch/rate callers
    public func speak(_ text: String, pitchMultiplier: Float, rateMultiplier: Float = 0.52, interrupt: Bool = true) {
        if interrupt {
            stopSpeaking()
        }
        onSubtitleEmitted?(text)
        speakFallback(text, pitch: pitchMultiplier, rate: rateMultiplier)
    }

    private func speakFallback(_ text: String, pitch: Float, rate: Float) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = fallbackVoice
        utterance.pitchMultiplier = pitch
        utterance.rate = rate
        utterance.preUtteranceDelay = 0.04
        utterance.postUtteranceDelay = 0.08
        synthesizer.speak(utterance)
    }

    public func stopSpeaking() {
        stateLock.withLock {
            speechGeneration &+= 1
        }
        audioMixer?.stopVoice()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    public var isSpeaking: Bool {
        let kokoroBusy = stateLock.withLock { _pendingKokoroTasks > 0 } || (audioMixer?.isVoicePlaying ?? false)
        return kokoroBusy || synthesizer.isSpeaking
    }
}
