import Foundation
import FlyingFox
import GnomesCore
import GnomesContracts

public actor WebSocketGateway: WSHandler {
    private var clientContinuations: [UUID: AsyncStream<WSFrame>.Continuation] = [:]

    public init() {}

    public func makeFrames(for client: AsyncThrowingStream<WSFrame, any Error>) async throws -> AsyncStream<WSFrame> {
        let clientId = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: WSFrame.self)
        clientContinuations[clientId] = continuation

        continuation.onTermination = { [weak self] _ in
            Task { [weak self] in
                await self?.removeClient(id: clientId)
            }
        }

        // Process incoming client frames
        Task {
            do {
                for try await frame in client {
                    if frame.opcode == .close {
                        continuation.finish()
                        break
                    }
                    // Handle client ping / message
                    if frame.opcode == .ping {
                        continuation.yield(WSFrame(fin: true, opcode: .pong, mask: nil, payload: frame.payload))
                    }
                }
            } catch {
                continuation.finish()
            }
        }

        return stream
    }

    private func removeClient(id: UUID) {
        clientContinuations.removeValue(forKey: id)
    }

    /// Broadcasts a typed ServerEnvelope to all connected WebSocket clients
    public func broadcast(envelope: ServerEnvelope) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(envelope) else { return }
        let frame = WSFrame(fin: true, opcode: .text, mask: nil, payload: data)

        for continuation in clientContinuations.values {
            continuation.yield(frame)
        }
    }

    public var connectedClientCount: Int {
        return clientContinuations.count
    }
}
