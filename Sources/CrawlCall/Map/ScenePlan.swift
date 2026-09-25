// Where every module of a parsed map ends up in metres. FR-TOOL-020 asks for the
// kit's module placed for each cell at the coordinates the specification gives it;
// this is that arithmetic, kept apart from RealityKit so it can be checked by a test
// rather than by eye.
//
// A cell's coordinates come from the navigation-graph cell size of the tuning
// configuration (IF-MAP-020) and the kit's floor height, so the graph's cells and the
// geometry cannot drift apart.
//
// implements: FR-TOOL-020, FR-MAP-090, FR-GREENHOLM-010, FR-MAP-150
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
        /// The floor of the map this piece was placed on, carried rather than
        /// measured: a module's height says nothing about which floor it belongs to
        /// — a stair rises to its floor from the one below, a wall stands on its own
        /// — and FR-VIEW-140 asks what is above the head, not what is high up.
        let level: Int
    }

    /// The widest gap between the surfaces of two cells a walker can step between,
    /// in metres. FR-MAP-090 asks that this stay within the tuning's tail-gap
    /// tolerance, because a tail rests on surfaces and falls through what is missing.
    ///
    /// Measured between the facing edges of the two pieces, so a kit whose floor
    /// module is narrower than a cell shows up here rather than under the snake.
    func widestGap(along graph: NavigationGraph) -> Double {
        var widest: Double = .zero
        for node in graph.nodes {
            guard let here = surface(at: node, height: graph.height(of: node, floorHeight: floorHeight)) else { continue }
            for next in graph.neighbours(of: node) where next.floor == node.floor {
                guard let there = surface(at: next, height: graph.height(of: next, floorHeight: floorHeight))
                else { continue }
                let alongX = next.x != node.x
                let centres = alongX ? abs(there.centre.x - here.centre.x) : abs(there.centre.z - here.centre.z)
                let halves = alongX ? (here.size.x + there.size.x) * Geometry.half
                                    : (here.size.z + there.size.z) * Geometry.half
                widest = max(widest, centres - halves)
            }
        }
        return widest
    }

    /// The walkable piece a cell stands on, if the plan placed one there, its top at
    /// `height` — the node's, which on a flight is not its floor's (FR-MAP-150).
    func surface(at node: NavigationGraph.Node, height top: Double) -> Piece? {
        let x = Double(node.x) * cellSize
        let z = Double(node.z) * cellSize
        return pieces.first { piece in
            abs(piece.centre.x - x) < Geometry.samePosition && abs(piece.centre.z - z) < Geometry.samePosition
                && abs(piece.centre.y + piece.size.y * Geometry.half - top) < Geometry.samePosition
        }
    }

    /// The box the whole map sits in, which is what a camera with nothing to follow
    /// has to aim at.
    struct Bounds: Equatable {
        let lowest: SIMD3<Double>
        let highest: SIMD3<Double>
        var centre: SIMD3<Double> { (lowest + highest) * Geometry.half }
        var extent: SIMD3<Double> { highest - lowest }
    }

    let pieces: [Piece]
    let cellSize: Double
    let floorHeight: Double
    /// Which pieces cover which cells, for questions about a small stretch of the map.
    let index: PieceIndex

    init(pieces: [Piece], cellSize: Double, floorHeight: Double) {
        self.pieces = pieces
        self.cellSize = cellSize
        self.floorHeight = floorHeight
        self.index = PieceIndex(pieces: pieces, cellSize: cellSize)
    }

    /// The underside of the lowest floor: where its walking surface is, less the
    /// thinnest piece that surface is made of. Not the lowest point of the plan, which
    /// a stair sunk below its floor can reach; this is the level the arena stands at,
    /// which a setting lays its ground to (FR-GREENHOLM-010). Zero for an empty plan.
    var underside: Double {
        guard let lowest = pieces.map(\.level).min() else { return .zero }
        let surface = Double(lowest) * floorHeight
        let slabs = pieces.filter { $0.level == lowest && abs($0.centre.y + $0.size.y * Geometry.half - surface) < Geometry.samePosition }
        return surface - (slabs.map(\.size.y).min() ?? .zero)
    }

    /// Empty where there are no pieces, so a caller need not special-case an empty map.
    var bounds: Bounds {
        guard let first = pieces.first else { return Bounds(lowest: .zero, highest: .zero) }
        var low = first.centre - first.size * Geometry.half
        var high = first.centre + first.size * Geometry.half
        for piece in pieces.dropFirst() {
            low = pointwiseMin(low, piece.centre - piece.size * Geometry.half)
            high = pointwiseMax(high, piece.centre + piece.size * Geometry.half)
        }
        return Bounds(lowest: low, highest: high)
    }

    static func make(map: MapSpecification, kit: Kit, cellSize: Double) -> ScenePlan {
        var pieces: [Piece] = []
        for placement in map.placements {
            // A step is drawn as an arrow, which is no key of the legend: its module is
            // the kit's step module (FR-MAP-150).
            guard let module = placement.step != nil ? kit.step : kit.module(for: placement.character),
                  module.size.count == SIMD3<Double>.scalarCount else { continue }
            let size = SIMD3<Double>(module.size)
            let elevation = Double(placement.floor) * kit.floorHeight
            // A step is a block from under its floor's surface — as deep as the floor
            // slab, so the two meet — up to its own height on the flight (FR-MAP-150).
            // A box, like every other piece, so that sight, collision and see-through
            // take it as they take a crate (ADR-0033).
            if placement.step != nil {
                let top = map.height(of: placement)
                let slab = kit.floor.flatMap { $0.size.count == SIMD3<Double>.scalarCount ? SIMD3<Double>($0.size).y : nil }
                let bottom = elevation - (slab ?? .zero)
                pieces.append(Piece(module: module.name,
                                    size: SIMD3(size.x, top - bottom, size.z),
                                    centre: SIMD3(Double(placement.x) * cellSize, (top + bottom) * Geometry.half,
                                                  Double(placement.z) * cellSize),
                                    colour: SIMD3<Double>(module.colour),
                                    level: placement.floor))
                continue
            }
            // A cell holds one module, so a cell holding a wall holds no floor and the
            // scene would have a hole under it. The floor is implied (FR-TOOL-020); a
            // deliberate hole is a different thing and a map will say so (FR-MAP-110).
            if !module.walkable, let floor = kit.floor, floor.size.count == SIMD3<Double>.scalarCount {
                let floorSize = SIMD3<Double>(floor.size)
                pieces.append(Piece(module: floor.name,
                                    size: floorSize,
                                    centre: SIMD3(Double(placement.x) * cellSize,
                                                  elevation - floorSize.y * Geometry.half,
                                                  Double(placement.z) * cellSize),
                                    colour: SIMD3<Double>(floor.colour),
                                    level: placement.floor))
            }
            // A walkable module *is* the surface, so its top sits at the floor's
            // elevation; anything else stands on that surface, sunk into it by
            // `MapGrid.surfaceOverlap` so that its underside and the slab's top are not the
            // same plane — two coplanar faces fight for the depth buffer.
            let y = module.walkable
                ? elevation - size.y * Geometry.half
                : elevation + size.y * Geometry.half - MapGrid.surfaceOverlap
            pieces.append(Piece(module: module.name,
                                size: size,
                                centre: SIMD3(Double(placement.x) * cellSize, y, Double(placement.z) * cellSize),
                                colour: SIMD3<Double>(module.colour),
                                level: placement.floor))
        }
        return ScenePlan(pieces: pieces, cellSize: cellSize, floorHeight: kit.floorHeight)
    }
}
