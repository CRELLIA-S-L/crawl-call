// What a bot knows (ADR-0032): what it has seen of the snake, of the enemy and of the
// map, each with when; what it was given at the start; and what its squad has told it.
// A bot acts on this and on nothing else (FR-BOT-220): the truth is the world's, the
// record is the bot's.
//
// file implements: FR-BOT-050, FR-BOT-360, FR-BOT-220, FR-BOT-230, FR-BOT-240, FR-BOT-250, FR-BOT-260, FR-BOT-310, FR-BOT-320, FR-BOT-330
import Foundation

struct Knowledge: Equatable {
    /// Where something was seen, and when, in seconds of the match.
    struct Sighting: Equatable {
        var point: SIMD3<Double>
        var time: Double
    }

    /// What stood in a cell when it was seen — the module's name, or nil where the
    /// cell held nothing — and when.
    struct Cell: Equatable {
        var stands: String?
        var time: Double
    }

    /// A rough area: where the enemy squad starts (FR-BOT-250).
    struct Area: Equatable {
        var centre: SIMD3<Double>
        var radius: Double
    }

    /// The latest sighting of each part of the snake, by its place from the head
    /// (FR-BOT-050).
    var snake: [Int: Sighting] = [:]
    /// The latest sighting of each enemy bot, by its id (FR-BOT-240).
    var enemies: [Int: Sighting] = [:]
    /// The enemy bots it has seen dead, or been told of, and when they were seen so:
    /// no longer anyone to fire at or hide from (FR-BOT-320).
    var fallen: [Int: Double] = [:]
    /// The latest sighting of each cell of the map (FR-BOT-230).
    var cells: [NavigationGraph.Node: Cell] = [:]
    /// Given at the start (FR-BOT-250): the building's outline, floor by floor — which
    /// cells belong to it, not what stands in them — the ways between its floors, and
    /// where the enemy squad starts.
    var outline: Set<NavigationGraph.Node> = []
    var ways: Set<NavigationGraph.Node> = []
    var enemyStart: Area?
    /// The enemy bots it went to find where they were last seen and did not, and
    /// when (FR-BOT-360): a sighting of one no later than that is not believed again,
    /// its own or its squad's.
    var cleared: [Int: Double] = [:]

    /// Whether any part of the snake is in the record.
    var knowsSnake: Bool { !snake.isEmpty }

    /// Where the snake's parts were last seen, as far as the record goes.
    var snakePoints: [SIMD3<Double>] {
        snake.keys.sorted().compactMap { snake[$0]?.point }
    }

    /// The parts of the snake seen at `time` — in view now, not remembered.
    func snake(seenAt time: Double) -> [SIMD3<Double>] {
        snake.keys.sorted().compactMap { key in
            snake[key].flatMap { $0.time >= time ? $0.point : nil }
        }
    }

    /// The enemy bots seen at `time` — in view now — by id, where they stand.
    func enemies(seenAt time: Double) -> [(id: Int, point: SIMD3<Double>)] {
        enemies.keys.sorted().compactMap { id in
            enemies[id].flatMap { $0.time >= time ? (id: id, point: $0.point) : nil }
        }
    }

    /// Where the enemy bots were last seen, as far as the record goes.
    var enemyPoints: [SIMD3<Double>] {
        enemies.keys.sorted().compactMap { enemies[$0]?.point }
    }

    /// Records that an enemy was not where it was last seen, found out at `time`
    /// (FR-BOT-360).
    mutating func notFound(enemy id: Int, at time: Double) {
        cleared[id] = time
        enemies[id] = nil
    }

    /// Records an enemy seen dead at `time`: it leaves the enemies the bot fights.
    mutating func saw(fallen id: Int, at time: Double) {
        if fallen[id] == nil { fallen[id] = time }
        enemies[id] = nil
    }

    /// Whether the bot knows a cell: it has seen it, or it is a way between floors it
    /// was given at the start.
    func knows(_ cell: NavigationGraph.Node) -> Bool {
        cells[cell] != nil || ways.contains(cell)
    }

    /// Drops every sighting of the snake and of the enemy older than the times the
    /// configuration sets; a time of nothing forgets nothing, and the map is never
    /// forgotten (FR-BOT-260).
    mutating func forget(at now: Double, snakeAfter: Double, enemyAfter: Double) {
        if snakeAfter > .zero { snake = snake.filter { now - $0.value.time <= snakeAfter } }
        if enemyAfter > .zero { enemies = enemies.filter { now - $0.value.time <= enemyAfter } }
    }

    /// Takes in what another bot of the squad knows, as far as it had seen it by
    /// `before` — the squad's delay ago — the later of two sightings of one thing
    /// winning (FR-BOT-310).
    mutating func hear(_ other: Knowledge, seenBy before: Double) {
        func merge<Key: Hashable, Value>(_ mine: inout [Key: Value], _ theirs: [Key: Value],
                                         time: (Value) -> Double) {
            for (key, value) in theirs where time(value) <= before {
                if let known = mine[key], time(known) >= time(value) { continue }
                mine[key] = value
            }
        }
        merge(&snake, other.snake) { $0.time }
        merge(&enemies, other.enemies) { $0.time }
        merge(&cells, other.cells) { $0.time }
        // A death is heard as the rest is; a body stays dead, and an older sighting
        // of it standing is heard no more.
        for (id, time) in other.fallen where time <= before { saw(fallen: id, at: time) }
        for id in fallen.keys { enemies[id] = nil }
        // Nor is a sighting it has already gone to and found empty (FR-BOT-360).
        for (id, time) in cleared where (enemies[id]?.time ?? .infinity) <= time { enemies[id] = nil }
    }
}
