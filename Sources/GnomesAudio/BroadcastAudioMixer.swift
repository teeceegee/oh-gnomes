import Foundation
import AVFoundation

/// Multi-bus broadcast audio mixer hosting Kokoro neural commentary,
/// looping stadium crowd ambience, ducking race-day background music, and sound FX.
///
/// All AVAudioEngine / AVAudioPlayerNode operations are strictly serialized onto `audioQueue`
/// via async dispatch so the Main Thread and AVFAudio's internal completion queue can never deadlock.
public final class BroadcastAudioMixer: @unchecked Sendable {
    private let audioQueue = DispatchQueue(label: "com.echopost.ohgnomes.audio.mixer", qos: .userInteractive)
    private let stateLock = NSLock()

    private let engine = AVAudioEngine()
    private let voicePlayer = AVAudioPlayerNode()
    private let musicPlayer = AVAudioPlayerNode()
    private let crowdPlayer = AVAudioPlayerNode()
    private let fxPlayer = AVAudioPlayerNode()

    private let voiceFormat: AVAudioFormat
    private let fxFormat: AVAudioFormat

    private var _isAmbienceEnabled: Bool = true
    private var _isRacing: Bool = false
    private var _isDucked: Bool = false
    private var _isEngineStarted: Bool = false
    private var _activeVoiceBuffers: Int = 0
    private var _voiceGeneration: UInt64 = 0

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
        applyBusVolumesOnAudioQueue()
    }

    public func startIfNeeded() {
        audioQueue.async { [weak self] in
            self?.startIfNeededOnAudioQueue()
        }
    }

    private func startIfNeededOnAudioQueue() {
        guard !_isEngineStarted else { return }
        do {
            try engine.start()
            _isEngineStarted = true
            startAmbientLoopsOnAudioQueue()
        } catch {
            // Headless or audio-unavailable environment
        }
    }

    private func startAmbientLoopsOnAudioQueue() {
        if let musicBuf = synthesizeRaceDayMusicLoop() {
            musicPlayer.scheduleBuffer(musicBuf, at: nil, options: .loops)
            musicPlayer.play()
        }
        if let crowdBuf = synthesizeCrowdMurmurLoop() {
            crowdPlayer.scheduleBuffer(crowdBuf, at: nil, options: .loops)
            crowdPlayer.play()
        }
        applyBusVolumesOnAudioQueue()
    }

    public func setAmbienceEnabled(_ enabled: Bool) {
        stateLock.withLock { _isAmbienceEnabled = enabled }
        audioQueue.async { [weak self] in
            self?.applyBusVolumesOnAudioQueue()
        }
    }

    public func setRaceIntensity(_ isRacing: Bool) {
        stateLock.withLock { _isRacing = isRacing }
        audioQueue.async { [weak self] in
            self?.applyBusVolumesOnAudioQueue()
        }
    }

    public func setCommentaryDucking(_ ducked: Bool) {
        stateLock.withLock { _isDucked = ducked }
        audioQueue.async { [weak self] in
            self?.applyBusVolumesOnAudioQueue()
        }
    }

    private func applyBusVolumesOnAudioQueue() {
        let (enabled, racing, ducked) = stateLock.withLock {
            (_isAmbienceEnabled, _isRacing, _isDucked)
        }
        guard enabled else {
            musicPlayer.volume = 0.0
            crowdPlayer.volume = 0.0
            return
        }
        let baseMusic: Float = racing ? 0.14 : 0.20
        let baseCrowd: Float = racing ? 0.22 : 0.09
        let duckScale: Float = ducked ? 0.28 : 1.0

        musicPlayer.volume = baseMusic * duckScale
        crowdPlayer.volume = baseCrowd * duckScale
    }

    /// Plays a 24kHz Float32 Kokoro PCM voice buffer with automatic music/crowd ducking.
    public func playVoicePCM(_ pcm: KokoroPCMResult, interrupt: Bool, onComplete: (@Sendable () -> Void)? = nil) {
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

        audioQueue.async { [weak self] in
            guard let self = self else { return }
            self.startIfNeededOnAudioQueue()

            if interrupt {
                self.stopVoiceOnAudioQueue()
            }

            let gen: UInt64 = self.stateLock.withLock {
                self._activeVoiceBuffers += 1
                self._isDucked = true
                return self._voiceGeneration
            }
            self.applyBusVolumesOnAudioQueue()

            // IMPORTANT: Completion callback runs on AVFAudio's internal caulk queue.
            // Never acquire locks or touch AVAudioNodes synchronously inside it — hop to audioQueue.async!
            self.voicePlayer.scheduleBuffer(buffer) { [weak self] in
                guard let self = self else { return }
                self.audioQueue.async {
                    let shouldUnduck = self.stateLock.withLock { () -> Bool in
                        guard self._voiceGeneration == gen else { return false }
                        self._activeVoiceBuffers = max(0, self._activeVoiceBuffers - 1)
                        if self._activeVoiceBuffers == 0 {
                            self._isDucked = false
                            return true
                        }
                        return false
                    }
                    if shouldUnduck {
                        self.applyBusVolumesOnAudioQueue()
                    }
                    onComplete?()
                }
            }

            if !self.voicePlayer.isPlaying {
                self.voicePlayer.play()
            }
        }
    }

    /// Non-blocking stop so callers on @MainActor never block waiting on AVFAudio.
    public func stopVoice() {
        audioQueue.async { [weak self] in
            self?.stopVoiceOnAudioQueue()
        }
    }

    private func stopVoiceOnAudioQueue() {
        stateLock.withLock {
            _voiceGeneration &+= 1
            _activeVoiceBuffers = 0
            _isDucked = false
        }
        if voicePlayer.isPlaying {
            voicePlayer.stop()
        }
        applyBusVolumesOnAudioQueue()
    }

    /// Schedules a 44.1kHz sound FX buffer on the FX bus.
    public func playFXBuffer(_ buffer: AVAudioPCMBuffer) {
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            self.startIfNeededOnAudioQueue()
            self.fxPlayer.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            if !self.fxPlayer.isPlaying {
                self.fxPlayer.play()
            }
        }
    }

    // MARK: - Procedural Broadcast Loops (Generated Once at Startup)

    private func synthesizeRaceDayMusicLoop() -> AVAudioPCMBuffer? {
        let sr = 44_100.0
        let duration = 8.0
        let frameCount = Int(sr * duration)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fxFormat, frameCapacity: AVAudioFrameCount(frameCount)),
              let ch = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = AVAudioFrameCount(frameCount)

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

    private func synthesizeCrowdMurmurLoop() -> AVAudioPCMBuffer? {
        let sr = 44_100.0
        let duration = 4.0
        let frameCount = Int(sr * duration)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fxFormat, frameCapacity: AVAudioFrameCount(frameCount)),
              let ch = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = AVAudioFrameCount(frameCount)

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
