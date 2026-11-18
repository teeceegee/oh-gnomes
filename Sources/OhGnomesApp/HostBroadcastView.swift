import SwiftUI
import CoreImage.CIFilterBuiltins
import GnomesPresentation3D

public struct HostBroadcastView: View {
    @ObservedObject var viewModel: HostViewModel
    private let ciContext = CIContext()

    public init(viewModel: HostViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            // 1. Metal-Backed 3D SceneKit Garden Racetrack Broadcast
            RaceBroadcast3DView(sceneController: viewModel.broadcastScene)
                .id(ObjectIdentifier(viewModel.broadcastScene))
                .edgesIgnoringSafeArea(.all)

            // 2. HUD Overlays
            VStack {
                // Top Bar (Broadcast Header)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("OH! GNOMES")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.yellow)
                            .shadow(color: .black.opacity(0.8), radius: 3)
                        Text("Race #\(viewModel.currentRaceIndex)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    // Join Code, QR Code & URL Banner
                    HStack(spacing: 16) {
                        if let qrImage = generateQRCode(from: "http://\(viewModel.lanAddress):\(String(viewModel.serverPort))/") {
                            Image(nsImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 56, height: 56)
                                .padding(4)
                                .background(Color.white)
                                .cornerRadius(6)
                        }

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("JOIN ON YOUR PHONE")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(.white.opacity(0.7))
                            Text(verbatim: "http://\(viewModel.lanAddress):\(String(viewModel.serverPort))/")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }

                        HStack(spacing: 6) {
                            Text("CODE:")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundColor(.white.opacity(0.8))
                            Text(viewModel.joinCode)
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.red.opacity(0.85))
                                .cornerRadius(6)
                        }

                        VStack(alignment: .center, spacing: 2) {
                            Text("PLAYERS")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(.white.opacity(0.7))
                            Text("\(viewModel.connectedPlayersCount)/20")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(10)

                    Spacer()

                    // Phase Badge & Host Controls
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 8) {
                            if let secs = viewModel.bettingSecondsRemaining {
                                Text("⏱ \(secs)s")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(secs <= 10 ? Color.red : Color.orange)
                                    .cornerRadius(6)
                            }
                            Text(viewModel.currentPhaseName.uppercased())
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(6)
                        }

                        HStack(spacing: 6) {
                            Button(action: { viewModel.toggleMysteryMode() }) {
                                Text(viewModel.isMysteryMode ? "🕵️ Mystery" : "👁 Open")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.85))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button(action: { viewModel.showGrandFinale() }) {
                                Text("🏆 Finale")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.9))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button(action: { viewModel.resetSession() }) {
                                Text("↺ Reset")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.75))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isRunningRace)

                            Button(action: {
                                viewModel.advancePhase()
                            }) {
                                Text(buttonLabelForPhase)
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isRunningRace)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Grand Finale Leaderboard Reveal Overlay
                if let standings = viewModel.finaleStandings {
                    VStack(spacing: 12) {
                        HStack {
                            Text("🏆 GRAND FINALE STANDINGS")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(.yellow)
                            Spacer()
                            Button("Close ✕") {
                                viewModel.finaleStandings = nil
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.white.opacity(0.8))
                        }
                        if standings.isEmpty {
                            Text("No players joined yet.")
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            ForEach(Array(standings.enumerated()), id: \.element.id) { idx, p in
                                HStack {
                                    Text(idx == 0 ? "🥇" : idx == 1 ? "🥈" : idx == 2 ? "🥉" : "#\(idx + 1)")
                                        .font(.system(size: 20, weight: .bold))
                                        .frame(width: 36)
                                    Text("\(p.gem.iconSymbol) \(p.displayName)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(String(format: "£%.2f", Double(p.balancePennies) / 100.0))
                                        .font(.system(size: 18, weight: .black, design: .monospaced))
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(idx == 0 ? 0.14 : 0.06))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 580)
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yellow.opacity(0.6), lineWidth: 2))
                    .shadow(radius: 20)
                } else if !viewModel.lastRacePodium.isEmpty {
                    // Post-Race Podium Card
                    VStack(spacing: 8) {
                        Text("🏁 OFFICIAL PODIUM — RACE #\(viewModel.currentRaceIndex)")
                            .font(.system(size: 15, weight: .black))
                            .foregroundColor(.yellow)
                        HStack(spacing: 16) {
                            ForEach(Array(viewModel.lastRacePodium.enumerated()), id: \.element.gnomeId) { idx, r in
                                VStack(spacing: 4) {
                                    Text(idx == 0 ? "🥇 1st" : idx == 1 ? "🥈 2nd" : "🥉 3rd")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(idx == 0 ? .yellow : .white)
                                    Text(r.gnomeName)
                                        .font(.system(size: 15, weight: .heavy))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }

                Spacer()

                // Multi-Camera Angle Switcher Bar
                HStack(spacing: 8) {
                    Text("📷 CAM:")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white.opacity(0.8))
                    ForEach(BroadcastCameraAngle.allCases, id: \.self) { angle in
                        Button(action: { viewModel.setCameraAngle(angle) }) {
                            Text(angle.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(viewModel.selectedCameraAngle == angle ? Color.blue : Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.55))
                .cornerRadius(10)

                // Live Synchronized Commentary Subtitle
                HStack {
                    Text(viewModel.subtitleText)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(12)
                        .shadow(radius: 6)
                }
                .padding(.bottom, 24)
            }
        }
        .frame(minWidth: 1280, minHeight: 720)
        .onAppear {
            viewModel.start()
        }
    }

    private var buttonLabelForPhase: String {
        switch viewModel.currentPhaseName {
        case "Preparing":
            return "Start Introduction ▶"
        case "Introduction":
            return "Open Betting 💷"
        case "Betting Open":
            return "Close Betting & Lock 🔒"
        case "Betting Closed":
            return "Start Race! 🏁"
        default:
            return "Next Race ▶▶"
        }
    }

    private func generateQRCode(from string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 6, y: 6))
        guard let cgImage = ciContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
