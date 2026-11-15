import Foundation
import SpriteKit
import GnomesCore

public typealias ColorType = SKColor

/// SpriteKit node representing a floating Gnome Gem hovering above a backed runner
@MainActor
public final class GemNode: SKNode, @unchecked Sendable {
    public let gem: GnomeGem
    public let playerDisplayName: String
    private let shapeNode: SKShapeNode
    private let symbolLabel: SKLabelNode
    private let nameLabel: SKLabelNode

    public init(gem: GnomeGem, playerDisplayName: String) {
        self.gem = gem
        self.playerDisplayName = playerDisplayName

        let size: CGFloat = 28.0
        let color = Self.colorFromHex(gem.colorHex)

        // 1. Build geometric shape geometry
        switch gem.shape {
        case .star:
            self.shapeNode = SKShapeNode(path: Self.createStarPath(radius: size / 2.0))
        case .diamond:
            self.shapeNode = SKShapeNode(path: Self.createDiamondPath(size: size))
        case .hexagon:
            self.shapeNode = SKShapeNode(path: Self.createHexagonPath(radius: size / 2.0))
        case .triangle:
            self.shapeNode = SKShapeNode(path: Self.createTrianglePath(size: size))
        case .circle:
            self.shapeNode = SKShapeNode(circleOfRadius: size / 2.0)
        case .heart:
            self.shapeNode = SKShapeNode(path: Self.createHeartPath(size: size))
        case .shield:
            self.shapeNode = SKShapeNode(path: Self.createShieldPath(size: size))
        case .clover:
            self.shapeNode = SKShapeNode(path: Self.createCloverPath(size: size))
        }

        shapeNode.fillColor = color
        shapeNode.strokeColor = .white
        shapeNode.lineWidth = 1.5

        // 2. Icon symbol label
        symbolLabel = SKLabelNode(text: gem.iconSymbol)
        symbolLabel.fontSize = 14
        symbolLabel.fontColor = .white
        symbolLabel.verticalAlignmentMode = .center
        symbolLabel.horizontalAlignmentMode = .center

        // 3. Player display name tag
        nameLabel = SKLabelNode(text: playerDisplayName)
        nameLabel.fontSize = 11
        nameLabel.fontName = "HelveticaNeue-Bold"
        nameLabel.fontColor = .white
        nameLabel.position = CGPoint(x: 0, y: 22)
        nameLabel.verticalAlignmentMode = .bottom
        nameLabel.horizontalAlignmentMode = .center

        super.init()

        addChild(shapeNode)
        addChild(symbolLabel)
        addChild(nameLabel)

        // Subtle gentle floating bobbing animation
        let bobUp = SKAction.moveBy(x: 0, y: 5, duration: 0.6)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = bobUp.reversed()
        run(SKAction.repeatForever(SKAction.sequence([bobUp, bobDown])))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func createDiamondPath(size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let half = size / 2.0
        path.move(to: CGPoint(x: 0, y: half))
        path.addLine(to: CGPoint(x: half, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -half))
        path.addLine(to: CGPoint(x: -half, y: 0))
        path.closeSubpath()
        return path
    }

    private static func createTrianglePath(size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let h = size * 0.866
        path.move(to: CGPoint(x: 0, y: h / 2.0))
        path.addLine(to: CGPoint(x: size / 2.0, y: -h / 2.0))
        path.addLine(to: CGPoint(x: -size / 2.0, y: -h / 2.0))
        path.closeSubpath()
        return path
    }

    private static func createHexagonPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<6 {
            let angle = (CGFloat(i) * CGFloat.pi / 3.0) - (CGFloat.pi / 6.0)
            let pt = CGPoint(x: radius * cos(angle), y: radius * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    private static func createStarPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let innerRadius = radius * 0.5
        for i in 0..<10 {
            let r = i.isMultiple(of: 2) ? radius : innerRadius
            let angle = (CGFloat(i) * CGFloat.pi / 5.0) - (CGFloat.pi / 2.0)
            let pt = CGPoint(x: r * cos(angle), y: r * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    private static func createHeartPath(size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let s = size * 0.45
        path.move(to: CGPoint(x: 0, y: -s))
        path.addCurve(to: CGPoint(x: -s, y: s * 0.4), control1: CGPoint(x: -s * 0.6, y: -s * 0.6), control2: CGPoint(x: -s, y: 0))
        path.addArc(center: CGPoint(x: -s * 0.5, y: s * 0.5), radius: s * 0.5, startAngle: CGFloat.pi, endAngle: 0, clockwise: false)
        path.addArc(center: CGPoint(x: s * 0.5, y: s * 0.5), radius: s * 0.5, startAngle: CGFloat.pi, endAngle: 0, clockwise: false)
        path.addCurve(to: CGPoint(x: 0, y: -s), control1: CGPoint(x: s, y: 0), control2: CGPoint(x: s * 0.6, y: -s * 0.6))
        path.closeSubpath()
        return path
    }

    private static func createShieldPath(size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let half = size / 2.0
        path.move(to: CGPoint(x: -half, y: half))
        path.addLine(to: CGPoint(x: half, y: half))
        path.addLine(to: CGPoint(x: half, y: 0))
        path.addQuadCurve(to: CGPoint(x: 0, y: -half), control: CGPoint(x: half * 0.8, y: -half * 0.7))
        path.addQuadCurve(to: CGPoint(x: -half, y: 0), control: CGPoint(x: -half * 0.8, y: -half * 0.7))
        path.closeSubpath()
        return path
    }

    private static func createCloverPath(size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let r = size * 0.28
        path.addEllipse(in: CGRect(x: -r, y: 0, width: r * 2, height: r * 2))
        path.addEllipse(in: CGRect(x: -r * 2, y: -r, width: r * 2, height: r * 2))
        path.addEllipse(in: CGRect(x: 0, y: -r, width: r * 2, height: r * 2))
        return path
    }

    public static func colorFromHex(_ hex: String) -> ColorType {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }
        var rgbValue: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgbValue)
        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0
        return ColorType(red: r, green: g, blue: b, alpha: 1.0)
    }
}
