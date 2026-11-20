import Foundation
import SceneKit
import SwiftUI
import AppKit
import GnomesCore
import GnomesContracts
import GnomesSimulation

@MainActor
public final class RaceBroadcast3DScene: ObservableObject {
    public let scene: SCNScene
    public let course: Course
    public let gnomes: [Gnome]
    public let cameraNode: SCNNode
    public let cameraDirector = BroadcastCameraDirector3D()
    public private(set) var gnomeNodes: [Gnome3DNode] = []

    private var isRacing: Bool = false

    public init(course: Course, gnomes: [Gnome]) {
        self.course = course
        self.gnomes = gnomes
        self.scene = SCNScene()
        self.cameraNode = SCNNode()

        setupEnvironmentAndLighting()
        setupCourse()
        setupRunners()
        setupCamera()
    }

    private func setupEnvironmentAndLighting() {
        // Sky gradient background
        scene.background.contents = NSColor(red: 0.45, green: 0.74, blue: 0.96, alpha: 1.0)
        scene.fogStartDistance = 75.0
        scene.fogEndDistance = 170.0
        scene.fogColor = NSColor(red: 0.68, green: 0.86, blue: 0.98, alpha: 1.0)

        // Warm afternoon sunlight with real-time shadows
        let sunLight = SCNLight()
        sunLight.type = .directional
        sunLight.color = NSColor(red: 1.0, green: 0.97, blue: 0.90, alpha: 1.0)
        sunLight.intensity = 1300
        sunLight.castsShadow = true
        sunLight.shadowSampleCount = 8
        sunLight.shadowRadius = 3.0
        sunLight.shadowColor = NSColor(white: 0.0, alpha: 0.35)
        let sunNode = SCNNode()
        sunNode.light = sunLight
        sunNode.eulerAngles = SCNVector3(-CGFloat.pi / 3.0, CGFloat.pi / 5.0, 0)
        scene.rootNode.addChildNode(sunNode)

        // Ambient sky fill light
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(red: 0.65, green: 0.78, blue: 0.95, alpha: 1.0)
        ambient.intensity = 450
        let ambNode = SCNNode()
        ambNode.light = ambient
        scene.rootNode.addChildNode(ambNode)
    }

    private func setupCourse() {
        let courseNode = GardenCourse3DBuilder.buildCourseNode(course: course)
        scene.rootNode.addChildNode(courseNode)
    }

    private func setupRunners() {
        for (idx, gnome) in gnomes.enumerated() {
            let lane = idx + 1
            let node = Gnome3DNode(gnome: gnome, lane: lane)
            let pt = course.position3D(atDistanceMeters: 0.0, lane: lane)
            node.position = SCNVector3(pt.x, pt.y, pt.z)
            node.eulerAngles = SCNVector3(0, CGFloat(pt.headingRadians), 0)
            gnomeNodes.append(node)
            scene.rootNode.addChildNode(node)
        }
    }

    private func setupCamera() {
        let cam = SCNCamera()
        cam.fieldOfView = 52
        cam.zNear = 0.2
        cam.zFar = 250.0
        cam.wantsHDR = true
        cam.bloomIntensity = 0.35
        cam.bloomThreshold = 0.9
        cameraNode.camera = cam

        let startPt = course.position3D(atDistanceMeters: 2.0, lane: 4)
        cameraNode.position = SCNVector3(startPt.x - 9.5, startPt.y + 5.2, startPt.z + 8.5)
        cameraNode.look(at: SCNVector3(startPt.x + 8.0, startPt.y + 1.0, startPt.z), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        scene.rootNode.addChildNode(cameraNode)
    }

    public func setCameraAngle(_ angle: BroadcastCameraAngle) {
        cameraDirector.selectedMode = angle
        if !isRacing {
            cameraDirector.updateCamera(cameraNode: cameraNode, course: course, leaderDistance: 0.0, isRacing: false, dt: 0.5)
        }
    }

    public func attachGems(_ backedGems: [BackedGnomeGem]) {
        for bg in backedGems {
            if let runner = gnomeNodes.first(where: { $0.gnome.id == bg.gnomeId }) {
                runner.attachGem(gem: bg.gem, playerDisplayName: bg.playerDisplayName)
            }
        }
    }

    public func triggerIncidentEffect(gnomeId: String, type: IncidentType) {
        guard let runner = gnomeNodes.first(where: { $0.gnome.id == gnomeId }) else { return }
        let ps: SCNParticleSystem
        switch type {
        case .mudSplash, .mudSlideBowling, .stumble, .gnomePileup, .gnomeCollision:
            ps = ParticleFX3D.makeMudSplash3D()
            cameraDirector.triggerIncidentCutaway(distanceMeters: Double(runner.position.x), lane: runner.lane)
        case .sprinklerDaze:
            ps = ParticleFX3D.makeWaterSpray3D()
        case .airborneLaunch, .sprintSurge, .hedgeShortcut, .snailDistraction, .hatSteal:
            ps = ParticleFX3D.makeSpringBurst3D()
            cameraDirector.triggerIncidentCutaway(distanceMeters: Double(runner.position.x), lane: runner.lane)
        }
        runner.addParticleSystem(ps)
    }

    public func triggerFinishConfetti() {
        let finPt = course.position3D(atDistanceMeters: course.totalDistanceMeters, lane: 4)
        let confettiNode = SCNNode()
        confettiNode.position = SCNVector3(finPt.x, finPt.y + 4.5, finPt.z)
        confettiNode.addParticleSystem(ParticleFX3D.makeFinishConfetti3D())
        scene.rootNode.addChildNode(confettiNode)
    }

    public func updateScene(runners states: [RunnerState], dt: Double) {
        isRacing = true
        var maxLeaderDist = 0.0

        for state in states {
            if let node = gnomeNodes.first(where: { $0.gnome.id == state.gnomeId }) {
                let pt = course.position3D(atDistanceMeters: state.distanceMeters, lane: node.lane)
                node.position = SCNVector3(pt.x, pt.y, pt.z)
                node.eulerAngles = SCNVector3(0, CGFloat(pt.headingRadians), 0)
                node.updateAnimation(from: state, dt: dt)

                if state.distanceMeters > maxLeaderDist && !state.isFinished {
                    maxLeaderDist = state.distanceMeters
                }
            }
        }

        if maxLeaderDist == 0.0, let firstDist = states.map({ $0.distanceMeters }).max() {
            maxLeaderDist = firstDist
        }

        cameraDirector.updateCamera(
            cameraNode: cameraNode,
            course: course,
            leaderDistance: maxLeaderDist,
            isRacing: true,
            dt: dt
        )
    }
}

/// SwiftUI NSViewRepresentable hosting Metal-accelerated SceneKit 3D broadcast view
public struct RaceBroadcast3DView: NSViewRepresentable {
    @ObservedObject var sceneController: RaceBroadcast3DScene

    public init(sceneController: RaceBroadcast3DScene) {
        self.sceneController = sceneController
    }

    public func makeNSView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero, options: [SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue])
        view.scene = sceneController.scene
        view.pointOfView = sceneController.cameraNode
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = true
        view.autoenablesDefaultLighting = false
        return view
    }

    public func updateNSView(_ nsView: SCNView, context: Context) {
        if nsView.scene !== sceneController.scene {
            nsView.scene = sceneController.scene
            nsView.pointOfView = sceneController.cameraNode
        }
    }
}
