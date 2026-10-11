// The way from one cell to another over the graph the bots path on. Breadth first,
// because every edge of this graph costs the same step and the shortest route is the
// one with the fewest of them.
//
// file implements: FR-BOT-165
import Foundation

enum Route {
    /// The cells to walk, the first being the one after `start` and the last being
    /// `goal`. Empty when there is no way — which is a designed event and not an
    /// edge case (FR-BOT-167).
    static func between(_ start: NavigationGraph.Node, _ goal: NavigationGraph.Node,
                        in graph: NavigationGraph) -> [NavigationGraph.Node] {
        guard start != goal, graph.isWalkable(start), graph.isWalkable(goal) else { return [] }
        var cameFrom: [NavigationGraph.Node: NavigationGraph.Node] = [:]
        var queue = [start]
        var index = queue.startIndex
        while index < queue.endIndex {
            let here = queue[index]
            queue.formIndex(after: &index)
            if here == goal { break }
            for next in graph.neighbours(of: here).sorted(by: order) where cameFrom[next] == nil && next != start {
                cameFrom[next] = here
                queue.append(next)
            }
        }
        guard cameFrom[goal] != nil else { return [] }
        var path: [NavigationGraph.Node] = []
        var step = goal
        while step != start {
            path.append(step)
            guard let back = cameFrom[step] else { return [] }
            step = back
        }
        return path.reversed()
    }

    private static func order(_ a: NavigationGraph.Node, _ b: NavigationGraph.Node) -> Bool {
        (a.floor, a.z, a.x) < (b.floor, b.z, b.x)
    }
}
