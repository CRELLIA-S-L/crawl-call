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
        // Ground as a 0.4 m slab too (the maintainer's request), its top face at y = 0.
        descriptors.append(box(name: "ground", center: [0, -0.2, 0], size: [24, 0.4, 16]))
        // Upper floor and ramp as 0.4 m slabs, not zero-thickness quads (the maintainer's hypothesis).
        descriptors.append(box(name: "upper", center: [8, ArenaLayout.upperY - 0.2, 0], size: [8, 0.4, 16]))
        descriptors.append(slopedSlab(name: "ramp",
                                      x0: -4, y0: 0, x1: 4, y1: ArenaLayout.upperY,
                                      z0: ArenaLayout.rampZ.lowerBound, z1: ArenaLayout.rampZ.upperBound, thickness: 0.4))
        for (i, c) in ArenaLayout.coverBoxes.enumerated() {
            descriptors.append(box(name: "cover\(i)", center: c, size: ArenaLayout.coverSize))
        }
        // A back wall under the upper floor so nobody walks through the cliff face.
        descriptors.append(box(name: "cliff", center: [4, 1.5, -3], size: [0.2, 3, 10]))

        let renderMesh = try MeshResource.generate(from: descriptors)
        // One descriptor for the navmesh: everything concatenated, so that no part is left out.
        let merged = merge(descriptors)

        var config = NavigationMeshResource.Configuration(
            cellSize: 0.2, cellHeight: 0.1, walkableSlopeAngle: 45,
            characterHeight: 1.8, walkableClimb: 0.4, characterRadius: 0.3)
        config.partitionMethod = .watershed
        let drop = NavigationMeshResource.OffMeshConnection(
            startPoint: ArenaLayout.dropStart, endPoint: ArenaLayout.dropEnd,
            radius: 0.6, isBidirectional: false, label: "drop")
        let nav = try NavigationMeshResource(meshDescriptor: merged, offMeshConnections: [drop], configuration: config)
        nav.markFlagOnOffMeshConnections(offMeshConnectionIndices: [0], flag: ArenaLayout.dropFlag)
        let ys = nav.vertices.map(\.y)
        Telemetry.shared.note(String(format: "navmesh: %d verts, %d polys, y %.2f…%.2f, %d off-mesh",
                                     nav.vertices.count, nav.polygonIndices.count, ys.min() ?? 0, ys.max() ?? 0, nav.offMeshConnections.count))

        // Dump the polygons of the upper level with their extents, to see what the query has to choose from.
        for (i, poly) in nav.polygonIndices.enumerated() {
            let vs = poly.map { nav.vertices[$0] }
            guard let cy = vs.map(\.y).max(), cy > 99 else { continue }
            let xs = vs.map(\.x), zs = vs.map(\.z)
            Telemetry.shared.note(String(format: "poly %d: x %.1f…%.1f z %.1f…%.1f y %.1f", i, xs.min()!, xs.max()!, zs.min()!, zs.max()!, cy))
        }

        let root = Entity()
        root.name = "arena"
        root.components.set(NavigationMeshComponent(navigationMeshes: [nav]))

        // Debug overlay: the navmesh polygons, drawn slightly above the surface.
        var overlay = MeshDescriptor(name: "navOverlay")
        let overlayVerts = nav.vertices.map { $0 + [0, 0.05, 0] }
        var tris: [UInt32] = []
        for poly in nav.polygonIndices where poly.count >= 3 {
            for i in 1..<(poly.count - 1) { tris += [UInt32(poly[0]), UInt32(poly[i]), UInt32(poly[i + 1])] }
        }
        overlay.positions = MeshBuffers.Positions(overlayVerts)
        overlay.primitives = .triangles(tris)
        if let overlayMesh = try? MeshResource.generate(from: [overlay]) {
            var m = UnlitMaterial(color: UIColor(red: 0.1, green: 0.9, blue: 0.3, alpha: 0.35))
            m.blending = .transparent(opacity: 0.35)
            let e = ModelEntity(mesh: overlayMesh, materials: [m])
            e.name = "navOverlay"
            root.addChild(e)
        }

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

    private static func merge(_ ds: [MeshDescriptor]) -> MeshDescriptor {
        var out = MeshDescriptor(name: "merged")
        var pos: [SIMD3<Float>] = []
        var tris: [UInt32] = []
        for d in ds {
            let base = UInt32(pos.count)
            pos += Array(d.positions)
            if case .triangles(let t)? = d.primitives { tris += t.map { $0 + base } }
        }
        out.positions = MeshBuffers.Positions(pos)
        out.primitives = .triangles(tris)
        return out
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

    /// A ramp with thickness: the top face plus a bottom face and sides, closed.
    private static func slopedSlab(name: String, x0: Float, y0: Float, x1: Float, y1: Float, z0: Float, z1: Float, thickness t: Float) -> MeshDescriptor {
        var d = MeshDescriptor(name: name)
        let top: [SIMD3<Float>] = [[x0, y0, z0], [x1, y1, z0], [x1, y1, z1], [x0, y0, z1]]
        let bottom = top.map { $0 - SIMD3<Float>(0, t, 0) }
        let p = top + bottom
        let n = simd_normalize(SIMD3<Float>(-(y1 - y0), x1 - x0, 0))
        let faces: [([Int], SIMD3<Float>)] = [
            ([0, 3, 2, 1], n), ([4, 5, 6, 7], -n),
            ([0, 1, 5, 4], [0, 0, -1]), ([3, 7, 6, 2], [0, 0, 1]),
            ([0, 4, 7, 3], [-1, 0, 0]), ([1, 2, 6, 5], [1, 0, 0]),
        ]
        var positions: [SIMD3<Float>] = []; var normals: [SIMD3<Float>] = []; var tris: [UInt32] = []
        for (idx, nn) in faces {
            let base = UInt32(positions.count)
            for i in idx { positions.append(p[i]); normals.append(nn) }
            tris += [base, base + 1, base + 2, base, base + 2, base + 3]
        }
        d.positions = MeshBuffers.Positions(positions); d.normals = MeshBuffers.Normals(normals); d.primitives = .triangles(tris)
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
