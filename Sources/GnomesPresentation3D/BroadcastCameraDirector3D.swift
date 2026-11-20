import Foundation
import SceneKit
import GnomesSimulation

public enum BroadcastCameraAngle: String, CaseIterable, Sendable {
    case auto = "Auto TV"
    case startGateCrane = "Start Crane"
    case tracksideDolly = "Trackside Dolly"
    case droneChase = "Drone Chase"
    case overheadTactical = "Overhead"
    case finishPhotoCam = "Finish Cam"
}

@MainActor
public final class BroadcastCameraDirector3D {
    public var selectedMode: BroadcastCameraAngle = .auto
    public private(set) var activeAutoAngle: BroadcastCameraAngle = .startGateCrane

    private var autoSwitchElapsed: Double = 0.0
    private var incidentCutawayRemaining: Double = 0.0
    private var incidentTargetDistance: Double = 0.0
    private var incidentTargetLane: Int = 4
    private var smoothedLookAt = SCNVector3(0, 1.0, 0)

    public init() {}

    public func triggerIncidentCutaway(distanceMeters: Double, lane: Int) {
        guard selectedMode == .auto else { return }
        incidentCutawayRemaining = 2.0
        incidentTargetDistance = distanceMeters
        incidentTargetLane = lane
    }

    public func resetForNewRace() {
        autoSwitchElapsed = 0.0
        incidentCutawayRemaining = 0.0
        activeAutoAngle = .startGateCrane
    }

    public func updateCamera(
        cameraNode: SCNNode,
        course: Course,
        leaderDistance: Double,
        isRacing: Bool,
        dt: Double
    ) {
        if incidentCutawayRemaining > 0 {
            incidentCutawayRemaining = max(0, incidentCutawayRemaining - dt)
        }

        let effectiveAngle: BroadcastCameraAngle
        if selectedMode != .auto {
            effectiveAngle = selectedMode
        } else if !isRacing {
            effectiveAngle = .startGateCrane
        } else if leaderDistance >= course.totalDistanceMeters - 22.0 {
            effectiveAngle = .finishPhotoCam
        } else {
            autoSwitchElapsed += dt
            if autoSwitchElapsed >= 4.5 {
                autoSwitchElapsed = 0.0
                let cycle: [BroadcastCameraAngle] = [.droneChase, .tracksideDolly, .overheadTactical, .droneChase]
                let currentIdx = cycle.firstIndex(of: activeAutoAngle) ?? 0
                activeAutoAngle = cycle[(currentIdx + 1) % cycle.count]
            }
            effectiveAngle = activeAutoAngle
        }

        let focusDist = (incidentCutawayRemaining > 0 && selectedMode == .auto) ? incidentTargetDistance : leaderDistance
        let focusLane = (incidentCutawayRemaining > 0 && selectedMode == .auto) ? incidentTargetLane : 4
        let trackPt = course.position3D(atDistanceMeters: focusDist, lane: focusLane)

        let forwardX = cos(trackPt.headingRadians)
        let forwardZ = -sin(trackPt.headingRadians)
        let rightX = -sin(trackPt.headingRadians)
        let rightZ = -cos(trackPt.headingRadians)

        var desiredPos: SCNVector3
        var desiredLookAt = SCNVector3(trackPt.x, trackPt.y + 0.9, trackPt.z)

        if incidentCutawayRemaining > 0 && selectedMode == .auto {
            // Tight dramatic incident cutaway
            desiredPos = SCNVector3(
                trackPt.x + forwardX * 3.5 + rightX * 4.5,
                trackPt.y + 2.4,
                trackPt.z + forwardZ * 3.5 + rightZ * 4.5
            )
        } else {
            switch effectiveAngle {
            case .auto, .startGateCrane:
                let startPt = course.position3D(atDistanceMeters: 2.0, lane: 4)
                desiredPos = SCNVector3(startPt.x - 9.5, startPt.y + 5.2, startPt.z + 8.5)
                desiredLookAt = SCNVector3(startPt.x + 8.0, startPt.y + 1.0, startPt.z)

            case .tracksideDolly:
                desiredPos = SCNVector3(
                    trackPt.x + forwardX * 2.5 + rightX * 11.0,
                    trackPt.y + 3.2,
                    trackPt.z + forwardZ * 2.5 + rightZ * 11.0
                )

            case .droneChase:
                desiredPos = SCNVector3(
                    trackPt.x - forwardX * 11.5 + rightX * 3.0,
                    trackPt.y + 6.5,
                    trackPt.z - forwardZ * 11.5 + rightZ * 3.0
                )
                desiredLookAt = SCNVector3(trackPt.x + forwardX * 4.0, trackPt.y + 0.8, trackPt.z + forwardZ * 4.0)

            case .overheadTactical:
                desiredPos = SCNVector3(
                    trackPt.x - forwardX * 9.0,
                    trackPt.y + 17.0,
                    trackPt.z - forwardZ * 9.0
                )

            case .finishPhotoCam:
                let finPt = course.position3D(atDistanceMeters: course.totalDistanceMeters, lane: 4)
                let finRightX = -sin(finPt.headingRadians)
                let finRightZ = -cos(finPt.headingRadians)
                desiredPos = SCNVector3(
                    finPt.x + finRightX * 11.5,
                    finPt.y + 3.0,
                    finPt.z + finRightZ * 11.5
                )
                desiredLookAt = SCNVector3(finPt.x - 2.0, finPt.y + 0.9, finPt.z)
            }
        }

        // Smooth camera damping
        let alpha = CGFloat(min(1.0, dt * 4.5))
        cameraNode.position = SCNVector3(
            cameraNode.position.x + (desiredPos.x - cameraNode.position.x) * alpha,
            cameraNode.position.y + (desiredPos.y - cameraNode.position.y) * alpha,
            cameraNode.position.z + (desiredPos.z - cameraNode.position.z) * alpha
        )
        smoothedLookAt = SCNVector3(
            smoothedLookAt.x + (desiredLookAt.x - smoothedLookAt.x) * alpha,
            smoothedLookAt.y + (desiredLookAt.y - smoothedLookAt.y) * alpha,
            smoothedLookAt.z + (desiredLookAt.z - smoothedLookAt.z) * alpha
        )
        cameraNode.look(at: smoothedLookAt, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
    }
}
