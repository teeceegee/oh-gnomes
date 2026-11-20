import Foundation
import SceneKit
import AppKit
import GnomesCore
import GnomesSimulation

@MainActor
public final class Gnome3DNode: SCNNode {
    public let gnome: Gnome
    public let visualProfile: GnomeVisualProfile
    public let lane: Int

    private let bodyRoot = SCNNode()
    private let leftLeg = SCNNode()
    private let rightLeg = SCNNode()
    private let leftArm = SCNNode()
    private let rightArm = SCNNode()
    private let hatNode = SCNNode()
    private var gemContainerNode: SCNNode?
    private var stridePhase: Double = 0.0

    public init(gnome: Gnome, lane: Int) {
        self.gnome = gnome
        self.visualProfile = GnomeVisualProfile.profile(for: gnome)
        self.lane = lane
        super.init()

        self.name = "gnome_\(gnome.id)"
        buildRig()
        buildNameplate()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildRig() {
        let hScale = CGFloat(visualProfile.heightScale)
        let wScale = CGFloat(visualProfile.widthScale)
        bodyRoot.scale = SCNVector3(wScale, hScale, wScale)
        addChildNode(bodyRoot)

        let tunicColor = Color3DHelper.nsColor(fromHex: visualProfile.tunicColorHex)
        let hatColor = Color3DHelper.nsColor(fromHex: visualProfile.hatColorHex)
        let beardColor = Color3DHelper.nsColor(fromHex: visualProfile.beardColorHex)
        let skinColor = NSColor(red: 0.98, green: 0.80, blue: 0.68, alpha: 1.0)
        let bootColor = NSColor(red: 0.22, green: 0.14, blue: 0.08, alpha: 1.0)

        // 1. Torso (Tunic)
        let torsoGeo = SCNCylinder(radius: 0.24, height: 0.48)
        torsoGeo.firstMaterial?.diffuse.contents = tunicColor
        torsoGeo.firstMaterial?.roughness.contents = 0.75
        let torso = SCNNode(geometry: torsoGeo)
        torso.position = SCNVector3(0, 0.44, 0)
        torso.castsShadow = true
        bodyRoot.addChildNode(torso)

        // Belt
        let beltGeo = SCNCylinder(radius: 0.248, height: 0.07)
        beltGeo.firstMaterial?.diffuse.contents = bootColor
        let belt = SCNNode(geometry: beltGeo)
        belt.position = SCNVector3(0, 0.30, 0)
        bodyRoot.addChildNode(belt)

        // 2. Legs
        let legGeo = SCNCapsule(capRadius: 0.075, height: 0.28)
        legGeo.firstMaterial?.diffuse.contents = bootColor
        leftLeg.geometry = legGeo
        leftLeg.position = SCNVector3(0, 0.14, -0.10)
        leftLeg.castsShadow = true
        bodyRoot.addChildNode(leftLeg)

        rightLeg.geometry = legGeo
        rightLeg.position = SCNVector3(0, 0.14, 0.10)
        rightLeg.castsShadow = true
        bodyRoot.addChildNode(rightLeg)

        // 3. Arms
        let armGeo = SCNCapsule(capRadius: 0.06, height: 0.32)
        armGeo.firstMaterial?.diffuse.contents = tunicColor
        leftArm.geometry = armGeo
        leftArm.position = SCNVector3(0, 0.50, -0.27)
        leftArm.castsShadow = true
        bodyRoot.addChildNode(leftArm)

        rightArm.geometry = armGeo
        rightArm.position = SCNVector3(0, 0.50, 0.27)
        rightArm.castsShadow = true
        bodyRoot.addChildNode(rightArm)

        // 4. Head + Nose + Eyes (facing +X)
        let headGeo = SCNSphere(radius: 0.20)
        headGeo.firstMaterial?.diffuse.contents = skinColor
        let head = SCNNode(geometry: headGeo)
        head.position = SCNVector3(0, 0.80, 0)
        head.castsShadow = true
        bodyRoot.addChildNode(head)

        let noseGeo = SCNSphere(radius: 0.055)
        noseGeo.firstMaterial?.diffuse.contents = NSColor(red: 0.96, green: 0.62, blue: 0.58, alpha: 1.0)
        let nose = SCNNode(geometry: noseGeo)
        nose.position = SCNVector3(0.20, 0.80, 0)
        bodyRoot.addChildNode(nose)

        let eyeGeo = SCNSphere(radius: 0.025)
        eyeGeo.firstMaterial?.diffuse.contents = NSColor.black
        for zSide in [-0.07, 0.07] {
            let eye = SCNNode(geometry: eyeGeo)
            eye.position = SCNVector3(0.17, 0.86, CGFloat(zSide))
            bodyRoot.addChildNode(eye)
        }

        // 5. Unique Beard Style
        buildBeard(color: beardColor)

        // 6. Unique Hat Style
        buildHat(color: hatColor)

        // 7. Unique Accessory
        buildAccessory()
    }

    private func buildBeard(color: NSColor) {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.roughness.contents = 0.85

        switch visualProfile.beardStyle {
        case .longFlowing:
            let cone = SCNCone(topRadius: 0.17, bottomRadius: 0.03, height: 0.42)
            cone.materials = [mat]
            let n = SCNNode(geometry: cone)
            n.position = SCNVector3(0.12, 0.56, 0)
            n.eulerAngles = SCNVector3(0, 0, CGFloat.pi)
            bodyRoot.addChildNode(n)
        case .bushy:
            let sphere = SCNSphere(radius: 0.18)
            sphere.materials = [mat]
            let n = SCNNode(geometry: sphere)
            n.position = SCNVector3(0.12, 0.66, 0)
            n.scale = SCNVector3(0.9, 1.1, 1.2)
            bodyRoot.addChildNode(n)
        case .braided:
            let cyl = SCNCylinder(radius: 0.07, height: 0.36)
            cyl.materials = [mat]
            let n = SCNNode(geometry: cyl)
            n.position = SCNVector3(0.15, 0.56, 0)
            bodyRoot.addChildNode(n)
        case .handlebar:
            let bar = SCNCapsule(capRadius: 0.035, height: 0.34)
            bar.materials = [mat]
            let n = SCNNode(geometry: bar)
            n.position = SCNVector3(0.18, 0.74, 0)
            n.eulerAngles = SCNVector3(CGFloat.pi / 2.0, 0, 0)
            bodyRoot.addChildNode(n)
        case .trimmed:
            let box = SCNBox(width: 0.14, height: 0.18, length: 0.22, chamferRadius: 0.06)
            box.materials = [mat]
            let n = SCNNode(geometry: box)
            n.position = SCNVector3(0.13, 0.68, 0)
            bodyRoot.addChildNode(n)
        }
    }

    private func buildHat(color: NSColor) {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.roughness.contents = 0.6

        hatNode.position = SCNVector3(0, 0.94, 0)
        bodyRoot.addChildNode(hatNode)

        switch visualProfile.hatStyle {
        case .pointy:
            let cone = SCNCone(topRadius: 0.01, bottomRadius: 0.22, height: 0.45)
            cone.materials = [mat]
            let n = SCNNode(geometry: cone)
            n.position = SCNVector3(0, 0.22, 0)
            n.castsShadow = true
            hatNode.addChildNode(n)
        case .wizardTall:
            let cone = SCNCone(topRadius: 0.01, bottomRadius: 0.21, height: 0.62)
            cone.materials = [mat]
            let n = SCNNode(geometry: cone)
            n.position = SCNVector3(-0.04, 0.29, 0)
            n.eulerAngles = SCNVector3(0, 0, 0.15)
            n.castsShadow = true
            hatNode.addChildNode(n)
            let brim = SCNCylinder(radius: 0.32, height: 0.03)
            brim.materials = [mat]
            hatNode.addChildNode(SCNNode(geometry: brim))
        case .wideBrim:
            let top = SCNCylinder(radius: 0.18, height: 0.22)
            top.materials = [mat]
            let n = SCNNode(geometry: top)
            n.position = SCNVector3(0, 0.11, 0)
            hatNode.addChildNode(n)
            let brim = SCNCylinder(radius: 0.35, height: 0.035)
            brim.materials = [mat]
            hatNode.addChildNode(SCNNode(geometry: brim))
        case .bowler:
            let dome = SCNSphere(radius: 0.20)
            dome.materials = [mat]
            let n = SCNNode(geometry: dome)
            n.position = SCNVector3(0, 0.08, 0)
            hatNode.addChildNode(n)
            let brim = SCNCylinder(radius: 0.27, height: 0.03)
            brim.materials = [mat]
            hatNode.addChildNode(SCNNode(geometry: brim))
        case .beret:
            let beret = SCNCylinder(radius: 0.24, height: 0.10)
            beret.materials = [mat]
            let n = SCNNode(geometry: beret)
            n.position = SCNVector3(-0.03, 0.06, 0)
            n.eulerAngles = SCNVector3(0, 0, 0.18)
            hatNode.addChildNode(n)
        }
    }

    private func buildAccessory() {
        switch visualProfile.accessory {
        case .monocle:
            let ring = SCNTorus(ringRadius: 0.045, pipeRadius: 0.008)
            ring.firstMaterial?.diffuse.contents = NSColor.systemYellow
            let n = SCNNode(geometry: ring)
            n.position = SCNVector3(0.19, 0.86, 0.07)
            n.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 2.0)
            bodyRoot.addChildNode(n)
        case .goggles:
            for zSide in [-0.07, 0.07] {
                let lens = SCNCylinder(radius: 0.045, height: 0.03)
                lens.firstMaterial?.diffuse.contents = NSColor.cyan
                let n = SCNNode(geometry: lens)
                n.position = SCNVector3(0.19, 0.86, CGFloat(zSide))
                n.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 2.0)
                bodyRoot.addChildNode(n)
            }
        case .flower:
            let flower = SCNSphere(radius: 0.06)
            flower.firstMaterial?.diffuse.contents = NSColor.systemPink
            let n = SCNNode(geometry: flower)
            n.position = SCNVector3(0.05, 1.05, 0.18)
            bodyRoot.addChildNode(n)
        case .trowel:
            let handle = SCNCylinder(radius: 0.025, height: 0.30)
            handle.firstMaterial?.diffuse.contents = NSColor.brown
            let n = SCNNode(geometry: handle)
            n.position = SCNVector3(0.10, 0.45, 0.30)
            n.eulerAngles = SCNVector3(0, 0, -0.5)
            rightArm.addChildNode(n)
        case .lantern:
            let lantern = SCNBox(width: 0.10, height: 0.14, length: 0.10, chamferRadius: 0.02)
            lantern.firstMaterial?.diffuse.contents = NSColor.systemYellow
            lantern.firstMaterial?.emission.contents = NSColor.systemYellow
            let n = SCNNode(geometry: lantern)
            n.position = SCNVector3(0.15, -0.15, 0)
            rightArm.addChildNode(n)
        case .pipe:
            let stem = SCNCylinder(radius: 0.015, height: 0.16)
            stem.firstMaterial?.diffuse.contents = NSColor.brown
            let n = SCNNode(geometry: stem)
            n.position = SCNVector3(0.24, 0.72, 0.04)
            n.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 2.0)
            bodyRoot.addChildNode(n)
        case .magnifyingGlass:
            let ring = SCNTorus(ringRadius: 0.07, pipeRadius: 0.012)
            ring.firstMaterial?.diffuse.contents = NSColor.orange
            let n = SCNNode(geometry: ring)
            n.position = SCNVector3(0.18, 0.0, 0)
            leftArm.addChildNode(n)
        case .none:
            break
        }
    }

    private func buildNameplate() {
        let textGeo = SCNText(string: gnome.name, extrusionDepth: 0.02)
        textGeo.font = NSFont.boldSystemFont(ofSize: 0.22)
        textGeo.flatness = 0.2
        textGeo.firstMaterial?.diffuse.contents = NSColor.white

        let (minB, maxB) = textGeo.boundingBox
        let textNode = SCNNode(geometry: textGeo)
        textNode.position = SCNVector3(-(maxB.x - minB.x) / 2.0, 1.55, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        textNode.constraints = [billboard]
        addChildNode(textNode)
    }

    /// Attaches a glowing 3D rotating Gnome Gem & player badge above this runner
    public func attachGem(gem: GnomeGem, playerDisplayName: String) {
        gemContainerNode?.removeFromParentNode()

        let container = SCNNode()
        container.position = SCNVector3(0, 2.05, 0)

        let gemColor = Color3DHelper.nsColor(fromHex: gem.colorHex)
        let gemGeo = SCNPyramid(width: 0.34, height: 0.45, length: 0.34)
        gemGeo.firstMaterial?.diffuse.contents = gemColor
        gemGeo.firstMaterial?.emission.contents = gemColor.withAlphaComponent(0.5)
        gemGeo.firstMaterial?.specular.contents = NSColor.white
        gemGeo.firstMaterial?.shininess = 0.9

        let gemMesh = SCNNode(geometry: gemGeo)
        gemMesh.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2.0, z: 0, duration: 2.0)))
        container.addChildNode(gemMesh)

        let playerText = SCNText(string: "\(gem.iconSymbol) \(playerDisplayName)", extrusionDepth: 0.02)
        playerText.font = NSFont.boldSystemFont(ofSize: 0.24)
        playerText.firstMaterial?.diffuse.contents = NSColor.yellow
        let (minB, maxB) = playerText.boundingBox
        let labelNode = SCNNode(geometry: playerText)
        labelNode.position = SCNVector3(-(maxB.x - minB.x) / 2.0, 0.52, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        labelNode.constraints = [billboard]
        container.addChildNode(labelNode)

        container.runAction(SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0.16, z: 0, duration: 0.6),
            SCNAction.moveBy(x: 0, y: -0.16, z: 0, duration: 0.6)
        ])))

        addChildNode(container)
        self.gemContainerNode = container
    }

    /// Updates stride animation, airborne somersault, or tumble pose from simulation state
    public func updateAnimation(from state: RunnerState, dt: Double) {
        stridePhase += state.velocityMps * dt * 2.8

        switch state.statusEffect {
        case .running, .sprinting:
            let swing = CGFloat(sin(stridePhase)) * 0.65
            leftLeg.eulerAngles = SCNVector3(0, 0, swing)
            rightLeg.eulerAngles = SCNVector3(0, 0, -swing)
            leftArm.eulerAngles = SCNVector3(0, 0, -swing * 0.8)
            rightArm.eulerAngles = SCNVector3(0, 0, swing * 0.8)
            bodyRoot.position.y = CGFloat(abs(sin(stridePhase))) * 0.10
            bodyRoot.eulerAngles = SCNVector3(0, 0, -0.08) // Forward lean

        case .airborneLaunch:
            bodyRoot.position.y = 2.1
            bodyRoot.eulerAngles = SCNVector3(0, 0, CGFloat(-stridePhase * 1.5)) // Somersault!

        case .stumbled:
            bodyRoot.position.y = 0.15
            bodyRoot.eulerAngles = SCNVector3(0.3, 0, CGFloat.pi / 2.2) // Faceplant tumble!

        case .mudStuck:
            let slowSwing = CGFloat(sin(stridePhase * 0.4)) * 0.25
            leftLeg.eulerAngles = SCNVector3(0, 0, slowSwing)
            rightLeg.eulerAngles = SCNVector3(0, 0, -slowSwing)
            bodyRoot.position.y = -0.12 // Sunk slightly in mud
            bodyRoot.eulerAngles = SCNVector3(0, 0, -0.15)

        case .finished:
            leftLeg.eulerAngles = SCNVector3Zero
            rightLeg.eulerAngles = SCNVector3Zero
            leftArm.eulerAngles = SCNVector3(0, 0, 2.4) // Victory arms raised!
            rightArm.eulerAngles = SCNVector3(0, 0, 2.4)
            bodyRoot.position.y = 0.0
            bodyRoot.eulerAngles = SCNVector3Zero
        }
    }
}
