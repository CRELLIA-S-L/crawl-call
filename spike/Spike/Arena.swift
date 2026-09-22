// Spike check 1 & 2 — the arena: two floors, a ramp, a ledge with a one-way drop,
// some cover boxes; one navigation mesh built from the same geometry.
// Throwaway code: measures, never ships (spike/README.md).
import RealityKit
import UIKit

enum ArenaLayout {
    // Ground floor
    static let groundMin = SIMD3<Float>(-12, 0, -8)
    static let groundMax = SIMD3<Float>(12, 0, 8)
    // Upper floor on the right, 3 m up
    static let upperY: Float = 3
    static let upperMin = SIMD3<Float>(4, 3, -8)
    static let upperMax = SIMD3<Float>(12, 3, 8)
    // Ramp from ground (x=-4) to upper (x=4), z in [2, 6]
    static let rampZ: ClosedRange<Float> = 2...6
    // The ledge: upper floor edge at x=4 for z < 2 is a 3 m cliff.
    static let dropStart = SIMD3<Float>(4.4, 3, -4)
    static let dropEnd = SIMD3<Float>(2.8, 0, -4)
    static let coverBoxes: [SIMD3<Float>] = [
        [-8, 0.6, -5], [-6, 0.6, 3], [-1, 0.6, -2], [1, 0.6, 5], [-9, 0.6, 6], [0, 0.6, -6],
    ]
    static let coverSize = SIMD3<Float>(1.6, 1.2, 0.6)
    static let snakeStart = SIMD3<Float>(-10, 0, 0)

    /// The flag on the drop connection: bots ignore it, the snake does not.
    static let dropFlag = NavigationMeshResource.Flag(1)
}

/// Builds render meshes and the navigation mesh from the same descriptors.
@MainActor
enum ArenaBuilder {
    struct Built {
        let root: Entity
        let navMesh: NavigationMeshResource
        let tapTargets: [Entity]
    }

    static func build() throws -> Built {
        var descriptors: [MeshDescriptor] = []
        descriptors.append(quad(name: "ground", ArenaLayout.groundMin, ArenaLayout.groundMax))
        descriptors.append(quad(name: "upper", ArenaLayout.upperMin, ArenaLayout.upperMax))
        // Ramp: a sloped quad from (-4, 0) to (4, 3) over z in rampZ.
        descriptors.append(slopedQuad(name: "ramp",
                                      x0: -4, y0: 0, x1: 4, y1: ArenaLayout.upperY,
                                      z0: ArenaLayout.rampZ.lowerBound, z1: ArenaLayout.rampZ.upperBound))
        for (i, c) in ArenaLayout.coverBoxes.enumerated() {
            descriptors.append(box(name: "cover\(i)", center: c, size: ArenaLayout.coverSize))
        }
        // A back wall under the upper floor so nobody walks through the cliff face.
        descriptors.append(box(name: "cliff", center: [4, 1.5, -3], size: [0.2, 3, 10]))

        let renderMesh = try MeshResource.generate(from: descriptors)

        var config = NavigationMeshResource.Configuration(
            cellSize: 0.2, cellHeight: 0.1, walkableSlopeAngle: 45,
            characterHeight: 1.8, walkableClimb: 0.4, characterRadius: 0.3)
        config.partitionMethod = .watershed
        let drop = NavigationMeshResource.OffMeshConnection(
            startPoint: ArenaLayout.dropStart, endPoint: ArenaLayout.dropEnd,
            radius: 0.6, isBidirectional: false, label: "drop")
        let nav = try NavigationMeshResource(mesh: renderMesh, offMeshConnections: [drop], configuration: config)
        nav.markFlagOnOffMeshConnections(offMeshConnectionIndices: [0], flag: ArenaLayout.dropFlag)

        let root = Entity()
        root.name = "arena"
        root.components.set(NavigationMeshComponent(navigationMeshes: [nav]))

        let floorMaterial = SimpleMaterial(color: UIColor(red: 0.86, green: 0.80, blue: 0.68, alpha: 1), isMetallic: false)
        let model = ModelEntity(mesh: renderMesh, materials: [floorMaterial])
        model.name = "arenaModel"
        root.addChild(model)

        // Tap targets: thin collision boxes over each floor so a tap yields a 3D point.
        var targets: [Entity] = []
        for (name, lo, hi) in [("groundTap", ArenaLayout.groundMin, ArenaLayout.groundMax),
                               ("upperTap", ArenaLayout.upperMin, ArenaLayout.upperMax)] {
            let size = SIMD3<Float>(hi.x - lo.x, 0.05, hi.z - lo.z)
            let e = Entity()
            e.name = name
            e.position = (lo + hi) / 2
            e.components.set(CollisionComponent(shapes: [.generateBox(size: size)]))
            e.components.set(InputTargetComponent())
            root.addChild(e)
            targets.append(e)
        }
        // The ramp gets one too, tilted.
        let ramp = Entity()
        ramp.name = "rampTap"
        let rampLen = Float(8 * 8 + 3 * 3).squareRoot()
        ramp.position = [0, ArenaLayout.upperY / 2, (ArenaLayout.rampZ.lowerBound + ArenaLayout.rampZ.upperBound) / 2]
        ramp.orientation = simd_quatf(angle: -atan2(ArenaLayout.upperY, 8), axis: [0, 0, 1])
        ramp.components.set(CollisionComponent(shapes: [.generateBox(size: [rampLen, 0.05, ArenaLayout.rampZ.upperBound - ArenaLayout.rampZ.lowerBound])]))
        ramp.components.set(InputTargetComponent())
        root.addChild(ramp)
        targets.append(ramp)

        return Built(root: root, navMesh: nav, tapTargets: targets)
    }

    // MARK: geometry helpers (y-up, counter-clockwise seen from above)

    private static func quad(name: String, _ lo: SIMD3<Float>, _ hi: SIMD3<Float>) -> MeshDescriptor {
        var d = MeshDescriptor(name: name)
        let y = lo.y
        d.positions = MeshBuffers.Positions([
            [lo.x, y, lo.z], [hi.x, y, lo.z], [hi.x, y, hi.z], [lo.x, y, hi.z],
        ])
        d.normals = MeshBuffers.Normals([[0, 1, 0], [0, 1, 0], [0, 1, 0], [0, 1, 0]])
        d.primitives = .triangles([0, 2, 1, 0, 3, 2])
        return d
    }

    private static func slopedQuad(name: String, x0: Float, y0: Float, x1: Float, y1: Float, z0: Float, z1: Float) -> MeshDescriptor {
        var d = MeshDescriptor(name: name)
        d.positions = MeshBuffers.Positions([
            [x0, y0, z0], [x1, y1, z0], [x1, y1, z1], [x0, y0, z1],
        ])
        let n = simd_normalize(SIMD3<Float>(-(y1 - y0), x1 - x0, 0))
        d.normals = MeshBuffers.Normals([n, n, n, n])
        d.primitives = .triangles([0, 2, 1, 0, 3, 2])
        return d
    }

    private static func box(name: String, center c: SIMD3<Float>, size s: SIMD3<Float>) -> MeshDescriptor {
        var d = MeshDescriptor(name: name)
        let h = s / 2
        let p: [SIMD3<Float>] = [
            c + [-h.x, -h.y, -h.z], c + [h.x, -h.y, -h.z], c + [h.x, h.y, -h.z], c + [-h.x, h.y, -h.z],
            c + [-h.x, -h.y, h.z], c + [h.x, -h.y, h.z], c + [h.x, h.y, h.z], c + [-h.x, h.y, h.z],
        ]
        // Six faces, two triangles each, outward-facing.
        let faces: [([Int], SIMD3<Float>)] = [
            ([0, 3, 2, 1], [0, 0, -1]), ([4, 5, 6, 7], [0, 0, 1]),
            ([0, 4, 7, 3], [-1, 0, 0]), ([1, 2, 6, 5], [1, 0, 0]),
            ([3, 7, 6, 2], [0, 1, 0]), ([0, 1, 5, 4], [0, -1, 0]),
        ]
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var tris: [UInt32] = []
        for (idx, n) in faces {
            let base = UInt32(positions.count)
            for i in idx { positions.append(p[i]); normals.append(n) }
            tris += [base, base + 1, base + 2, base, base + 2, base + 3]
        }
        d.positions = MeshBuffers.Positions(positions)
        d.normals = MeshBuffers.Normals(normals)
        d.primitives = .triangles(tris)
        return d
    }
}
