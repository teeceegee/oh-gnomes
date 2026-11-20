import Foundation
import AVFoundation

/// Multi-bus broadcast audio mixer hosting Kokoro neural commentary,
/// looping stadium crowd ambience, ducking race-day background music, and sound FX.
public final class BroadcastAudioMixer: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let voicePlayer = AVAudioPlayerNode()
    private let musicPlayer = AVAudioPlayerNode()
    private let crowdPlayer = AVAudioPlayerNode()
    private let fxPlayer = AVAudioPlayerNode()

    private let voiceFormat: AVAudioFormat
    private let fxFormat: AVAudioFormat

    private let stateLock = NSLock()
    private var _isAmbienceEnabled: Bool = true
    private var _isRacing: Bool = false
    private var _isDucked: Bool = false
    private var _isEngineStarted: Bool = false
    private var _activeVoiceBuffers: Int = 0

    public var isAmbienceEnabled: Bool {
        stateLock.withLock { _isAmbienceEnabled }
    }

    public var isVoicePlaying: Bool {
        stateLock.withLock { _activeVoiceBuffers > 0 }
    }

    public init() {
        self.voiceFormat = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!
        self.fxFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

        engine.attach(voicePlayer)
        engine.attach(musicPlayer)
        engine.attach(crowdPlayer)
        engine.attach(fxPlayer)

        engine.connect(voicePlayer, to: engine.mainMixerNode, format: voiceFormat)
        engine.connect(musicPlayer, to: engine.mainMixerNode, format: fxFormat)
        engine.connect(crowdPlayer, to: engine.mainMixerNode, format: fxFormat)
        engine.connect(fxPlayer, to: engine.mainMixerNode, format: fxFormat)

        voicePlayer.volume = 1.0
        fxPlayer.volume = 0.85
        applyBusVolumesLocked()
    }

    public func startIfNeeded() {
        stateLock.withLock {
            guard !_isEngineStarted else { return }
            do {
                try engine.start()
                _isEngineStarted = true
                startAmbientLoopsLocked()
            } catch {
                // Headless or audio-unavailable CI environment
            }
        }
    }

    private func startAmbientLoopsLocked() {
        if let musicBuf = synthesizeRaceDayMusicLoop() {
            musicPlayer.scheduleBuffer(musicBuf, at: nil, options: .loops)
            musicPlayer.play()
        }
        if let crowdBuf = synthesizeCrowdMurmurLoop() {
            crowdPlayer.scheduleBuffer(crowdBuf, at: nil, options: .loops)
            crowdPlayer.play()
        }
        applyBusVolumesLocked()
    }

    public func setAmbienceEnabled(_ enabled: Bool) {
        stateLock.withLock {
            _isAmbienceEnabled = enabled
            applyBusVolumesLocked()
        }
    }

    public func setRaceIntensity(_ isRacing: Bool) {
        stateLock.withLock {
            _isRacing = isRacing
            applyBusVolumesLocked()
        }
    }

    public func setCommentaryDucking(_ ducked: Bool) {
        stateLock.withLock {
            _isDucked = ducked
            applyBusVolumesLocked()
        }
    }

    private func applyBusVolumesLocked() {
        guard _isAmbienceEnabled else {
            musicPlayer.volume = 0.0
            crowdPlayer.volume = 0.0
            return
        }
        let baseMusic: Float = _isRacing ? 0.14 : 0.20
        let baseCrowd: Float = _isRacing ? 0.22 : 0.09
        let duckScale: Float = _isDucked ? 0.28 : 1.0

        musicPlayer.volume = baseMusic * duckScale
        crowdPlayer.volume = baseCrowd * duckScale
    }

    /// Plays a 24kHz Float32 Kokoro PCM voice buffer with automatic music/crowd ducking.
    public func playVoicePCM(_ pcm: KokoroPCMResult, interrupt: Bool, onComplete: (@Sendable () -> Void)? = nil) {
        startIfNeeded()
        guard !pcm.samples.isEmpty else {
            onComplete?()
            return
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: pcm.sampleRate, channels: 1) ?? voiceFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(pcm.samples.count)) else {
            onComplete?()
            return
        }
        buffer.frameLength = AVAudioFrameCount(pcm.samples.count)
        if let channel = buffer.floatChannelData?[0] {
            pcm.samples.withUnsafeBufferPointer { src in
                if let base = src.baseAddress {
                    channel.update(from: base, count: pcm.samples.count)
                }
            }
        }

        if interrupt {
            stopVoice()
        }

        stateLock.withLock {
            _activeVoiceBuffers += 1
            _isDucked = true
            applyBusVolumesLocked()
        }

        voicePlayer.scheduleBuffer(buffer) { [weak self] in
            guard let self = self else { return }
            self.stateLock.withLock {
                self._activeVoiceBuffers = max(0, self._activeVoiceBuffers - 1)
                if self._activeVoiceBuffers == 0 {
                    self._isDucked = false
                    self.applyBusVolumesLocked()
                }
            }
            onComplete?()
        }

        if !voicePlayer.isPlaying {
            voicePlayer.play()
        }
    }

    public func stopVoice() {
        voicePlayer.stop()
        stateLock.withLock {
            _activeVoiceBuffers = 0
            _isDucked = false
            applyBusVolumesLocked()
        }
    }

    /// Schedules a 44.1kHz sound FX buffer on the FX bus.
    public func playFXBuffer(_ buffer: AVAudioPCMBuffer) {
        startIfNeeded()
        fxPlayer.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !fxPlayer.isPlaying {
            fxPlayer.play()
        }
    }

    // MARK: - Procedural Broadcast Loops (Generated Once at Startup)

    /// Generates an upbeat 8-second garden derby brass/marimba chord loop.
    private func synthesizeRaceDayMusicLoop() -> AVAudioPCMBuffer? {
        let sr = 44_100.0
        let duration = 8.0
        let frameCount = Int(sr * duration)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fxFormat, frameCapacity: AVAudioFrameCount(frameCount)),
              let ch = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = AVAudioFrameCount(frameCount)

        // Bright major British country-fair chord sequence (C - G - Am - F - C - G - F - G)
        let chords: [[Double]] = [
            [261.63, 329.63, 392.00], // C
            [293.66, 392.00, 493.88], // G
            [220.00, 261.63, 329.63], // Am
            [261.63, 349.23, 440.00], // F
            [261.63, 329.63, 392.00], // C
            [293.66, 392.00, 493.88], // G
            [261.63, 349.23, 440.00], // F
            [293.66, 392.00, 493.88]  // G
        ]
        let bassNotes: [Double] = [130.81, 196.00, 110.00, 174.61, 130.81, 196.00, 174.61, 196.00]

        let twoPi = 2.0 * Double.pi
        for i in 0..<frameCount {
            let t = Double(i) / sr
            let barIdx = min(7, Int(t))
            let beatFrac = t - floor(t)
            let subBeat = (t * 2.0) - floor(t * 2.0)

            let chordEnv = exp(-subBeat * 5.5)
            let bassEnv = exp(-beatFrac * 3.8)

            var sample = sin(twoPi * bassNotes[barIdx] * t) * bassEnv * 0.22
            for freq in chords[barIdx] {
                sample += sin(twoPi * freq * t) * chordEnv * 0.11
            }
            ch[i] = Float(sample)
        }
        return buf
    }

    /// Generates a warm 4-second seamless stadium crowd murmur (band-filtered pink noise).
    private func synthesizeCrowdMurmurLoop() -> AVAudioPCMBuffer? {
        let sr = 44_100.0
        let duration = 4.0
        let frameCount = Int(sr * duration)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fxFormat, frameCapacity: AVAudioFrameCount(frameCount)),
              let ch = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = AVAudioFrameCount(frameCount)

        // Simple deterministic pink-ish low-pass filtered noise with smooth crossfade at loop seam
        var b0 = 0.0, b1 = 0.0, b2 = 0.0
        var state: UInt64 = 0x5EED_C0DE_1234
        for i in 0..<frameCount {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let white = (Double(Int64(bitPattern: state)) / Double(Int64.max))
            b0 = 0.997 * b0 + white * 0.03
            b1 = 0.985 * b1 + white * 0.04
            b2 = 0.950 * b2 + white * 0.05
            let t = Double(i) / sr
            let swell = 0.78 + 0.22 * sin(2.0 * Double.pi * t / duration)
            ch[i] = Float((b0 + b1 + b2) * 0.35 * swell)
        }
        return buf
    }
}
