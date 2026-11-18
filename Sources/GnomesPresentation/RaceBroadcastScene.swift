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

        // Track surface background (extended with runoff left & right so camera never sees void)
        let runoffWidth = trackWidth + 2400.0
        let trackBg = SKShapeNode(rectOf: CGSize(width: runoffWidth, height: trackHeight), cornerRadius: 16)
        trackBg.position = CGPoint(x: trackWidth / 2.0, y: size.height / 2.0)
        trackBg.fillColor = ColorType(red: 0.22, green: 0.45, blue: 0.25, alpha: 1.0) // Lush green grass
        trackBg.strokeColor = .clear
        addChild(trackBg)

        // Draw surface zones (e.g. mud pit)
        for zone in course.surfaceZones {
            let startX = 100.0 + CGFloat(zone.startMeter * 25.0)
            let endX = 100.0 + CGFloat(zone.endMeter * 25.0)
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

        // Lane divider lines
        let startY = (size.height / 2.0) + (4 * 70.0)
        for laneIdx in 0...8 {
            let lineY = startY - CGFloat(laneIdx * 70)
            let lanePath = CGMutablePath()
            lanePath.move(to: CGPoint(x: 100.0, y: lineY))
            lanePath.addLine(to: CGPoint(x: 100.0 + trackWidth, y: lineY))
            let laneLine = SKShapeNode(path: lanePath)
            laneLine.strokeColor = ColorType(white: 1.0, alpha: 0.22)
            laneLine.lineWidth = 2.0
            laneLine.zPosition = 2
            addChild(laneLine)
        }

        // Starting Line
        let startLine = SKShapeNode(rectOf: CGSize(width: 8, height: trackHeight - 40))
        startLine.position = CGPoint(x: 100.0, y: size.height / 2.0)
        startLine.fillColor = ColorType(white: 1.0, alpha: 0.85)
        startLine.strokeColor = .clear
        startLine.zPosition = 3
        addChild(startLine)

        // Finish Line
        let finishX = 100.0 + trackWidth
        let finishLine = SKShapeNode(rectOf: CGSize(width: 20, height: trackHeight))
        finishLine.position = CGPoint(x: finishX, y: size.height / 2.0)
        finishLine.fillColor = .white
        finishLine.strokeColor = .red
        finishLine.lineWidth = 2
        finishLine.zPosition = 3
        addChild(finishLine)

        // Obstacle Props along the track
        for obs in course.obstacleZones {
            let obsX = 100.0 + CGFloat(obs.locationMeter * 25.0)
            let propNode = SKShapeNode(rectOf: CGSize(width: 18, height: trackHeight - 60), cornerRadius: 6)
            propNode.position = CGPoint(x: obsX, y: size.height / 2.0)
            propNode.zPosition = 3

            let label = SKLabelNode()
            label.fontSize = 18
            label.position = CGPoint(x: 0, y: (trackHeight / 2.0) - 20)

            switch obs.obstacleType {
            case .springLauncher, .catapultTrap:
                propNode.fillColor = ColorType(red: 0.95, green: 0.75, blue: 0.10, alpha: 0.35)
                propNode.strokeColor = ColorType(red: 0.95, green: 0.85, blue: 0.20, alpha: 0.8)
                label.text = "🚀"
            case .mudPuddle:
                propNode.fillColor = ColorType(red: 0.32, green: 0.18, blue: 0.08, alpha: 0.65)
                propNode.strokeColor = .clear
                label.text = "💩"
            case .waterSprinkler, .movingSprinkler:
                propNode.fillColor = ColorType(red: 0.20, green: 0.65, blue: 0.95, alpha: 0.35)
                propNode.strokeColor = ColorType(red: 0.40, green: 0.80, blue: 1.0, alpha: 0.8)
                label.text = "💦"
            case .lowHedge:
                propNode.fillColor = ColorType(red: 0.10, green: 0.35, blue: 0.12, alpha: 0.75)
                propNode.strokeColor = ColorType(red: 0.25, green: 0.60, blue: 0.25, alpha: 0.9)
                label.text = "🌿"
            case .moleHill:
                propNode.fillColor = ColorType(red: 0.45, green: 0.30, blue: 0.18, alpha: 0.75)
                propNode.strokeColor = .clear
                label.text = "⛰️"
            case .snailDistraction:
                propNode.fillColor = ColorType(red: 0.55, green: 0.45, blue: 0.25, alpha: 0.55)
                propNode.strokeColor = .clear
                label.text = "🐌"
            case .flowerpotDomino:
                propNode.fillColor = ColorType(red: 0.75, green: 0.35, blue: 0.20, alpha: 0.65)
                propNode.strokeColor = .clear
                label.text = "🪴"
            }
            propNode.addChild(label)
            addChild(propNode)
        }
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
        broadcastCamera.position = CGPoint(x: 900, y: size.height / 2.0)
        cameraDirector.setMode(.startLine, trackBounds: CGRect(x: 0, y: 0, width: course.totalDistanceMeters * 25.0, height: size.height))
    }

    private func setupHUD() {
        // Photo finish banner (subtitles are rendered cleanly by the SwiftUI host overlay)
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

    /// Triggers Metal particle burst at a runner's position on incident
    public func triggerIncidentEffect(gnomeId: String, type: IncidentType) {
        guard let runner = runnerNodes.first(where: { $0.gnomeId == gnomeId }) else { return }
        let emitter: SKEmitterNode
        switch type {
        case .mudSplash, .mudSlideBowling, .stumble, .gnomePileup:
            emitter = MetalParticleShaders.makeMudSplashEmitter()
        case .airborneLaunch, .sprintSurge, .sprinklerDaze, .gnomeCollision, .hedgeShortcut, .snailDistraction, .hatSteal:
            emitter = MetalParticleShaders.makeSpringDustEmitter()
        }
        emitter.position = runner.position
        emitter.zPosition = 8
        addChild(emitter)
        emitter.run(SKAction.sequence([SKAction.wait(forDuration: 1.0), SKAction.removeFromParent()]))
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
