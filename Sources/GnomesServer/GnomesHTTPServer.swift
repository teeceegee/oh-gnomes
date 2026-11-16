import Foundation
import FlyingFox
import GnomesCore
import GnomesContracts
import GnomesEconomy
import GnomesSimulation

public final class GnomesHTTPServer: @unchecked Sendable {
    public let port: UInt16
    public let sessionManager: SessionManager
    public let wsGateway: WebSocketGateway
    private var server: HTTPServer?
    private var serverTask: Task<Void, Error>?

    public static func resolveDefaultPort() -> UInt16 {
        if let envPort = ProcessInfo.processInfo.environment["OH_GNOMES_PORT"],
           let parsed = UInt16(envPort) {
            return parsed
        }
        return 8778
    }

    public init(
        port: UInt16 = resolveDefaultPort(),
        sessionManager: SessionManager,
        wsGateway: WebSocketGateway = WebSocketGateway()
    ) {
        self.port = port
        self.sessionManager = sessionManager
        self.wsGateway = wsGateway
    }

    public func start() async throws {
        let server = HTTPServer(port: port)
        self.server = server

        // 1. WebSocket upgrade route
        await server.appendRoute("/ws", for: [.GET], to: WebSocketHTTPHandler(handler: wsGateway))

        // 2. Health check route
        await server.appendRoute("/health", for: [.GET]) { [weak self] _ in
            guard let self = self else {
                return HTTPResponse(statusCode: .internalServerError)
            }
            let playerCount = await self.sessionManager.players.count
            let phase = await self.sessionManager.session.phase.rawValue
            let raceIdx = await self.sessionManager.session.currentRaceIndex
            let wsCount = await self.wsGateway.connectedClientCount

            let json = """
            {"status":"ok","port":\(self.port),"phase":"\(phase)","raceIndex":\(raceIdx),"players":\(playerCount),"wsClients":\(wsCount)}
            """
            return HTTPResponse(statusCode: .ok, headers: [.contentType: "application/json"], body: Data(json.utf8))
        }

        // 3. Session info route
        await server.appendRoute("/api/session", for: [.GET]) { [weak self] _ in
            guard let self = self else { return HTTPResponse(statusCode: .internalServerError) }
            let session = await self.sessionManager.session
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(session) else {
                return HTTPResponse(statusCode: .internalServerError)
            }
            return HTTPResponse(statusCode: .ok, headers: [.contentType: "application/json"], body: data)
        }

        // 4. Player Join route
        await server.appendRoute("/api/player/join", for: [.POST]) { [weak self] request in
            guard let self = self else { return HTTPResponse(statusCode: .internalServerError) }
            do {
                let bodyData = try await request.bodyData
                let decoder = JSONDecoder()
                let joinReq = try decoder.decode(JoinRequest.self, from: bodyData)
                let clientHash = request.headers[HTTPHeader("X-Device-Hash")] ?? UUID().uuidString

                let payload = try await self.sessionManager.join(request: joinReq, credentialHash: clientHash)
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(payload)
                return HTTPResponse(statusCode: .ok, headers: [.contentType: "application/json"], body: data)
            } catch let error as SessionError {
                let errorMsg = "{\"error\":\"\(error)\"}"
                return HTTPResponse(statusCode: .badRequest, headers: [.contentType: "application/json"], body: Data(errorMsg.utf8))
            } catch {
                return HTTPResponse(statusCode: .badRequest, headers: [.contentType: "application/json"], body: Data("{\"error\":\"Invalid request\"}".utf8))
            }
        }

        // 5. Player Reconnect route
        await server.appendRoute("/api/player/reconnect", for: [.POST]) { [weak self] request in
            guard let self = self else { return HTTPResponse(statusCode: .internalServerError) }
            do {
                let bodyData = try await request.bodyData
                let decoder = JSONDecoder()
                let recReq = try decoder.decode(ReconnectRequest.self, from: bodyData)
                if let payload = await self.sessionManager.reconnect(request: recReq) {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    let data = try encoder.encode(payload)
                    return HTTPResponse(statusCode: .ok, headers: [.contentType: "application/json"], body: data)
                } else {
                    return HTTPResponse(statusCode: .unauthorized, headers: [.contentType: "application/json"], body: Data("{\"error\":\"Invalid credentials\"}".utf8))
                }
            } catch {
                return HTTPResponse(statusCode: .badRequest, headers: [.contentType: "application/json"], body: Data("{\"error\":\"Bad request\"}".utf8))
            }
        }

        // 6. Place Bet route
        await server.appendRoute("/api/player/bet", for: [.POST]) { [weak self] request in
            guard let self = self else { return HTTPResponse(statusCode: .internalServerError) }
            do {
                let playerId = request.headers[HTTPHeader("X-Player-ID")] ?? ""
                guard !playerId.isEmpty else {
                    return HTTPResponse(statusCode: .unauthorized, body: Data("{\"error\":\"Missing X-Player-ID\"}".utf8))
                }
                let bodyData = try await request.bodyData
                let decoder = JSONDecoder()
                let betReq = try decoder.decode(PlaceBetRequest.self, from: bodyData)
                let ticket = try await self.sessionManager.placeBet(request: betReq, playerId: playerId)

                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(ticket)
                return HTTPResponse(statusCode: .ok, headers: [.contentType: "application/json"], body: data)
            } catch {
                return HTTPResponse(statusCode: .badRequest, body: Data("{\"error\":\"\(error)\"}".utf8))
            }
        }

        // 7. Standings route (enforcing Mystery Mode projection filtering)
        await server.appendRoute("/api/standings", for: [.GET]) { [weak self] request in
            guard let self = self else { return HTTPResponse(statusCode: .internalServerError) }
            let roleStr = request.headers[HTTPHeader("X-Client-Role")] ?? "phonePlayer"
            let role = ClientRole(rawValue: roleStr) ?? .phonePlayer
            let projection = await self.sessionManager.getStandingsProjection(forRole: role)

            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(projection) else {
                return HTTPResponse(statusCode: .internalServerError)
            }
            return HTTPResponse(statusCode: .ok, headers: [.contentType: "application/json"], body: data)
        }

        // 8. Current Race View route for mobile phone controllers
        await server.appendRoute("/api/race/current", for: [.GET]) { [weak self] request in
            guard let self = self else { return HTTPResponse(statusCode: .internalServerError) }
            let playerId = request.headers[HTTPHeader("X-Player-ID")] ?? ""
            if let view = await self.sessionManager.getCurrentRaceView(forPlayerId: playerId) {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                guard let data = try? encoder.encode(view) else {
                    return HTTPResponse(statusCode: .internalServerError)
                }
                return HTTPResponse(statusCode: .ok, headers: [.contentType: "application/json"], body: data)
            } else {
                return HTTPResponse(statusCode: .notFound, headers: [.contentType: "application/json"], body: Data("{\"error\":\"No active race\"}".utf8))
            }
        }

        // 9. Root Web Controller HTML
        await server.appendRoute("/", for: [.GET]) { _ in
            let candidates: [URL?] = [
                Bundle.main.resourceURL?.appendingPathComponent("WebController/index.html"),
                ProcessInfo.processInfo.environment["OH_GNOMES_WEB_DIR"].map {
                    URL(fileURLWithPath: $0).appendingPathComponent("index.html")
                },
                URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent("WebController/index.html")
            ]

            for case let url? in candidates {
                if FileManager.default.fileExists(atPath: url.path),
                   let fileData = try? Data(contentsOf: url) {
                    return HTTPResponse(statusCode: .ok, headers: [.contentType: "text/html; charset=utf-8"], body: fileData)
                }
            }

            let html = """
            <!DOCTYPE html>
            <html lang="en">
            <head><title>Oh! Gnomes</title></head>
            <body><h1>Oh! Gnomes Mobile Controller</h1><p>WebController/index.html could not be located.</p></body>
            </html>
            """
            return HTTPResponse(statusCode: .ok, headers: [.contentType: "text/html; charset=utf-8"], body: Data(html.utf8))
        }

        // Start listening asynchronously
        self.serverTask = Task {
            try await server.run()
        }
    }

    public func stop() async {
        serverTask?.cancel()
        serverTask = nil
        await server?.stop()
        server = nil
    }
}
