// Where every module of a parsed map ends up in metres. FR-TOOL-020 asks for the
// kit's module placed for each cell at the coordinates the specification gives it;
// this is that arithmetic, kept apart from RealityKit so it can be checked by a test
// rather than by eye.
//
// A cell's coordinates come from the navigation-graph cell size of the tuning
// configuration (IF-MAP-020) and the kit's floor height, so the graph's cells and the
// geometry cannot drift apart.
//
// implements: FR-TOOL-020
import Foundation

struct ScenePlan: Equatable {
    struct Piece: Equatable {
        let module: String
        /// Width, height and depth in metres.
        let size: SIMD3<Double>
        /// The centre of the box, in metres, with y up.
        let centre: SIMD3<Double>
        /// Red, green and blue in 0…1, as the kit's legend gives them.
        let colour: SIMD3<Double>
    }

    /// The box the whole map sits in, which is what a camera with nothing to follow
    /// has to aim at.
    struct Bounds: Equatable {
        let lowest: SIMD3<Double>
        let highest: SIMD3<Double>
        var centre: SIMD3<Double> { (lowest + highest) / 2 }
        var extent: SIMD3<Double> { highest - lowest }
    }

    let pieces: [Piece]
    let cellSize: Double
    let floorHeight: Double

    /// Empty where there are no pieces, so a caller need not special-case an empty map.
    var bounds: Bounds {
        guard let first = pieces.first else { return Bounds(lowest: .zero, highest: .zero) }
        var low = first.centre - first.size / 2
        var high = first.centre + first.size / 2
        for piece in pieces.dropFirst() {
            low = SIMD3(min(low.x, piece.centre.x - piece.size.x / 2),
                        min(low.y, piece.centre.y - piece.size.y / 2),
                        min(low.z, piece.centre.z - piece.size.z / 2))
            high = SIMD3(max(high.x, piece.centre.x + piece.size.x / 2),
                         max(high.y, piece.centre.y + piece.size.y / 2),
                         max(high.z, piece.centre.z + piece.size.z / 2))
        }
        return Bounds(lowest: low, highest: high)
    }

    /// How far a standing module is sunk into the surface it stands on, in metres.
    /// Small enough to be invisible at a cell of half a metre, large enough that no
    /// two faces end up in the same plane.
    static let surfaceOverlap = 0.01

    static func make(map: MapSpecification, kit: Kit, cellSize: Double) -> ScenePlan {
        var pieces: [Piece] = []
        for placement in map.placements {
            guard let module = kit.module(for: placement.character), module.size.count == 3 else { continue }
            let size = SIMD3(module.size[0], module.size[1], module.size[2])
            let elevation = Double(placement.floor) * kit.floorHeight
            // A cell holds one module, so a cell holding a wall holds no floor and the
            // scene would have a hole under it. The floor is implied (FR-TOOL-020); a
            // deliberate hole is a different thing and a map will say so (FR-MAP-110).
            if !module.walkable, let floor = kit.floor, floor.size.count == 3 {
                let floorSize = SIMD3(floor.size[0], floor.size[1], floor.size[2])
                pieces.append(Piece(module: floor.name,
                                    size: floorSize,
                                    centre: SIMD3(Double(placement.x) * cellSize,
                                                  elevation - floorSize.y / 2,
                                                  Double(placement.z) * cellSize),
                                    colour: SIMD3(floor.colour[0], floor.colour[1], floor.colour[2])))
            }
            // A walkable module *is* the surface, so its top sits at the floor's
            // elevation; anything else stands on that surface, sunk into it by
            // `surfaceOverlap` so that its underside and the slab's top are not the
            // same plane — two coplanar faces fight for the depth buffer.
            let y = module.walkable
                ? elevation - size.y / 2
                : elevation + size.y / 2 - Self.surfaceOverlap
            pieces.append(Piece(module: module.name,
                                size: size,
                                centre: SIMD3(Double(placement.x) * cellSize, y, Double(placement.z) * cellSize),
                                colour: SIMD3(module.colour[0], module.colour[1], module.colour[2])))
        }
        return ScenePlan(pieces: pieces, cellSize: cellSize, floorHeight: kit.floorHeight)
    }
}
