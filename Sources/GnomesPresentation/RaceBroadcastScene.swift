import Foundation
import SpriteKit
import GnomesCore
import GnomesContracts
import GnomesSimulation

@MainActor
public final class RaceBroadcastScene: SKScene, @unchecked Sendable {
    public static let standardSize = CGSize(width: 1920, height: 1080)

    public let course: Course
    public let gnomes: [Gnome]
    public private(set) var runnerNodes: [RunnerNode] = []
    public let cameraDirector = CameraDirector()
    private let broadcastCamera = SKCameraNode()

    // UI Overlays
    private let topTickerNode = SKNode()
    private let subtitleBanner = SKNode()
    private let subtitleLabel = SKLabelNode()
    private let photoFinishBanner = SKLabelNode()

    public private(set) var isPhotoFinishFrozen: Bool = false

    public init(course: Course, gnomes: [Gnome]) {
        self.course = course
        self.gnomes = gnomes
        super.init(size: Self.standardSize)
        self.scaleMode = .aspectFit
        self.backgroundColor = ColorType(red: 0.1, green: 0.12, blue: 0.18, alpha: 1.0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func didMove(to view: SKView) {
        setupWorld()
        setupRunners()
        setupCamera()
        setupHUD()
    }

    private func setupWorld() {
        let trackWidth = CGFloat(course.totalDistanceMeters * 25.0) // 25 pixels per meter
        let trackHeight: CGFloat = 8 * 70.0 + 100.0 // 8 lanes @ 70px

        // Track surface background
        let trackBg = SKShapeNode(rectOf: CGSize(width: trackWidth, height: trackHeight), cornerRadius: 16)
        trackBg.position = CGPoint(x: trackWidth / 2.0, y: size.height / 2.0)
        trackBg.fillColor = ColorType(red: 0.22, green: 0.45, blue: 0.25, alpha: 1.0) // Lush green grass
        trackBg.strokeColor = .clear
        addChild(trackBg)

        // Draw surface zones (e.g. mud pit)
        for zone in course.surfaceZones {
            let startX = CGFloat(zone.startMeter * 25.0)
            let endX = CGFloat(zone.endMeter * 25.0)
            let zoneWidth = endX - startX
            let zoneNode = SKShapeNode(rectOf: CGSize(width: zoneWidth, height: trackHeight))
            zoneNode.position = CGPoint(x: startX + (zoneWidth / 2.0), y: size.height / 2.0)

            switch zone.surfaceType {
            case .mud:
                zoneNode.fillColor = ColorType(red: 0.40, green: 0.26, blue: 0.15, alpha: 0.85) // Muddy brown
            case .stone:
                zoneNode.fillColor = ColorType(red: 0.55, green: 0.58, blue: 0.62, alpha: 0.85) // Stone gray
            case .water:
                zoneNode.fillColor = ColorType(red: 0.20, green: 0.45, blue: 0.75, alpha: 0.85) // Water blue
            case .grass:
                zoneNode.fillColor = .clear
            }
            zoneNode.strokeColor = .clear
            addChild(zoneNode)
        }

        // Finish Line
        let finishX = trackWidth - 100.0
        let finishLine = SKShapeNode(rectOf: CGSize(width: 20, height: trackHeight))
        finishLine.position = CGPoint(x: finishX, y: size.height / 2.0)
        finishLine.fillColor = .white
        finishLine.strokeColor = .red
        finishLine.lineWidth = 2
        addChild(finishLine)
    }

    private func setupRunners() {
        let startY = (size.height / 2.0) + (4 * 70.0) - 35.0
        for (idx, gnome) in gnomes.enumerated() {
            let laneY = startY - CGFloat(idx * 70)
            let runner = RunnerNode(gnomeId: gnome.id, gnomeName: gnome.name, lane: idx + 1)
            runner.position = CGPoint(x: 100, y: laneY)
            runner.zPosition = 5
            runnerNodes.append(runner)
            addChild(runner)
        }
    }

    private func setupCamera() {
        addChild(broadcastCamera)
        self.camera = broadcastCamera
        broadcastCamera.position = CGPoint(x: 400, y: size.height / 2.0)
        cameraDirector.setMode(.startLine, trackBounds: CGRect(x: 0, y: 0, width: course.totalDistanceMeters * 25.0, height: size.height))
    }

    private func setupHUD() {
        // Subtitle Banner at bottom of camera view
        let bannerBg = SKShapeNode(rectOf: CGSize(width: 1400, height: 70), cornerRadius: 12)
        bannerBg.fillColor = ColorType(white: 0.0, alpha: 0.75)
        bannerBg.strokeColor = ColorType(white: 1.0, alpha: 0.2)
        bannerBg.position = CGPoint(x: 0, y: -450)
        subtitleBanner.addChild(bannerBg)

        subtitleLabel.fontName = "HelveticaNeue-Bold"
        subtitleLabel.fontSize = 24
        subtitleLabel.fontColor = .white
        subtitleLabel.position = CGPoint(x: 0, y: -460)
        subtitleLabel.horizontalAlignmentMode = .center
        subtitleBanner.addChild(subtitleLabel)

        broadcastCamera.addChild(subtitleBanner)

        // Photo finish banner
        photoFinishBanner.fontName = "HelveticaNeue-Black"
        photoFinishBanner.fontSize = 42
        photoFinishBanner.fontColor = .yellow
        photoFinishBanner.position = CGPoint(x: 0, y: 350)
        photoFinishBanner.text = "📸 PHOTO FINISH!"
        photoFinishBanner.isHidden = true
        broadcastCamera.addChild(photoFinishBanner)
    }

    /// Updates subtitles on the broadcast display
    public func setSubtitleText(_ text: String) {
        subtitleLabel.text = text
    }

    /// Triggers freeze-frame photo finish zoom
    public func triggerPhotoFinish() {
        isPhotoFinishFrozen = true
        photoFinishBanner.isHidden = false
        cameraDirector.setMode(.finishLine, trackBounds: CGRect(x: 0, y: 0, width: course.totalDistanceMeters * 25.0, height: size.height))
    }

    /// Attaches player Gnome Gems to runners
    public func attachGems(_ backedGems: [BackedGnomeGem]) {
        for bg in backedGems {
            if let runner = runnerNodes.first(where: { $0.gnomeId == bg.gnomeId }) {
                runner.attachGem(gem: bg.gem, playerDisplayName: bg.playerDisplayName)
            }
        }
    }

    /// Updates scene node positions from tick simulation state
    public func updateScene(runners states: [RunnerState], dt: CGFloat) {
        guard !isPhotoFinishFrozen else { return }

        var maxLeaderX: CGFloat = 0.0
        let trackWidth = CGFloat(course.totalDistanceMeters * 25.0)

        for state in states {
            if let node = runnerNodes.first(where: { $0.gnomeId == state.gnomeId }) {
                let worldX = 100.0 + CGFloat(state.distanceMeters * 25.0)
                node.position.x = worldX
                node.update(from: state)

                if worldX > maxLeaderX && !state.isFinished {
                    maxLeaderX = worldX
                }
            }
        }

        cameraDirector.update(
            camera: broadcastCamera,
            leaderX: maxLeaderX,
            trackBounds: CGRect(x: 0, y: 0, width: trackWidth, height: size.height),
            dt: dt
        )
    }
}
