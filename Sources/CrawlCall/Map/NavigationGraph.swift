// The bots' model of the map (ADR-0016): one node per walkable cell and floor, an
// edge for every transition between floors, and edges between neighbouring cells on
// the same floor.
//
// Which cells count as neighbours is not something the requirements settle. This uses
// the four orthogonal ones: a diagonal step would let a bot cut the corner of a wall,
// which is a bug the grid cannot see and a player can. Said out loud because the
// specification is silent on it.
//
// implements: FR-TOOL-030, FR-MAP-020
import Foundation

struct NavigationGraph: Equatable {
    struct Node: Hashable {
        let floor: Int
        let x: Int
        let z: Int
    }

    private(set) var neighbours: [Node: Set<Node>]

    var nodes: Set<Node> { Set(neighbours.keys) }
    var nodeCount: Int { neighbours.count }
    var edgeCount: Int { neighbours.values.reduce(0) { $0 + $1.count } / 2 }

    func isWalkable(_ node: Node) -> Bool { neighbours[node] != nil }
    func neighbours(of node: Node) -> Set<Node> { neighbours[node] ?? [] }

    /// Builds the graph from a parsed map. A transition whose ends are not both
    /// walkable makes no edge; reporting that is FR-TOOL-040's job, not this one's.
    static func derive(from map: MapSpecification) -> NavigationGraph {
        var neighbours: [Node: Set<Node>] = [:]
        for placement in map.placements where placement.walkable {
            neighbours[Node(floor: placement.floor, x: placement.x, z: placement.z)] = []
        }

        func link(_ a: Node, _ b: Node) {
            guard neighbours[a] != nil, neighbours[b] != nil else { return }
            neighbours[a]?.insert(b)
            neighbours[b]?.insert(a)
        }

        for node in neighbours.keys {
            link(node, Node(floor: node.floor, x: node.x + 1, z: node.z))
            link(node, Node(floor: node.floor, x: node.x, z: node.z + 1))
        }
        for transition in map.transitions {
            link(Node(floor: transition.from, x: transition.x, z: transition.z),
                 Node(floor: transition.to, x: transition.x, z: transition.z))
        }
        return NavigationGraph(neighbours: neighbours)
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
