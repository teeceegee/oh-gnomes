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

        // 8. Root Web Controller HTML
        await server.appendRoute("/", for: [.GET]) { _ in
            let html = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                <title>Oh! Gnomes — Player Controller</title>
                <style>
                    body { font-family: system-ui, -apple-system, sans-serif; background: #1a1a24; color: #fff; margin: 0; padding: 20px; text-align: center; }
                    .badge { display: inline-block; padding: 6px 12px; border-radius: 9999px; background: #3b82f6; font-weight: bold; margin-bottom: 12px; }
                    h1 { margin: 10px 0; font-size: 28px; }
                    .card { background: #262636; border-radius: 12px; padding: 20px; margin: 20px auto; max-width: 400px; box-shadow: 0 4px 20px rgba(0,0,0,0.5); }
                    input, button { width: 100%; box-sizing: border-box; padding: 14px; border-radius: 8px; border: none; margin: 8px 0; font-size: 16px; }
                    input { background: #121218; color: #fff; border: 1px solid #444; }
                    button { background: #10b981; color: #fff; font-weight: bold; cursor: pointer; transition: background 0.2s; }
                    button:hover { background: #059669; }
                </style>
            </head>
            <body>
                <div class="card">
                    <div class="badge">Oh! Gnomes</div>
                    <h1>Join Race Night</h1>
                    <p style="color: #9ca3af; font-size: 14px;">Enter your room code and display name to join the race.</p>
                    <input type="text" id="joinCode" placeholder="Room Code (e.g. GNOM)" uppercase style="text-transform:uppercase;">
                    <input type="text" id="displayName" placeholder="Your Name">
                    <button id="joinBtn" onclick="handleJoin()">Join Game</button>
                    <div id="status" style="margin-top: 15px; font-weight: bold;"></div>
                </div>
                <script>
                    async function handleJoin() {
                        const code = document.getElementById('joinCode').value.trim();
                        const name = document.getElementById('displayName').value.trim();
                        const status = document.getElementById('status');
                        if (!code || !name) { status.innerText = 'Please enter room code and name.'; status.style.color = '#ef4444'; return; }
                        status.innerText = 'Connecting...'; status.style.color = '#3b82f6';
                        try {
                            const res = await fetch('/api/player/join', {
                                method: 'POST',
                                headers: {'Content-Type':'application/json'},
                                body: JSON.stringify({joinCode: code, displayName: name, clientNonce: crypto.randomUUID()})
                            });
                            const data = await res.json();
                            if (res.ok) {
                                status.innerText = `Joined as ${data.displayName}! Gem: ${data.gem.name}`;
                                status.style.color = '#10b981';
                            } else {
                                status.innerText = data.error || 'Failed to join'; status.style.color = '#ef4444';
                            }
                        } catch (e) {
                            status.innerText = 'Connection error: ' + e.message; status.style.color = '#ef4444';
                        }
                    }
                </script>
            </body>
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
