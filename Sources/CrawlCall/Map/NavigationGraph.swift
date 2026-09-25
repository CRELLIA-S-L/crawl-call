// The bots' model of the map (ADR-0016): one node per walkable cell and floor at the
// height of its surface, edges between neighbouring cells whose surfaces are a step
// apart or less whichever floor each is on, and an edge for every transition between
// floors (FR-MAP-020). A flight of stairs joins its floors by the first rule: its top
// step is level with the floor above (FR-MAP-150, ADR-0033).
//
// Which cells count as neighbours is not something the requirements settle. This uses
// the four orthogonal ones: a diagonal step would let a bot cut the corner of a wall,
// which is a bug the grid cannot see and a player can. Said out loud because the
// specification is silent on it.
//
// implements: FR-TOOL-030, FR-MAP-020, FR-MAP-150, FR-MAP-025
import Foundation

struct NavigationGraph: Equatable {
    struct Node: Hashable {
        let floor: Int
        let x: Int
        let z: Int
    }

    private(set) var neighbours: [Node: Set<Node>]
    /// The height of each node's walking surface, in metres.
    private(set) var heights: [Node: Double]

    var nodes: Set<Node> { Set(neighbours.keys) }
    var nodeCount: Int { neighbours.count }
    var edgeCount: Int { neighbours.values.reduce(.zero) { $0 + $1.count } / MapGrid.endsPerEdge }

    func isWalkable(_ node: Node) -> Bool { neighbours[node] != nil }
    func neighbours(of node: Node) -> Set<Node> { neighbours[node] ?? [] }

    /// How high a node's walking surface is; a cell the graph does not hold is at its
    /// floor's height, so that a caller asking about a wall's cell gets its floor.
    func height(of node: Node, floorHeight: Double) -> Double {
        heights[node] ?? Double(node.floor) * floorHeight
    }

    /// Where a node stands, in metres: the middle of its cell, at the height of its
    /// surface.
    func centre(of node: Node, cellSize: Double, floorHeight: Double) -> SIMD3<Double> {
        SIMD3(Double(node.x) * cellSize, height(of: node, floorHeight: floorHeight), Double(node.z) * cellSize)
    }

    /// The node at a cell whose surface is highest but no higher than `height` allows
    /// — the ground a thing at that height stands on there — or nil where the graph
    /// holds nothing at that cell at or below it.
    func node(atX x: Int, z: Int, below height: Double) -> Node? {
        floors.compactMap { floor -> (Node, Double)? in
            let node = Node(floor: floor, x: x, z: z)
            guard let h = heights[node], h <= height + Geometry.samePosition else { return nil }
            return (node, h)
        }.max { $0.1 < $1.1 }?.0
    }

    /// The floors the graph has nodes on.
    private(set) var floors: [Int] = []

    /// Builds the graph from a parsed map. A transition whose ends are not both
    /// walkable makes no edge; reporting that is FR-TOOL-040's job, not this one's.
    ///
    /// `stepHeight` is the tuning's (IF-MAP-020): the same number the snake climbs by
    /// (FR-MAP-025).
    static func derive(from map: MapSpecification, stepHeight: Double) -> NavigationGraph {
        var neighbours: [Node: Set<Node>] = [:]
        var heights: [Node: Double] = [:]
        for placement in map.placements where placement.walkable {
            let node = Node(floor: placement.floor, x: placement.x, z: placement.z)
            neighbours[node] = []
            heights[node] = map.height(of: placement)
        }
        let floors = Set(heights.keys.map(\.floor)).sorted()

        func link(_ a: Node, _ b: Node) {
            guard neighbours[a] != nil, neighbours[b] != nil else { return }
            neighbours[a]?.insert(b)
            neighbours[b]?.insert(a)
        }

        // Each pair of neighbouring cells once — to the east and to the south — on
        // every floor, joined where their surfaces are within a step of each other.
        for (node, height) in heights {
            for next in [(x: node.x + MapGrid.neighbourStep, z: node.z),
                         (x: node.x, z: node.z + MapGrid.neighbourStep)] {
                for floor in floors {
                    let other = Node(floor: floor, x: next.x, z: next.z)
                    guard let there = heights[other], abs(there - height) <= stepHeight + Geometry.samePosition
                    else { continue }
                    link(node, other)
                }
            }
        }
        for transition in map.transitions {
            link(Node(floor: transition.from, x: transition.x, z: transition.z),
                 Node(floor: transition.to, x: transition.x, z: transition.z))
        }
        return NavigationGraph(neighbours: neighbours, heights: heights, floors: floors)
    }

    /// The floors that can be reached from one node, walking. Used by the tests and,
    /// later, by the validator FR-TOOL-040 describes.
    func floorsReachable(from start: Node) -> Set<Int> {
        var seen: Set<Node> = [start]
        var queue = [start]
        while let node = queue.popLast() {
            for next in neighbours(of: node) where !seen.contains(next) {
                seen.insert(next)
                queue.append(next)
            }
        }
        return Set(seen.map(\.floor))
    }
}
