import SwiftUI
import SpriteKit
import GnomesPresentation

public struct HostBroadcastView: View {
    @ObservedObject var viewModel: HostViewModel

    public init(viewModel: HostViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            // 1. SpriteKit 1080p Metal Racetrack Scene
            SpriteView(
                scene: viewModel.broadcastScene,
                preferredFramesPerSecond: 60,
                options: [.ignoresSiblingOrder]
            )
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

                    // Join Code & URL Banner
                    HStack(spacing: 16) {
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
                        Text(viewModel.currentPhaseName.uppercased())
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(6)

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
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

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
}
