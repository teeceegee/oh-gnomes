import Foundation
import SceneKit
import AppKit
import GnomesSimulation

@MainActor
public enum GardenCourse3DBuilder {

    public static func buildCourseNode(course: Course) -> SCNNode {
        let root = SCNNode()
        root.name = "course_\(course.id)"

        // 1. Broad rolling garden lawn floor
        let floorGeo = SCNFloor()
        floorGeo.reflectivity = 0.04
        let grassMat = SCNMaterial()
        grassMat.diffuse.contents = NSColor(red: 0.16, green: 0.42, blue: 0.18, alpha: 1.0)
        grassMat.roughness.contents = 0.9
        floorGeo.materials = [grassMat]
        let floorNode = SCNNode(geometry: floorGeo)
        floorNode.position = SCNVector3(0, -0.05, 0)
        root.addChildNode(floorNode)

        // 2. Build 3D winding track segments every 2.5m along the spline
        let stepMeters = 2.5
        let trackWidth: CGFloat = 10.2
        var dist = 0.0

        while dist < course.totalDistanceMeters {
            let nextDist = min(course.totalDistanceMeters, dist + stepMeters)
            let midDist = (dist + nextDist) * 0.5
            let p0 = course.position3D(atDistanceMeters: dist, lane: 4)
            let p1 = course.position3D(atDistanceMeters: nextDist, lane: 4)

            // Center between lane 4 and 5
            let p0c = course.position3D(atDistanceMeters: dist, lane: 4)
            let p1c = course.position3D(atDistanceMeters: nextDist, lane: 4)
            let mid = course.position3D(atDistanceMeters: midDist, lane: 4)

            let dx = p1c.x - p0c.x
            let dy = p1c.y - p0c.y
            let dz = p1c.z - p0c.z
            let segLength = CGFloat(sqrt(dx * dx + dy * dy + dz * dz)) + 0.15

            let surface = course.surfaceZones.first { midDist >= $0.startMeter && midDist < $0.endMeter }
            let segColor: NSColor
            let roughness: CGFloat
            switch surface?.surfaceType ?? .grass {
            case .grass:
                segColor = NSColor(red: 0.22, green: 0.55, blue: 0.24, alpha: 1.0)
                roughness = 0.85
            case .mud:
                segColor = NSColor(red: 0.36, green: 0.22, blue: 0.11, alpha: 1.0)
                roughness = 0.45
            case .stone:
                segColor = NSColor(red: 0.58, green: 0.60, blue: 0.63, alpha: 1.0)
                roughness = 0.70
            case .water:
                segColor = NSColor(red: 0.18, green: 0.50, blue: 0.82, alpha: 0.92)
                roughness = 0.15
            }

            let slabGeo = SCNBox(width: segLength, height: 0.25, length: trackWidth, chamferRadius: 0.03)
            slabGeo.firstMaterial?.diffuse.contents = segColor
            slabGeo.firstMaterial?.roughness.contents = roughness

            let slab = SCNNode(geometry: slabGeo)
            slab.position = SCNVector3(mid.x, mid.y - 0.12, mid.z)
            slab.eulerAngles = SCNVector3(0, CGFloat(mid.headingRadians), CGFloat(atan2(dy, sqrt(dx * dx + dz * dz))))
            slab.castsShadow = false
            root.addChildNode(slab)

            // Picket fence posts every 5m on both sides
            if Int(dist) % 5 == 0 {
                let nx = sin(mid.headingRadians)
                let nz = cos(mid.headingRadians)
                for side in [-1.0, 1.0] {
                    let postGeo = SCNBox(width: 0.18, height: 0.95, length: 0.18, chamferRadius: 0.02)
                    postGeo.firstMaterial?.diffuse.contents = NSColor(white: 0.94, alpha: 1.0)
                    let post = SCNNode(geometry: postGeo)
                    let offset = side * (Double(trackWidth) * 0.5 + 0.35)
                    post.position = SCNVector3(mid.x + nx * offset, mid.y + 0.45, mid.z + nz * offset)
                    post.castsShadow = true
                    root.addChildNode(post)
                }
            }

            // Lush tall trees on the far backdrop side (-1) only, keeping foreground camera corridor (+1) 100% clear
            if Int(dist) % 15 == 0 {
                let nx = sin(mid.headingRadians)
                let nz = cos(mid.headingRadians)

                let backOffset = -(Double(trackWidth) * 0.5 + 5.5 + Double(Int(dist) % 4))
                let backTree = buildGardenTree(scale: (Int(dist) % 30 == 0) ? 1.25 : 0.95)
                backTree.position = SCNVector3(mid.x + nx * backOffset, mid.y, mid.z + nz * backOffset)
                root.addChildNode(backTree)

                // Low flower bush on foreground side (well below camera sightline)
                let frontOffset = Double(trackWidth) * 0.5 + 2.2
                let bush = SCNSphere(radius: 0.45)
                bush.firstMaterial?.diffuse.contents = (Int(dist) % 30 == 0) ? NSColor.systemPink : NSColor.systemYellow
                let bushNode = SCNNode(geometry: bush)
                bushNode.scale = SCNVector3(1.2, 0.55, 1.2)
                bushNode.position = SCNVector3(mid.x + nx * frontOffset, mid.y + 0.2, mid.z + nz * frontOffset)
                root.addChildNode(bushNode)
            }

            _ = (p0, p1)
            dist = nextDist
        }

        // 3. Starting Gate Arch
        let startPt = course.position3D(atDistanceMeters: 0.0, lane: 4)
        let startArch = buildGantryArch(title: "OH! GNOMES", archColor: NSColor.systemRed, width: trackWidth + 1.0)
        startArch.position = SCNVector3(startPt.x, startPt.y, startPt.z)
        startArch.eulerAngles = SCNVector3(0, CGFloat(startPt.headingRadians), 0)
        root.addChildNode(startArch)

        // 4. Finish Line Gantry
        let finishPt = course.position3D(atDistanceMeters: course.totalDistanceMeters, lane: 4)
        let finishArch = buildGantryArch(title: "FINISH", archColor: NSColor.systemYellow, width: trackWidth + 1.0)
        finishArch.position = SCNVector3(finishPt.x, finishPt.y, finishPt.z)
        finishArch.eulerAngles = SCNVector3(0, CGFloat(finishPt.headingRadians), 0)
        root.addChildNode(finishArch)

        // 5. 3D Obstacle Props
        for obs in course.obstacleZones {
            let pt = course.position3D(atDistanceMeters: obs.locationMeter, lane: 4)
            let prop = buildObstacleProp(type: obs.obstacleType, trackWidth: trackWidth)
            prop.position = SCNVector3(pt.x, pt.y + 0.05, pt.z)
            prop.eulerAngles = SCNVector3(0, CGFloat(pt.headingRadians), 0)
            root.addChildNode(prop)
        }

        return root
    }

    private static func buildGantryArch(title: String, archColor: NSColor, width: CGFloat) -> SCNNode {
        let node = SCNNode()
        let postMat = SCNMaterial()
        postMat.diffuse.contents = NSColor.white

        for side in [-1.0, 1.0] {
            let postGeo = SCNCylinder(radius: 0.22, height: 4.5)
            postGeo.materials = [postMat]
            let post = SCNNode(geometry: postGeo)
            post.position = SCNVector3(0, 2.25, CGFloat(side) * (width / 2.0))
            post.castsShadow = true
            node.addChildNode(post)
        }

        let beamGeo = SCNBox(width: 0.5, height: 0.9, length: width + 0.6, chamferRadius: 0.08)
        beamGeo.firstMaterial?.diffuse.contents = archColor
        let beam = SCNNode(geometry: beamGeo)
        beam.position = SCNVector3(0, 4.5, 0)
        beam.castsShadow = true
        node.addChildNode(beam)

        let textGeo = SCNText(string: title, extrusionDepth: 0.06)
        textGeo.font = NSFont.boldSystemFont(ofSize: 0.55)
        textGeo.firstMaterial?.diffuse.contents = NSColor.white
        let (minB, maxB) = textGeo.boundingBox
        let textNode = SCNNode(geometry: textGeo)
        textNode.position = SCNVector3(-0.3, 4.25, -(maxB.x - minB.x) / 2.0)
        textNode.eulerAngles = SCNVector3(0, -CGFloat.pi / 2.0, 0)
        node.addChildNode(textNode)

        return node
    }

    private static func buildGardenTree(scale: CGFloat) -> SCNNode {
        let tree = SCNNode()
        let trunkGeo = SCNCylinder(radius: 0.35 * scale, height: 2.2 * scale)
        trunkGeo.firstMaterial?.diffuse.contents = NSColor(red: 0.38, green: 0.24, blue: 0.12, alpha: 1.0)
        let trunk = SCNNode(geometry: trunkGeo)
        trunk.position = SCNVector3(0, 1.1 * scale, 0)
        trunk.castsShadow = true
        tree.addChildNode(trunk)

        let foliageGeo = SCNSphere(radius: 1.6 * scale)
        foliageGeo.firstMaterial?.diffuse.contents = NSColor(red: 0.14, green: 0.45, blue: 0.18, alpha: 1.0)
        let foliage = SCNNode(geometry: foliageGeo)
        foliage.position = SCNVector3(0, 2.8 * scale, 0)
        foliage.castsShadow = true
        tree.addChildNode(foliage)
        return tree
    }

    private static func buildObstacleProp(type: ObstacleType, trackWidth: CGFloat) -> SCNNode {
        let node = SCNNode()
        switch type {
        case .springLauncher, .catapultTrap:
            let pad = SCNBox(width: 1.2, height: 0.16, length: trackWidth * 0.85, chamferRadius: 0.05)
            pad.firstMaterial?.diffuse.contents = NSColor.systemYellow
            pad.firstMaterial?.emission.contents = NSColor.orange.withAlphaComponent(0.25)
            node.addChildNode(SCNNode(geometry: pad))

        case .mudPuddle:
            let puddle = SCNCylinder(radius: 2.2, height: 0.08)
            puddle.firstMaterial?.diffuse.contents = NSColor(red: 0.24, green: 0.14, blue: 0.06, alpha: 0.95)
            puddle.firstMaterial?.roughness.contents = 0.2
            node.addChildNode(SCNNode(geometry: puddle))

        case .waterSprinkler, .movingSprinkler:
            let base = SCNCylinder(radius: 0.25, height: 0.5)
            base.firstMaterial?.diffuse.contents = NSColor.systemTeal
            let sprinkler = SCNNode(geometry: base)
            sprinkler.position = SCNVector3(0, 0.25, 0)
            node.addChildNode(sprinkler)

        case .lowHedge:
            let hedge = SCNBox(width: 0.7, height: 0.65, length: trackWidth * 0.88, chamferRadius: 0.15)
            hedge.firstMaterial?.diffuse.contents = NSColor(red: 0.10, green: 0.36, blue: 0.12, alpha: 1.0)
            let hNode = SCNNode(geometry: hedge)
            hNode.position = SCNVector3(0, 0.32, 0)
            hNode.castsShadow = true
            node.addChildNode(hNode)

        case .moleHill:
            let mound = SCNCone(topRadius: 0.2, bottomRadius: 0.9, height: 0.55)
            mound.firstMaterial?.diffuse.contents = NSColor(red: 0.32, green: 0.20, blue: 0.10, alpha: 1.0)
            let mNode = SCNNode(geometry: mound)
            mNode.position = SCNVector3(0, 0.27, 0)
            node.addChildNode(mNode)

        case .snailDistraction:
            // Giant 3D spiral-shelled garden snail on track!
            let shell = SCNSphere(radius: 0.55)
            shell.firstMaterial?.diffuse.contents = NSColor.systemBrown
            let sNode = SCNNode(geometry: shell)
            sNode.position = SCNVector3(0, 0.55, 1.2)
            sNode.castsShadow = true
            node.addChildNode(sNode)

        case .flowerpotDomino:
            for offset in [-2.8, 0.0, 2.8] {
                let pot = SCNCone(topRadius: 0.35, bottomRadius: 0.22, height: 0.55)
                pot.firstMaterial?.diffuse.contents = NSColor(red: 0.76, green: 0.36, blue: 0.20, alpha: 1.0)
                let pNode = SCNNode(geometry: pot)
                pNode.position = SCNVector3(0, 0.28, CGFloat(offset))
                pNode.castsShadow = true
                node.addChildNode(pNode)
            }
        }
        return node
    }
}
