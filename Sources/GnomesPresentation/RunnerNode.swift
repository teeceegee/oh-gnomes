import Foundation
import SpriteKit
import GnomesCore
import GnomesSimulation

@MainActor
public final class RunnerNode: SKNode, @unchecked Sendable {
    public let gnomeId: String
    public let gnomeName: String
    public let lane: Int

    private let bodyNode: SKNode
    private let hatNode: SKShapeNode
    private let beardNode: SKShapeNode
    private let nameTag: SKLabelNode
    public private(set) var gemNode: GemNode?

    public init(gnomeId: String, gnomeName: String, lane: Int) {
        self.gnomeId = gnomeId
        self.gnomeName = gnomeName
        self.lane = lane

        self.bodyNode = SKNode()

        // 1. Gnome body
        let bodyCircle = SKShapeNode(circleOfRadius: 14)
        bodyCircle.fillColor = ColorType(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        bodyCircle.strokeColor = .white
        bodyCircle.lineWidth = 1.0
        bodyNode.addChild(bodyCircle)

        // 2. Gnome Beard
        let beardPath = CGMutablePath()
        beardPath.move(to: CGPoint(x: -8, y: -4))
        beardPath.addQuadCurve(to: CGPoint(x: 0, y: -16), control: CGPoint(x: -4, y: -12))
        beardPath.addQuadCurve(to: CGPoint(x: 8, y: -4), control: CGPoint(x: 4, y: -12))
        beardPath.closeSubpath()
        self.beardNode = SKShapeNode(path: beardPath)
        beardNode.fillColor = .white
        beardNode.strokeColor = .clear
        bodyNode.addChild(beardNode)

        // 3. Pointy Red Hat
        let hatPath = CGMutablePath()
        hatPath.move(to: CGPoint(x: -12, y: 6))
        hatPath.addLine(to: CGPoint(x: 0, y: 26))
        hatPath.addLine(to: CGPoint(x: 12, y: 6))
        hatPath.closeSubpath()
        self.hatNode = SKShapeNode(path: hatPath)
        hatNode.fillColor = ColorType(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
        hatNode.strokeColor = .white
        hatNode.lineWidth = 1.0
        bodyNode.addChild(hatNode)

        // 4. Name Tag
        self.nameTag = SKLabelNode(text: gnomeName)
        nameTag.fontSize = 11
        nameTag.fontName = "HelveticaNeue-Bold"
        nameTag.fontColor = .white
        nameTag.position = CGPoint(x: 0, y: -26)
        nameTag.horizontalAlignmentMode = .center

        super.init()

        addChild(bodyNode)
        addChild(nameTag)

        startRunningAnimation()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Attaches or updates the floating Gnome Gem for this runner
    public func attachGem(gem: GnomeGem, playerDisplayName: String) {
        gemNode?.removeFromParent()
        let newGem = GemNode(gem: gem, playerDisplayName: playerDisplayName)
        newGem.position = CGPoint(x: 0, y: 48)
        newGem.zPosition = 10
        self.gemNode = newGem
        addChild(newGem)
    }

    /// Starts cartoon stride bobbing
    public func startRunningAnimation() {
        bodyNode.removeAction(forKey: "statusAction")
        bodyNode.zRotation = 0
        let strideUp = SKAction.scaleY(to: 1.15, duration: 0.12)
        let strideDown = SKAction.scaleY(to: 0.85, duration: 0.12)
        bodyNode.run(SKAction.repeatForever(SKAction.sequence([strideUp, strideDown])), withKey: "statusAction")
    }

    /// Updates node visual presentation based on simulation state vector
    public func update(from state: RunnerState) {
        switch state.statusEffect {
        case .running, .sprinting:
            if bodyNode.action(forKey: "statusAction") == nil {
                startRunningAnimation()
            }
        case .stumbled:
            bodyNode.removeAction(forKey: "statusAction")
            bodyNode.zRotation = CGFloat.pi / 2.0 // Tumbled onto ground
        case .airborneLaunch:
            bodyNode.removeAction(forKey: "statusAction")
            bodyNode.zRotation = -CGFloat.pi / 6.0 // Angled airborne leap
        case .mudStuck:
            bodyNode.removeAction(forKey: "statusAction")
            bodyNode.setScale(0.9)
        case .finished:
            bodyNode.removeAction(forKey: "statusAction")
            bodyNode.zRotation = 0
            let hop = SKAction.sequence([SKAction.moveBy(x: 0, y: 12, duration: 0.2), SKAction.moveBy(x: 0, y: -12, duration: 0.2)])
            bodyNode.run(SKAction.repeatForever(hop), withKey: "statusAction")
        }
    }
}
