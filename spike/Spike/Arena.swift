// Spike checks 1 & 2 — the arena: two floors, a ramp, a ledge with a one-way drop,
// cover boxes; static collision for the snake's character controller; the navigation
// grid of ADR-0016 for the bots, built from the same layout. Throwaway code (spike/README.md).
import RealityKit
import UIKit

enum ArenaLayout {
    static let groundMin = SIMD3<Float>(-12, 0, -8)
    static let groundMax = SIMD3<Float>(12, 0, 8)
    static let upperY: Float = 3
    static let upperMin = SIMD3<Float>(4, 3, -8)
    static let upperMax = SIMD3<Float>(12, 3, 8)
    // Ramp from ground (x=-4) to upper (x=4), z in [2, 6]
    static let rampX0: Float = -4, rampX1: Float = 4
    static let rampZ: ClosedRange<Float> = 2...6
    // The ledge: the upper floor's edge at x=4 for z < 2 is a 3 m cliff; one-way drop for the snake.
    static let dropStart = SIMD3<Float>(4.75, 3, -4)
    static let dropEnd = SIMD3<Float>(3.0, 0, -4)
    static let dropFlag = 1
    static let coverBoxes: [SIMD3<Float>] = [
        [-8, 0.6, -5], [-6, 0.6, 3], [-1, 0.6, -2], [1, 0.6, 5], [-9, 0.6, 6], [0, 0.6, -6],
    ]
    static let coverSize = SIMD3<Float>(1.6, 1.2, 0.6)
    static let cliffCenter = SIMD3<Float>(4, 1.5, -3)
    static let cliffSize = SIMD3<Float>(0.2, 3, 10)
    static let slab: Float = 0.4
    static let snakeStart = SIMD3<Float>(-10, 0, 0)
    static let cellSize: Float = 0.5
    static let stepLimit: Float = 0.4
    static let characterHeight: Float = 1.8

    static func rampHeight(x: Float) -> Float { max(0, min(upperY, (x - rampX0) / (rampX1 - rampX0) * upperY)) }
}

@MainActor
enum ArenaBuilder {
    struct Built {
        let root: Entity
        let grid: NavGrid
    }

    static func build() throws -> Built {
        // Render geometry, all slabs.
        var descriptors: [MeshDescriptor] = []
        descriptors.append(box(name: "ground", center: [0, -ArenaLayout.slab / 2, 0], size: [24, ArenaLayout.slab, 16]))
        descriptors.append(box(name: "upper", center: [8, ArenaLayout.upperY - ArenaLayout.slab / 2, 0], size: [8, ArenaLayout.slab, 16]))
        descriptors.append(slopedSlab(name: "ramp", x0: ArenaLayout.rampX0, y0: 0, x1: ArenaLayout.rampX1, y1: ArenaLayout.upperY,
                                      z0: ArenaLayout.rampZ.lowerBound, z1: ArenaLayout.rampZ.upperBound, thickness: ArenaLayout.slab))
        for (i, c) in ArenaLayout.coverBoxes.enumerated() {
            descriptors.append(box(name: "cover\(i)", center: c, size: ArenaLayout.coverSize))
        }
        descriptors.append(box(name: "cliff", center: ArenaLayout.cliffCenter, size: ArenaLayout.cliffSize))
        let renderMesh = try MeshResource.generate(from: descriptors)

        let root = Entity()
        root.name = "arena"
        let floorMaterial = SimpleMaterial(color: UIColor(red: 0.86, green: 0.80, blue: 0.68, alpha: 1), isMetallic: false)
        let model = ModelEntity(mesh: renderMesh, materials: [floorMaterial])
        model.name = "arenaModel"

        // Static collision for the character controller: the same slabs as shapes.
        var shapes: [ShapeResource] = []
        shapes.append(.generateBox(size: [24, ArenaLayout.slab, 16]).offsetBy(translation: [0, -ArenaLayout.slab / 2, 0]))
        shapes.append(.generateBox(size: [8, ArenaLayout.slab, 16]).offsetBy(translation: [8, ArenaLayout.upperY - ArenaLayout.slab / 2, 0]))
        let rampLen = ((ArenaLayout.rampX1 - ArenaLayout.rampX0) * (ArenaLayout.rampX1 - ArenaLayout.rampX0) + ArenaLayout.upperY * ArenaLayout.upperY).squareRoot()
        let rampAngle = atan2(ArenaLayout.upperY, ArenaLayout.rampX1 - ArenaLayout.rampX0)
        let rampMid = SIMD3<Float>((ArenaLayout.rampX0 + ArenaLayout.rampX1) / 2, ArenaLayout.upperY / 2,
                                   (ArenaLayout.rampZ.lowerBound + ArenaLayout.rampZ.upperBound) / 2)
        // The box's top face must be the ramp surface: shift down by half the thickness along the ramp normal.
        let rampNormal = SIMD3<Float>(-sin(rampAngle), cos(rampAngle), 0)
        shapes.append(.generateBox(size: [rampLen, ArenaLayout.slab, ArenaLayout.rampZ.upperBound - ArenaLayout.rampZ.lowerBound])
            .offsetBy(rotation: simd_quatf(angle: rampAngle, axis: [0, 0, 1]), translation: rampMid - rampNormal * (ArenaLayout.slab / 2)))
        for c in ArenaLayout.coverBoxes { shapes.append(.generateBox(size: ArenaLayout.coverSize).offsetBy(translation: c)) }
        shapes.append(.generateBox(size: ArenaLayout.cliffSize).offsetBy(translation: ArenaLayout.cliffCenter))
        // Arena border walls so nobody walks off the world.
        let walls: [(SIMD3<Float>, SIMD3<Float>)] = [([-12.1, 1, 0], [0.2, 2, 16.4]), ([12.1, 1, 0], [0.2, 2, 16.4]),
                                                     ([0, 1, -8.1], [24.4, 2, 0.2]), ([0, 1, 8.1], [24.4, 2, 0.2])]
        for (c, s) in walls { shapes.append(.generateBox(size: s).offsetBy(translation: c)) }
        model.components.set(CollisionComponent(shapes: shapes, isStatic: true))
        root.addChild(model)

        // The navigation grid from the same layout.
        let grid = NavGrid(minX: ArenaLayout.groundMin.x, minZ: ArenaLayout.groundMin.z,
                           maxX: ArenaLayout.groundMax.x, maxZ: ArenaLayout.groundMax.z,
                           cellSize: ArenaLayout.cellSize, stepLimit: ArenaLayout.stepLimit)
        grid.addSurface(minX: ArenaLayout.groundMin.x, minZ: ArenaLayout.groundMin.z, maxX: ArenaLayout.groundMax.x, maxZ: ArenaLayout.groundMax.z, heightAt: { _, _ in 0 })
        grid.addSurface(minX: ArenaLayout.rampX0, minZ: ArenaLayout.rampZ.lowerBound, maxX: ArenaLayout.rampX1, maxZ: ArenaLayout.rampZ.upperBound, heightAt: { x, _ in ArenaLayout.rampHeight(x: x) })
        grid.addSurface(minX: ArenaLayout.upperMin.x, minZ: ArenaLayout.upperMin.z, maxX: ArenaLayout.upperMax.x, maxZ: ArenaLayout.upperMax.z, heightAt: { _, _ in ArenaLayout.upperY })
        for c in ArenaLayout.coverBoxes {
            let h = ArenaLayout.coverSize / 2 + 0.3   // a bot's radius of clearance around the box
            grid.block(minX: c.x - h.x, minZ: c.z - h.z, maxX: c.x + h.x, maxZ: c.z + h.z, bottom: 0, top: 1)
        }
        let ch = ArenaLayout.cliffSize / 2 + 0.3
        grid.block(minX: ArenaLayout.cliffCenter.x - ch.x, minZ: ArenaLayout.cliffCenter.z - ch.z,
                   maxX: ArenaLayout.cliffCenter.x + ch.x, maxZ: ArenaLayout.cliffCenter.z + ch.z, bottom: 0, top: 2.9)
        // Keep bots off the upper floor's cliff edge (a radius from the drop).
        grid.block(minX: 4, minZ: -8, maxX: 4.4, maxZ: 1.9, bottom: 2.9, top: 3.1)
        grid.applyClearance(ArenaLayout.characterHeight)
        grid.addTransition(from: ArenaLayout.dropStart, to: ArenaLayout.dropEnd, flag: ArenaLayout.dropFlag)

        var walkable = 0, blocked = 0, twoLevel = 0
        for c in 0..<grid.cellCount {
            let r = grid.surfaces(ofCell: c)
            walkable += r.filter { grid.walkable[$0] }.count; blocked += r.filter { !grid.walkable[$0] }.count
            if r.count > 1 { twoLevel += 1 }
        }
        Telemetry.shared.note("grid \(grid.nx)×\(grid.nz): \(walkable) walkable, \(blocked) blocked, \(twoLevel) cells with two levels")

        // Debug overlay: walkable cells green, blocked red, a little above each surface.
        var pos: [SIMD3<Float>] = []; var tris: [UInt32] = []
        var bpos: [SIMD3<Float>] = []; var btris: [UInt32] = []
        let e: Float = ArenaLayout.cellSize * 0.42
        for iz in 0..<grid.nz {
            for ix in 0..<grid.nx {
                let cell = ix + iz * grid.nx
                for k in grid.surfaces(ofCell: cell) {
                    let c = grid.center(GridNode(ix: ix, iz: iz, level: k - cell * NavGrid.maxLevels)) + [0, 0.06, 0]
                    let quad: [SIMD3<Float>] = [c + [-e, 0, -e], c + [e, 0, -e], c + [e, 0, e], c + [-e, 0, e]]
                    if grid.walkable[k] {
                        let b = UInt32(pos.count); pos += quad; tris += [b, b + 2, b + 1, b, b + 3, b + 2]
                    } else {
                        let b = UInt32(bpos.count); bpos += quad; btris += [b, b + 2, b + 1, b, b + 3, b + 2]
                    }
                }
            }
        }
        var overlay = MeshDescriptor(name: "gridOverlay")
        overlay.positions = MeshBuffers.Positions(pos); overlay.primitives = .triangles(tris)
        var blockedOverlay = MeshDescriptor(name: "gridBlocked")
        blockedOverlay.positions = MeshBuffers.Positions(bpos); blockedOverlay.primitives = .triangles(btris)
        for (d, color) in [(overlay, UIColor(red: 0.1, green: 0.9, blue: 0.3, alpha: 0.35)), (blockedOverlay, UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 0.35))] {
            if let m = try? MeshResource.generate(from: [d]) {
                var mat = UnlitMaterial(color: color)
                mat.blending = .transparent(opacity: 0.35)
                let ent = ModelEntity(mesh: m, materials: [mat])
                ent.name = d.name
                root.addChild(ent)
            }
        }
        return Built(root: root, grid: grid)
    }

    // MARK: geometry helpers (y-up)

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
        let faces: [([Int], SIMD3<Float>)] = [
            ([0, 3, 2, 1], [0, 0, -1]), ([4, 5, 6, 7], [0, 0, 1]),
            ([0, 4, 7, 3], [-1, 0, 0]), ([1, 2, 6, 5], [1, 0, 0]),
            ([3, 7, 6, 2], [0, 1, 0]), ([0, 1, 5, 4], [0, -1, 0]),
        ]
        var positions: [SIMD3<Float>] = []; var normals: [SIMD3<Float>] = []; var tris: [UInt32] = []
        for (idx, n) in faces {
            let base = UInt32(positions.count)
            for i in idx { positions.append(p[i]); normals.append(n) }
            tris += [base, base + 1, base + 2, base, base + 2, base + 3]
        }
        d.positions = MeshBuffers.Positions(positions); d.normals = MeshBuffers.Normals(normals); d.primitives = .triangles(tris)
        return d
    }
}
