import Foundation
import SpriteKit

public enum CameraMode: Sendable {
    case startLine
    case packLead
    case incidentFocus(targetPoint: CGPoint)
    case finishLine
}

@MainActor
public final class CameraDirector: @unchecked Sendable {
    public private(set) var currentMode: CameraMode = .startLine
    public var targetPosition: CGPoint = .zero
    public var targetScale: CGFloat = 1.0

    public init() {}

    public func setMode(_ mode: CameraMode, trackBounds: CGRect) {
        self.currentMode = mode
        switch mode {
        case .startLine:
            targetPosition = CGPoint(x: trackBounds.minX + 900, y: trackBounds.midY)
            targetScale = 1.0
        case .packLead:
            targetScale = 0.95
        case .incidentFocus(let point):
            targetPosition = point
            targetScale = 0.70 // Dramatic zoom-in
        case .finishLine:
            targetPosition = CGPoint(x: trackBounds.maxX - 200, y: trackBounds.midY)
            targetScale = 0.85
        }
    }

    /// Updates camera node position with smooth cinematic damping (easing)
    public func update(camera: SKCameraNode, leaderX: CGFloat, trackBounds: CGRect, dt: CGFloat) {
        switch currentMode {
        case .packLead:
            targetPosition = CGPoint(x: min(trackBounds.maxX - 400, leaderX + 150), y: trackBounds.midY)
        default:
            break
        }

        // Interpolate camera position and scale with easing factor
        let damping: CGFloat = 4.0 * dt
        let newX = camera.position.x + (targetPosition.x - camera.position.x) * damping
        let newY = camera.position.y + (targetPosition.y - camera.position.y) * damping
        camera.position = CGPoint(x: newX, y: newY)

        let newScale = camera.xScale + (targetScale - camera.xScale) * damping
        camera.setScale(newScale)
    }
}
