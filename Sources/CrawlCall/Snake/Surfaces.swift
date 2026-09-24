// Where the snake's head may be, in metres, answered from the same navigation graph
// the bots path over and the same tuning numbers they are measured by (FR-MAP-025) —
// and how close to what stands on that ground its body may come, answered from the
// boxes the scene is built from (ADR-0021).
//
// implements: FR-MAP-025, FR-SNAKE-010, FR-SNAKE-020, FR-SNAKE-220
import Foundation

struct Surfaces {
    let graph: NavigationGraph
    let cellSize: Double
    let floorHeight: Double
    /// The largest drop the head may take and still call it a path (IF-MAP-020).
    let maximumDropHeight: Double
    /// How wide the body is, which is how close to a wall the head may come.
    let bodyRadius: Double
    /// The tallest step the head may climb; with the stage-1 grid nothing is stepped,
    /// and it is read here so that snake and graph cannot disagree later.
    let stepHeight: Double
    /// The steepest slope the head may take, read for the same reason.
    let slopeAngle: Double
    /// The cells something stands in that the head cannot walk through. The graph
    /// cannot tell these from thin air — both are simply not walkable — and the
    /// difference is the whole of it: air is a ledge to drop from, a wall is a wall
    /// (FR-SNAKE-010).
    private let occupied: Set<NavigationGraph.Node>
    /// What the body cannot pass: every module the map places that is not walkable,
    /// as the box the scene is built from. A walkable module is ground however tall
    /// its box — a stair is walked up, not bumped into (ADR-0021).
    private let obstacles: [(lowest: SIMD3<Double>, highest: SIMD3<Double>)]

    init(graph: NavigationGraph, kit: Kit, tuning: TuningConfiguration, map: MapSpecification) {
        self.occupied = Set(map.placements.filter { !$0.walkable }
            .map { NavigationGraph.Node(floor: $0.floor, x: $0.x, z: $0.z) })
        let solid = Set(kit.modules.values.filter { !$0.walkable }.map(\.name))
        self.obstacles = ScenePlan.make(map: map, kit: kit, cellSize: tuning.navigationGraphCellSize).pieces
            .filter { solid.contains($0.module) }
            .map { (lowest: $0.centre - $0.size * Geometry.half, highest: $0.centre + $0.size * Geometry.half) }
        self.graph = graph
        self.cellSize = tuning.navigationGraphCellSize
        self.floorHeight = kit.floorHeight
        self.maximumDropHeight = tuning.maximumDropHeight
        self.bodyRadius = tuning.bodyRadius
        self.stepHeight = tuning.stepHeight
        self.slopeAngle = tuning.slopeAngle
    }

    /// The cell a position falls in. Cells are centred on their coordinates, so the
    /// nearest index is the one the position belongs to.
    func cell(of position: SIMD3<Double>, floor: Int) -> NavigationGraph.Node {
        NavigationGraph.Node(floor: floor,
                             x: Int((position.x / cellSize).rounded()),
                             z: Int((position.z / cellSize).rounded()))
    }

    /// The height of a floor's walking surface.
    func elevation(of floor: Int) -> Double { Double(floor) * floorHeight }

    func isWalkable(_ position: SIMD3<Double>, floor: Int) -> Bool {
        graph.isWalkable(cell(of: position, floor: floor))
    }

    /// The floor a declared transition leads down to from this cell, if there is one.
    /// A transition is an edge and an edge has two ends: the bots walk it either way
    /// and so does the snake, which is what keeps a balcony from being a trap.
    func descent(at position: SIMD3<Double>, from floor: Int) -> Int? {
        let here = cell(of: position, floor: floor)
        return graph.neighbours(of: here)
            .filter { $0.x == here.x && $0.z == here.z && $0.floor < floor }
            .map(\.floor)
            .max()
    }

    /// The floor a declared transition leads up to from this cell, if there is one.
    /// A transition is an edge of the graph between the same cell on two floors
    /// (FR-MAP-020), which is what a map's `transition` line becomes — so the stairs
    /// the head climbs and the edge the bots path along are the same thing, said
    /// once.
    func rise(at position: SIMD3<Double>, from floor: Int) -> Int? {
        let here = cell(of: position, floor: floor)
        return graph.neighbours(of: here)
            .filter { $0.x == here.x && $0.z == here.z && $0.floor > floor }
            .map(\.floor)
            .min()
    }

    /// The floor the head lands on when it leaves a ledge: the first one below that is
    /// walkable at the same place and no further down than the tuning allows
    /// (FR-SNAKE-220). Nil where there is nothing to land on within reach.
    func landing(below position: SIMD3<Double>, from floor: Int) -> Int? {
        // A ledge is where nothing stands. Walking into a wall with an open floor
        // beneath it is walking into a wall, not stepping off an edge — and without
        // this the head drops through the balcony's own walls.
        guard !occupied.contains(cell(of: position, floor: floor)) else { return nil }
        var candidate = floor - MapGrid.floorStep
        while elevation(of: floor) - elevation(of: candidate) <= maximumDropHeight {
            if graph.isWalkable(cell(of: position, floor: candidate)) { return candidate }
            candidate -= MapGrid.floorStep
        }
        return nil
    }

    // MARK: the body against what stands on the ground (ADR-0021)

    /// How far the body at a position is from the nearest thing it cannot pass, and
    /// which way on the ground leads away from it. Metres are the gap between the
    /// body and the module: zero where it touches, negative where it is inside.
    /// Nil where nothing stands at the body's height on that floor.
    ///
    /// The body is a circle of its radius around the head on the ground plane, as
    /// tall as it is wide, standing on the floor's surface; a module counts when its
    /// box reaches into that height, so a wall of the floor above is not in the way
    /// of a head on the floor below.
    func clearance(at position: SIMD3<Double>, floor: Int) -> (metres: Double, away: SIMD2<Double>)? {
        let bottom = elevation(of: floor)
        let top = bottom + Motion.heightInRadii * bodyRadius
        var nearest: (metres: Double, away: SIMD2<Double>)?
        for box in obstacles where box.lowest.y < top && box.highest.y > bottom {
            let offset = SIMD2(position.x - (box.lowest.x + box.highest.x) * Geometry.half,
                               position.z - (box.lowest.z + box.highest.z) * Geometry.half)
            let half = SIMD2((box.highest.x - box.lowest.x) * Geometry.half,
                             (box.highest.z - box.lowest.z) * Geometry.half)
            // How far outside the footprint along each axis; negative inside it.
            let beyond = SIMD2(abs(offset.x) - half.x, abs(offset.y) - half.y)
            let outside = SIMD2(max(beyond.x, .zero), max(beyond.y, .zero))
            let length = (outside.x * outside.x + outside.y * outside.y).squareRoot()
            let metres: Double
            let away: SIMD2<Double>
            if length > .zero {
                metres = length
                away = SIMD2(offset.x < .zero ? -outside.x : outside.x,
                             offset.y < .zero ? -outside.y : outside.y) / length
            } else if beyond.x > beyond.y {
                // Inside: out through the nearest side.
                metres = beyond.x
                away = SIMD2(offset.x < .zero ? Geometry.belowSide : Geometry.aboveSide, .zero)
            } else {
                metres = beyond.y
                away = SIMD2(.zero, offset.y < .zero ? Geometry.belowSide : Geometry.aboveSide)
            }
            let gap = metres - bodyRadius
            if nearest == nil || gap < nearest!.metres { nearest = (gap, away) }
        }
        return nearest
    }

    /// How far the body can go from a position along a direction on the ground, up
    /// to a distance, and which way leads away from what stopped it, where something
    /// did. The body stops where it touches, not where the step began.
    ///
    /// A body already inside something may go wherever it goes no deeper, so that a
    /// head set down overlapping a wall is not frozen there.
    ///
    /// Only the far end of the step is asked about, and that is enough: a step is
    /// never longer than half a cell, and the thinnest module in a kit is still wider
    /// than that once the body's width is added on each side of it — a partition of
    /// 0.1 m is 0.7 m to a body of 0.3 m — so no step can pass from one side of a
    /// module to the other.
    func room(from position: SIMD3<Double>, floor: Int, along unit: SIMD2<Double>,
              upTo distance: Double) -> (metres: Double, against: SIMD2<Double>?) {
        let deepest = min(.zero, clearance(at: position, floor: floor)?.metres ?? .zero)
        func at(_ metres: Double) -> SIMD3<Double> {
            SIMD3(position.x + unit.x * metres, position.y, position.z + unit.y * metres)
        }
        func fits(_ metres: Double) -> Bool {
            guard let there = clearance(at: at(metres), floor: floor) else { return true }
            return there.metres >= deepest - Motion.negligibleDistance
        }
        if fits(distance) { return (distance, nil) }
        var low: Double = .zero
        var high = distance
        while high - low > Motion.contactPrecision {
            let middle = (low + high) * Geometry.half
            if fits(middle) { low = middle } else { high = middle }
        }
        // What stopped the body is what it would be inside of just past the contact —
        // not what is nearest at the contact, where a body in a corner touches two
        // things at once and the one it is not pressing into may be named.
        return (low, clearance(at: at(high), floor: floor)?.away)
    }

    /// Whether the body can stand at a position without being inside anything.
    func fits(_ position: SIMD3<Double>, floor: Int) -> Bool {
        (clearance(at: position, floor: floor)?.metres ?? .zero) >= -Motion.overlapTolerance
    }

    /// A place for the body near a position, clear of what it cannot pass: moved out
    /// of whatever it overlaps, without leaving the cell the position is in. The
    /// position itself where that cannot be done.
    ///
    /// The match sets the head down with this (ADR-0021): it starts in the first
    /// walkable cell of the lowest floor (`Game.start`), which in an arena walled all
    /// round is a corner, and a body wider than a cell sits in both walls there.
    func clear(_ position: SIMD3<Double>, floor: Int) -> SIMD3<Double> {
        var here = position
        for _ in Int.zero..<Motion.pushOutAttempts {
            guard let near = clearance(at: here, floor: floor), near.metres < .zero else { break }
            here += SIMD3(near.away.x, .zero, near.away.y) * -near.metres
        }
        guard cell(of: here, floor: floor) == cell(of: position, floor: floor),
              fits(here, floor: floor) else { return position }
        return here
    }
}
