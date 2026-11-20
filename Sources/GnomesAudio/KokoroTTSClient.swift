import Foundation

public enum CommentatorVoice: String, CaseIterable, Sendable {
    case george = "bm_george"
    case daniel = "bm_daniel"
    case lewis = "bm_lewis"
    case fable = "bm_fable"
    case emma = "bf_emma"
    case alice = "bf_alice"

    public var displayName: String {
        switch self {
        case .george: return "George (BBC)"
        case .daniel: return "Daniel (UK)"
        case .lewis: return "Lewis (Warm)"
        case .fable: return "Fable (Drama)"
        case .emma: return "Emma (UK)"
        case .alice: return "Alice (UK)"
        }
    }
}

public struct KokoroPCMResult: Sendable {
    public let sampleRate: Double
    public let samples: [Float]
}

/// Manages a persistent warm Kokoro v1.0 ONNX worker process over stdin/stdout binary PCM pipes.
public final class KokoroTTSClient: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.echopost.ohgnomes.kokoro", qos: .userInitiated)
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var _isReady: Bool = false

    public var isAvailable: Bool {
        return queue.sync { _isReady && (process?.isRunning ?? false) }
    }

    public init(autoStart: Bool = true) {
        if autoStart {
            queue.async { [weak self] in
                self?.startWorkerLocked()
            }
        }
    }

    deinit {
        shutdown()
    }

    public func shutdown() {
        queue.sync {
            if let p = process, p.isRunning {
                p.terminate()
            }
            process = nil
            stdinHandle = nil
            stdoutHandle = nil
            _isReady = false
        }
    }

    private func resolvePythonPath() -> String? {
        let candidates: [String?] = [
            ProcessInfo.processInfo.environment["OH_GNOMES_KOKORO_PYTHON"],
            NSString(string: "~/.zen/venv/bin/python3").expandingTildeInPath,
            NSString(string: "~/Zen/.venv/bin/python3").expandingTildeInPath
        ]
        for case let path? in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    private func resolveWorkerScriptPath() -> String? {
        let candidates: [String?] = [
            Bundle.main.resourceURL?.appendingPathComponent("scripts/kokoro_worker.py").path,
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("scripts/kokoro_worker.py").path
        ]
        for case let path? in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    private func resolveModelDir() -> String? {
        let dir = ProcessInfo.processInfo.environment["OH_GNOMES_KOKORO_DIR"]
            ?? NSString(string: "~/.zen/models/kokoro").expandingTildeInPath
        let modelPath = (dir as NSString).appendingPathComponent("kokoro-v1.0.onnx")
        let voicesPath = (dir as NSString).appendingPathComponent("voices-v1.0.bin")
        if FileManager.default.fileExists(atPath: modelPath),
           FileManager.default.fileExists(atPath: voicesPath) {
            return dir
        }
        return nil
    }

    private func startWorkerLocked() {
        guard process == nil else { return }
        guard let pythonPath = resolvePythonPath(),
              let scriptPath = resolveWorkerScriptPath(),
              let modelDir = resolveModelDir() else {
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = [scriptPath]
        var env = ProcessInfo.processInfo.environment
        env["OH_GNOMES_KOKORO_DIR"] = modelDir
        env["ONNX_PROVIDER"] = "CPUExecutionProvider"
        env["PYTHONUNBUFFERED"] = "1"
        proc.environment = env

        let inPipe = Pipe()
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        do {
            try proc.run()
        } catch {
            return
        }

        // Wait for single-line "READY\n" on stderr
        var readyBuffer = Data()
        while proc.isRunning {
            let chunk = errPipe.fileHandleForReading.availableData
            if chunk.isEmpty { break }
            readyBuffer.append(chunk)
            if let str = String(data: readyBuffer, encoding: .utf8), str.contains("READY") {
                self.process = proc
                self.stdinHandle = inPipe.fileHandleForWriting
                self.stdoutHandle = outPipe.fileHandleForReading
                self._isReady = true
                return
            }
            if readyBuffer.count > 4096 { break }
        }

        proc.terminate()
    }

    /// Synthesizes text into raw Float32 PCM in memory via the warm Kokoro ONNX worker.
    public func synthesize(text: String, voice: CommentatorVoice = .george, speed: Double = 1.06) -> KokoroPCMResult? {
        return queue.sync {
            if !_isReady {
                startWorkerLocked()
            }
            guard _isReady,
                  let proc = process, proc.isRunning,
                  let stdin = stdinHandle,
                  let stdout = stdoutHandle else {
                return nil
            }

            let payload: [String: Any] = [
                "text": text,
                "voice": voice.rawValue,
                "speed": speed,
                "lang": "en-gb"
            ]
            guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
                  var lineData = String(data: jsonData, encoding: .utf8)?.data(using: .utf8) else {
                return nil
            }
            lineData.append(0x0A) // newline

            do {
                try stdin.write(contentsOf: lineData)
            } catch {
                _isReady = false
                return nil
            }

            guard let header = readExact(from: stdout, byteCount: 8), header.count == 8 else {
                _isReady = false
                return nil
            }

            let sampleRate = header.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
            let byteLength = header.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }

            guard sampleRate > 0, byteLength > 0, byteLength < 50_000_000 else {
                return nil
            }

            guard let pcmData = readExact(from: stdout, byteCount: Int(byteLength)),
                  pcmData.count == Int(byteLength) else {
                _isReady = false
                return nil
            }

            let sampleCount = pcmData.count / MemoryLayout<Float>.size
            var samples = [Float](repeating: 0, count: sampleCount)
            _ = samples.withUnsafeMutableBytes { dest in
                pcmData.copyBytes(to: dest)
            }
            return KokoroPCMResult(sampleRate: Double(sampleRate), samples: samples)
        }
    }

    private func readExact(from handle: FileHandle, byteCount: Int) -> Data? {
        var collected = Data()
        collected.reserveCapacity(byteCount)
        while collected.count < byteCount {
            let remaining = byteCount - collected.count
            guard let chunk = try? handle.read(upToCount: remaining), !chunk.isEmpty else {
                return nil
            }
            collected.append(chunk)
        }
        return collected
    }
}
