import Testing
import Foundation
@testable import GnomesCore
@testable import GnomesSimulation
@testable import GnomesAudio

@Suite("GnomesAudio Tests")
struct GnomesAudioTests {

    private final class SubtitleCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var _value: String?
        var value: String? {
            get { lock.withLock { _value } }
            set { lock.withLock { _value = newValue } }
        }
    }

    @Test("Commentary Engine Initialization & Subtitle Callback")
    func testCommentaryEngineSubtitles() {
        let engine = CommentaryEngine(enableKokoro: false)
        let collector = SubtitleCollector()

        engine.onSubtitleEmitted = { text in
            collector.value = text
        }

        engine.speak("And they're off down the garden trail!")
        #expect(collector.value == "And they're off down the garden trail!")
        engine.stopSpeaking()
    }

    @Test("Procedural Commentary Generation Cues")
    func testProceduralCommentaryCues() {
        let generator = ProceduralCommentaryGenerator()

        let start = generator.commentaryForStart(courseName: "Garden Grand Prix", entrantsCount: 8)
        #expect(!start.isEmpty)
        #expect(start.contains("gnomes") || start.contains("off") || start.contains("Garden Grand Prix"))

        let stumble = generator.commentaryForIncident(runnerName: "Barnaby", incidentType: .stumble, reason: "slipped")
        #expect(stumble.contains("Barnaby"))
        #expect(stumble.contains("stumble") || stumble.contains("Disaster") || stumble.contains("footing"))

        let launch = generator.commentaryForIncident(runnerName: "Gimlet", incidentType: .airborneLaunch, reason: "spring launcher")
        #expect(launch.contains("Gimlet"))
        #expect(launch.contains("spring launcher") || launch.contains("skies") || launch.contains("soaring") || launch.contains("air"))

        let finish = generator.commentaryForWinner(winnerName: "Eldred Oakfoot")
        #expect(finish.contains("Eldred Oakfoot"))
    }

    @Test("Audio FX Synthesizer & Multi-Bus BroadcastAudioMixer (EVD-320)")
    func testAudioFXSynthesizer() {
        let mixer = BroadcastAudioMixer()
        mixer.setAmbienceEnabled(true)
        #expect(mixer.isAmbienceEnabled)
        mixer.setRaceIntensity(true)
        mixer.setCommentaryDucking(true)
        mixer.setCommentaryDucking(false)
        mixer.setAmbienceEnabled(false)
        #expect(!mixer.isAmbienceEnabled)

        let fx = AudioFXSynthesizer(mixer: mixer)
        fx.playEffect(.startingGun)
        fx.playEffect(.raceBell)
        fx.playEffect(.trumpetFanfare)
        fx.playEffect(.mudSquelch)
        fx.playEffect(.springBoing)
        fx.playEffect(.crowdCheer)
        fx.playEffect(.victoryCelebration)
    }

    @Test("Kokoro v1.0 ONNX Persistent Worker 24kHz PCM Synthesis (EVD-318, EVD-319)")
    func testKokoroONNXSynthesis() {
        let client = KokoroTTSClient(autoStart: false)
        defer { client.shutdown() }
        if let result = client.synthesize(text: "And they are off!", voice: .george, speed: 1.08) {
            #expect(result.sampleRate == 24_000.0)
            #expect(result.samples.count > 10_000)
        }
    }
}
