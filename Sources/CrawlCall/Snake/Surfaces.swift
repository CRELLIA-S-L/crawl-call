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

    init(graph: NavigationGraph, kit: Kit, tuning: TuningConfiguration) {
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

    /// The floor the head lands on when it leaves a ledge: the first one below that is
    /// walkable at the same place and no further down than the tuning allows
    /// (FR-SNAKE-220). Nil where there is nothing to land on within reach.
    func landing(below position: SIMD3<Double>, from floor: Int) -> Int? {
        var candidate = floor - 1
        while elevation(of: floor) - elevation(of: candidate) <= maximumDropHeight {
            if graph.isWalkable(cell(of: position, floor: candidate)) { return candidate }
            candidate -= 1
        }
        return nil
    }
}
