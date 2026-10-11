// Who is on the map when a match begins: two squads, hostile to each other, of the
// size the match configuration sets (FR-BOT-020), one at each end of the island
// (FR-BOT-350).
//
// A map declares no area for either squad yet (Q-360), so the ends are found from what
// a map does say: which cells are walkable, where they lie, and which of them the
// snake's start reaches. When a map gains squad areas, they replace the ends.
//
// file implements: FR-BOT-020, FR-BOT-350, INV-BOT-030, FR-MAP-150, FR-BOT-280, FR-BOT-250
import Foundation

enum Squads {
    /// Both squads, one at each end of the island (FR-BOT-350).
    ///
    /// The ends are the two cells that lie farthest apart across the ground among
    /// those the snake's start reaches and that are not within its interrupt distance.
    /// The red squad takes the end farther from the snake, and each squad then fills
    /// the free cells nearest its end; ties are broken by floor, then z, then x, so the
    /// same map always produces the same match (ADR-0056).
    static func spawn(in world: World, snakeStart: NavigationGraph.Node) -> [Bot] {
        let size = world.configurations.match.squadSize
        guard size > .zero else { return [] }
        let cell = world.configurations.tuning.navigationGraphCellSize
        let height = world.kit.floorHeight

        // No bot starts within the snake's interrupt distance, measured across the
        // ground and not along the walk: a cell many steps away can be a wall's width
        // from the snake — outside a building the snake starts in — and a bot there
        // begins the match alarmed. Those cells are taken before anybody is placed.
        let snake = centre(of: snakeStart, in: world.graph, cellSize: cell, floorHeight: height)
        let interrupt = world.configurations.bot.interruptDistance
        let reach = distances(in: world.graph, from: snakeStart)
        let near = Set(reach.keys.filter {
            Perception.metres(centre(of: $0, in: world.graph, cellSize: cell, floorHeight: height), snake) <= interrupt
        })
        let clear = reach.filter { !near.contains($0.key) }
        let fromSnake = clear.isEmpty ? reach : clear
        guard let ends = ends(of: Array(fromSnake.keys), in: world.graph, cellSize: cell, floorHeight: height)
        else { return [] }
        let redAnchor = ground(ends.one.centre, snake) >= ground(ends.two.centre, snake) ? ends.one.node : ends.two.node
        let blueAnchor = redAnchor == ends.one.node ? ends.two.node : ends.one.node
        let redCentre = centre(of: redAnchor, in: world.graph, cellSize: cell, floorHeight: height)
        // Two squads closer together than the distance at which they keep together
        // (IF-BOT-010) would read as one group rather than two sides — which on a
        // small map two ends can still be. Measured across the room and not along the
        // walk: the configuration's number is in metres.
        let apart = world.configurations.bot.groupingDistance

        var taken: Set<NavigationGraph.Node> = clear.isEmpty ? [] : near
        let red = nearest(size, to: redAnchor, in: world.graph, avoiding: &taken)
        // Not merely two anchors apart but two groups apart: every cell of the second
        // squad keeps the grouping distance from every bot of the first, or the two
        // fan out towards each other and arrive as one crowd.
        let held = red.map { centre(of: $0, in: world.graph, cellSize: cell, floorHeight: height) }
        let blue = nearest(size, to: blueAnchor, in: world.graph, avoiding: &taken,
                           keeping: apart, from: held, cellSize: cell, floorHeight: height)

        var bots: [Bot] = []
        let blueCentre = centre(of: blueAnchor, in: world.graph, cellSize: cell, floorHeight: height)
        // What every bot knows at the start (FR-BOT-250): the building's outline, floor
        // by floor, and the ways between its floors — not what stands in its cells —
        // and roughly where the enemy squad starts.
        var start = Knowledge()
        start.outline = Set(world.map.placements.map { NavigationGraph.Node(floor: $0.floor, x: $0.x, z: $0.z) })
            .union(world.graph.nodes)
        start.ways = Set(world.map.placements.filter { $0.step != nil }
            .map { NavigationGraph.Node(floor: $0.floor, x: $0.x, z: $0.z) })
        func area(_ cells: [NavigationGraph.Node]) -> Knowledge.Area? {
            let points = cells.map { centre(of: $0, in: world.graph, cellSize: cell, floorHeight: height) }
            guard !points.isEmpty else { return nil }
            let middle = points.reduce(.zero, +) / Double(points.count)
            let radius = points.map { Perception.metres($0, middle) }.max() ?? .zero
            return Knowledge.Area(centre: middle, radius: radius + cell)
        }
        let startAreas: [Squad: Knowledge.Area?] = [.red: area(blue), .blue: area(red)]
        for (squad, cells, enemy) in [(Squad.red, red, blueCentre), (Squad.blue, blue, redCentre)] {
            for (index, node) in cells.enumerated() {
                let kind = Archetype.allCases[index % Archetype.allCases.count]
                let position = centre(of: node, in: world.graph, cellSize: cell, floorHeight: height)
                guard var bot = Bot(id: bots.count, squad: squad, archetype: kind,
                                    at: position, floor: node.floor,
                                    configuration: world.configurations.bot) else { continue }
                // Facing the other squad: the two are at war (FR-BOT-280).
                bot.facing = Turning.angle(from: position, to: enemy) ?? .zero
                bot.knowledge = start
                bot.knowledge.enemyStart = startAreas[squad] ?? nil
                bots.append(bot)
            }
        }
        return bots
    }

    /// Where a cell stands, in metres.
    static func centre(of node: NavigationGraph.Node, in graph: NavigationGraph,
                       cellSize: Double, floorHeight: Double) -> SIMD3<Double> {
        graph.centre(of: node, cellSize: cellSize, floorHeight: floorHeight)
    }

    /// Steps over the graph from one cell to every cell it can reach.
    static func distances(in graph: NavigationGraph,
                          from start: NavigationGraph.Node) -> [NavigationGraph.Node: Int] {
        guard graph.isWalkable(start) else { return [:] }
        var seen = [start: Int.zero]
        var queue = [start]
        var index = queue.startIndex
        while index < queue.endIndex {
            let here = queue[index]
            queue.formIndex(after: &index)
            // In any order: a breadth-first walk gives every cell the same count of steps
            // whichever neighbour it takes first.
            for next in graph.neighbours(of: here) where seen[next] == nil {
                seen[next] = seen[here]! + MapGrid.stepsPerNeighbour
                queue.append(next)
            }
        }
        return seen
    }

    /// The two cells that lie farthest apart across the ground: the island's ends
    /// (FR-BOT-350). Where several pairs are as far apart, the first in the cells'
    /// order; a single cell is both ends.
    static func ends(of cells: [NavigationGraph.Node], in graph: NavigationGraph,
                     cellSize: Double, floorHeight: Double)
        -> (one: (node: NavigationGraph.Node, centre: SIMD3<Double>),
            two: (node: NavigationGraph.Node, centre: SIMD3<Double>))? {
        let ordered = cells.sorted(by: before)
            .map { (node: $0, centre: centre(of: $0, in: graph, cellSize: cellSize, floorHeight: floorHeight)) }
        guard let first = ordered.first else { return nil }
        var best = (one: first, two: first, metres: -Double.infinity)
        for i in ordered.indices {
            for j in ordered.indices where j > i {
                let metres = ground(ordered[i].centre, ordered[j].centre)
                if metres > best.metres { best = (ordered[i], ordered[j], metres) }
            }
        }
        return (best.one, best.two)
    }

    /// How far apart two points lie across the ground, whatever floor each is on.
    static func ground(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = SIMD2(a.x - b.x, a.z - b.z)
        return (d * d).sum().squareRoot()
    }

    /// The `count` reachable cells nearest an anchor that nobody has taken yet, and
    /// that keep the given distance from the places named.
    private static func nearest(_ count: Int, to anchor: NavigationGraph.Node,
                                in graph: NavigationGraph,
                                avoiding taken: inout Set<NavigationGraph.Node>,
                                keeping distance: Double = .zero,
                                from others: [SIMD3<Double>] = [],
                                cellSize: Double = .zero,
                                floorHeight: Double = .zero) -> [NavigationGraph.Node] {
        let reach = distances(in: graph, from: anchor)
        let free = reach.keys
            .filter { !taken.contains($0) }
            .filter { node in
                guard distance > .zero, !others.isEmpty else { return true }
                let there = centre(of: node, in: graph, cellSize: cellSize, floorHeight: floorHeight)
                return others.allSatisfy { Perception.metres(there, $0) >= distance }
            }
            .sorted { a, b in
                reach[a]! != reach[b]! ? reach[a]! < reach[b]! : before(a, b)
            }
        let chosen = Array(free.prefix(count))
        taken.formUnion(chosen)
        return chosen
    }

    /// One order over cells, used wherever a tie would otherwise be the dictionary's
    /// to break.
    private static func before(_ a: NavigationGraph.Node, _ b: NavigationGraph.Node) -> Bool {
        (a.floor, a.z, a.x) < (b.floor, b.z, b.x)
    }
}
