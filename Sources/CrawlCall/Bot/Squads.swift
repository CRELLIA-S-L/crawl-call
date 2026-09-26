// Who is on the map when a match begins: two squads, hostile to each other, of the
// size the match configuration sets (FR-BOT-020).
//
// Where they begin is not something any requirement says — a map declares no spawn
// zone, the same gap the snake's own start runs into — so they are placed by the two
// things a map does say: which cells are walkable, and how far one cell is from
// another over the graph the bots path on. Said out loud rather than passed off as a
// rule: when a map gains spawn zones, this is what they replace.
//
// implements: FR-BOT-020, INV-BOT-030, FR-MAP-150, FR-BOT-280, FR-BOT-250
import Foundation

enum Squads {
    /// Both squads, placed away from the snake and away from each other.
    ///
    /// One squad anchors at the walkable cell farthest from the snake. The other
    /// anchors at the farthest cell from the snake that is not within grouping
    /// distance of the first — both squads want to be away from the player, and only
    /// the second also has to be somewhere else than the first. "Farthest from the
    /// first squad" would send it back into the snake's corner, and "farthest from
    /// both" lands it in the middle of the room, which on the blockout put four bots
    /// inside the snake's interrupt distance at the whistle.
    /// Each squad then fills the free cells nearest its anchor, and ties are broken
    /// by floor, then z, then x, so the same map always produces the same match.
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
        guard let redAnchor = farthest(in: fromSnake) else { return [] }
        // Two squads closer together than the distance at which they keep together
        // (IF-BOT-010) would read as one group rather than two sides. The distance is
        // measured across the room and not along the walk: the configuration's number
        // is in metres, and a balcony makes two cells a long walk apart while they
        // are four metres from one another — which is how both squads first ended up
        // on the same balcony.
        let redCentre = centre(of: redAnchor, in: world.graph, cellSize: cell, floorHeight: height)
        let apart = world.configurations.bot.groupingDistance
        let elsewhere = fromSnake.filter {
            Perception.metres(centre(of: $0.key, in: world.graph, cellSize: cell, floorHeight: height), redCentre) >= apart
        }
        guard let blueAnchor = farthest(in: elsewhere.isEmpty ? fromSnake : elsewhere) else { return [] }

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
            for next in graph.neighbours(of: here).sorted(by: before) where seen[next] == nil {
                seen[next] = seen[here]! + MapGrid.stepsPerNeighbour
                queue.append(next)
            }
        }
        return seen
    }

    /// The cell the walk reached last, ties broken by position so that the same map
    /// gives the same answer every time.
    private static func farthest(in distances: [NavigationGraph.Node: Int]) -> NavigationGraph.Node? {
        distances.max { a, b in
            a.value != b.value ? a.value < b.value : before(b.key, a.key)
        }?.key
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
