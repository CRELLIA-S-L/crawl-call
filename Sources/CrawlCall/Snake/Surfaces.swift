// Where the snake's head may be, in metres, answered from the same navigation graph
// the bots path over and the same tuning numbers they are measured by (FR-MAP-025).
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

    init(graph: NavigationGraph, kit: Kit, tuning: TuningConfiguration, map: MapSpecification) {
        self.occupied = Set(map.placements.filter { !$0.walkable }
            .map { NavigationGraph.Node(floor: $0.floor, x: $0.x, z: $0.z) })
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
        var candidate = floor - 1
        while elevation(of: floor) - elevation(of: candidate) <= maximumDropHeight {
            if graph.isWalkable(cell(of: position, floor: candidate)) { return candidate }
            candidate -= 1
        }
        return nil
    }
}
