// What a bot knows (ADR-0032): the sightings of the snake (FR-BOT-050), of the enemy
// (FR-BOT-240) and of the map (FR-BOT-230), each with when; what it is given at the
// start (FR-BOT-250); what it forgets (FR-BOT-260); what its squad tells it after a
// delay (FR-BOT-310); and that it chooses on that and on nothing else (FR-BOT-220).
//
// The arenas are built here, so that what is in the way is known.
//
// verifies: FR-BOT-050, FR-BOT-220, FR-BOT-230, FR-BOT-240, FR-BOT-250, FR-BOT-260, FR-BOT-310, IF-BOT-010
import XCTest
@testable import CrawlCall

final class KnowledgeTests: XCTestCase {
    private var shipped: World!
    private var configuration: BotConfiguration { shipped.configurations.bot }
    private let cell = 0.5
    private let east = Double.pi / 2

    override func setUpWithError() throws {
        try super.setUpWithError()
        shipped = try Launch.world().get()
    }

    /// A world of the shipped configuration and kit over a floor built here.
    private func world(_ rows: String...) throws -> World {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        return World(configurations: shipped.configurations, kit: shipped.kit, map: map, setting: shipped.setting,
                     graph: NavigationGraph.derive(from: map, stepHeight: shipped.configurations.tuning.stepHeight),
                     plan: ScenePlan.make(map: map, kit: shipped.kit, cellSize: cell))
    }

    private func at(_ x: Int, _ z: Int) -> SIMD3<Double> { SIMD3(Double(x) * cell, 0, Double(z) * cell) }
    private func node(_ x: Int, _ z: Int) -> NavigationGraph.Node { NavigationGraph.Node(floor: 0, x: x, z: z) }

    private func bot(_ id: Int = 0, _ squad: Squad = .red, at x: Int, _ z: Int, facing: Double? = nil) throws -> Bot {
        var made = try XCTUnwrap(Bot(id: id, squad: squad, archetype: .assault, at: at(x, z), floor: 0,
                                     configuration: configuration))
        made.facing = facing ?? east
        return made
    }

    /// A row thirty cells long with crates across it at column ten, and an open row
    /// above it. Crates, not the kit's wall, because a crate stands higher than a
    /// bot's eyes and the wall does not (ADR-0022).
    private func walled() throws -> World {
        try world(String(repeating: ".", count: 30),
                  String(repeating: ".", count: 10) + "o" + String(repeating: ".", count: 19),
                  String(repeating: ".", count: 10) + "o" + String(repeating: ".", count: 19))
    }

    // MARK: the snake (FR-BOT-050)

    func testASightingOfTheSnakeSaysWhereAndWhenAndTheLatestReplacesTheOneBefore() throws {
        let floor = try walled()
        var bots = [try bot(at: 2, 0)]
        Perception.notice(&bots, snake: [at(6, 0)], plan: floor.plan, configuration: configuration, now: 1)
        XCTAssertEqual(try element(0, of: bots).knowledge.snake, [0: .init(point: at(6, 0), time: 1)])

        // Seen again further on: the new place and time. A part beyond the range is
        // not seen at all.
        Perception.notice(&bots, snake: [at(7, 0), at(28, 0)], plan: floor.plan, configuration: configuration, now: 2)
        XCTAssertEqual(try element(0, of: bots).knowledge.snake, [0: .init(point: at(7, 0), time: 2)])

        // Turned away, it no longer sees the snake move: what it knows is where it saw it.
        bots[try checkedIndex(0, of: bots)].facing = -east
        Perception.notice(&bots, snake: [at(8, 0)], plan: floor.plan, configuration: configuration, now: 3)
        XCTAssertEqual(try element(0, of: bots).knowledge.snake, [0: .init(point: at(7, 0), time: 2)])
    }

    // MARK: the enemy (FR-BOT-240)

    func testABotRecordsTheEnemyItSeesAndNotTheOneItCannot() throws {
        let floor = try walled()
        var bots = [try bot(0, .red, at: 2, 1),
                    try bot(1, .blue, at: 6, 1),       // in the open ahead
                    try bot(2, .blue, at: 13, 1),      // behind the crates
                    try bot(3, .blue, at: 0, 1),       // behind the bot's back
                    try bot(4, .red, at: 5, 0)]        // a mate, not an enemy
        Perception.noticeEnemies(&bots, plan: floor.plan, configuration: configuration, now: 4)
        let known = try element(0, of: bots).knowledge.enemies
        XCTAssertEqual(known, [1: .init(point: at(6, 1), time: 4)])

        // The enemy moves on in view: the later sighting replaces the earlier.
        bots[try checkedIndex(1, of: bots)].position = at(7, 1)
        Perception.noticeEnemies(&bots, plan: floor.plan, configuration: configuration, now: 5)
        XCTAssertEqual(try element(0, of: bots).knowledge.enemies, [1: .init(point: at(7, 1), time: 5)])
    }

    // MARK: the map (FR-BOT-230)

    func testABotRecordsTheCellsItSeesWithWhatStandsInThem() throws {
        let floor = try walled()
        let modules = Perception.modules(of: floor.map)
        var looker = try bot(at: 2, 1)
        Perception.lookAtMap(&looker, world: floor, modules: modules, now: 3)
        let cells = looker.knowledge.cells

        XCTAssertEqual(modules[node(5, 1)], "floor", "the map moved, so the test proves nothing")
        XCTAssertEqual(modules[node(10, 1)], "crate", "the map moved, so the test proves nothing")
        XCTAssertEqual(cells[node(5, 1)], .init(stands: "floor", time: 3), "the open floor ahead")
        XCTAssertEqual(cells[node(10, 1)], .init(stands: "crate", time: 3), "the crate ahead, by its face")
        XCTAssertNil(cells[node(12, 1)], "the bot saw through the crate")
        XCTAssertNotNil(cells[node(12, 0)], "the open row beside the crates")
        XCTAssertNil(cells[node(0, 1)], "the bot saw behind its back")
        XCTAssertNil(cells[node(20, 0)], "the bot saw beyond its range")

        // Looked at again later: the later sighting replaces the earlier.
        Perception.lookAtMap(&looker, world: floor, modules: modules, now: 5)
        XCTAssertEqual(looker.knowledge.cells[node(5, 1)], .init(stands: "floor", time: 5))
        XCTAssertEqual(looker.lastLook, 5)
    }

    func testAMatchLooksAtTheMapAsItRuns() throws {
        // The wiring: once a match has run a frame, every bot knows cells round it.
        let start = try XCTUnwrap(Game.firstStart(in: shipped))
        var game = Game(world: shipped, start: start)
        XCTAssertTrue(game.bots.allSatisfy { $0.knowledge.cells.isEmpty })
        _ = game.advance(seconds: 1.0 / 60)
        XCTAssertFalse(game.bots.isEmpty)
        for bot in game.bots {
            XCTAssertFalse(bot.knowledge.cells.isEmpty, "bot \(bot.id) has seen nothing of the map")
        }
        // From then on the bots take turns: every bot looks once a period, and no frame
        // carries the looks of the whole squad.
        let period = shipped.configurations.bot.deliberationPeriod
        let frames = Int((period * 60).rounded())
        var looked: [Int: Int] = [:], most = 0
        for _ in 0..<(frames * 3) {
            _ = game.advance(seconds: 1.0 / 60)
            let now = game.bots.filter { $0.lastLook == game.elapsed }
            most = max(most, now.count)
            for bot in now { looked[bot.id, default: 0] += 1 }
        }
        XCTAssertLessThanOrEqual(most, Int((Double(game.bots.count) / Double(frames)).rounded(.up)) + 1,
                                 "\(most) bots looked round in one frame")
        for bot in game.bots {
            XCTAssertGreaterThanOrEqual(looked[bot.id] ?? 0, 2, "bot \(bot.id) stopped looking round")
        }
    }

    // MARK: the start (FR-BOT-250)

    func testAtTheStartABotKnowsTheOutlineTheWaysAndWhereTheEnemyStartsAndNothingElse() throws {
        let start = try XCTUnwrap(Game.firstStart(in: shipped))
        let bots = Squads.spawn(in: shipped, snakeStart: start)
        let ways = Set(shipped.map.placements.filter { $0.step != nil }.map { node($0.x, $0.z).on($0.floor) })
        XCTAssertFalse(ways.isEmpty, "the shipped map has no stairs, so the test proves nothing about them")
        XCTAssertFalse(bots.isEmpty)
        for bot in bots {
            let knowledge = bot.knowledge
            XCTAssertTrue(knowledge.snake.isEmpty && knowledge.enemies.isEmpty && knowledge.cells.isEmpty,
                          "bot \(bot.id) starts knowing more than the building")
            XCTAssertTrue(knowledge.outline.isSuperset(of: shipped.graph.nodes), "bot \(bot.id) lacks part of the outline")
            XCTAssertEqual(knowledge.ways, ways)
            // The rough area holds every enemy and is the enemy's, not the bot's own.
            let area = try XCTUnwrap(knowledge.enemyStart)
            for other in bots where other.squad != bot.squad {
                XCTAssertLessThanOrEqual(Perception.metres(other.position, area.centre), area.radius)
            }
            let own = bots.filter { $0.squad == bot.squad }.map(\.position).reduce(.zero, +)
                / Double(bots.filter { $0.squad == bot.squad }.count)
            XCTAssertGreaterThan(Perception.metres(own, area.centre), area.radius * 0.5,
                                 "bot \(bot.id) was given its own squad's start for the enemy's")
        }
        // What stands in a cell is not known: a cell is known by sight, a way by the start.
        let bot = try element(0, of: bots)
        let crateless = try XCTUnwrap(shipped.graph.nodes.first { !ways.contains($0) })
        XCTAssertFalse(bot.knowledge.knows(crateless))
        XCTAssertTrue(bot.knowledge.knows(try XCTUnwrap(ways.first)))
    }

    // MARK: forgetting (FR-BOT-260)

    func testNothingIsForgottenUnlessATimeIsSet() throws {
        XCTAssertEqual(configuration.snakeForgottenAfter, 0, "the shipped configuration forgets")
        XCTAssertEqual(configuration.enemyForgottenAfter, 0, "the shipped configuration forgets")
        var knowledge = Knowledge()
        knowledge.snake = [0: .init(point: at(1, 0), time: 1), 1: .init(point: at(2, 0), time: 8)]
        knowledge.enemies = [7: .init(point: at(3, 0), time: 1)]
        knowledge.cells = [node(1, 1): .init(stands: nil, time: 1)]
        let remembered = knowledge

        knowledge.forget(at: 1000, snakeAfter: 0, enemyAfter: 0)
        XCTAssertEqual(knowledge, remembered, "something was forgotten with no time set")

        knowledge.forget(at: 10, snakeAfter: 5, enemyAfter: 0)
        XCTAssertEqual(knowledge.snake, [1: .init(point: at(2, 0), time: 8)], "only the old sighting goes")
        XCTAssertEqual(knowledge.enemies, remembered.enemies)
        XCTAssertEqual(knowledge.cells, remembered.cells, "the map was forgotten")

        knowledge.forget(at: 10, snakeAfter: 0, enemyAfter: 5)
        XCTAssertTrue(knowledge.enemies.isEmpty)
        XCTAssertEqual(knowledge.cells, remembered.cells, "the map was forgotten")
    }

    // MARK: the squad (FR-BOT-310)

    func testASquadHearsWhatAMateSawOnceTheDelayHasPassed() throws {
        let delay = try XCTUnwrap(configuration.shareDelay["red"])
        XCTAssertGreaterThan(delay, 0)
        var witness = try bot(0, .red, at: 2, 0)
        witness.knowledge.snake = [0: .init(point: at(9, 9), time: 1)]
        witness.knowledge.enemies = [5: .init(point: at(8, 8), time: 1)]
        witness.knowledge.cells = [node(4, 4): .init(stands: "crate", time: 1)]
        var bots = [witness, try bot(1, .red, at: 3, 0), try bot(2, .blue, at: 4, 0)]

        Execution.share(&bots, now: 1 + delay * 0.9, configuration: configuration)
        XCTAssertEqual(try element(1, of: bots).knowledge, Knowledge(), "the mate heard before the delay had passed")

        Execution.share(&bots, now: 1 + delay, configuration: configuration)
        let mate = try element(1, of: bots).knowledge
        XCTAssertEqual(mate.snake, witness.knowledge.snake)
        XCTAssertEqual(mate.enemies, witness.knowledge.enemies)
        XCTAssertEqual(mate.cells, witness.knowledge.cells)
        XCTAssertEqual(try element(2, of: bots).knowledge, Knowledge(), "the enemy heard the squad")
    }

    func testWhatABotSawLaterIsNotOverwrittenByAnOlderReport() throws {
        var mine = Knowledge()
        mine.snake = [0: .init(point: at(1, 1), time: 5)]
        var theirs = Knowledge()
        theirs.snake = [0: .init(point: at(2, 2), time: 3), 1: .init(point: at(3, 3), time: 3)]
        mine.hear(theirs, seenBy: 4)
        XCTAssertEqual(mine.snake, [0: .init(point: at(1, 1), time: 5), 1: .init(point: at(3, 3), time: 3)])
        // And the other way round: a newer report replaces an older sighting.
        var old = Knowledge()
        old.snake = [0: .init(point: at(1, 1), time: 1)]
        old.hear(theirs, seenBy: 4)
        XCTAssertEqual(old.snake.first { $0.key == 0 }?.value, .init(point: at(2, 2), time: 3))
    }

    // MARK: acting on knowledge (FR-BOT-220)

    private func situation(_ floor: World) -> Deliberation.Situation {
        Deliberation.Situation(plan: floor.plan, graph: floor.graph, configuration: configuration, cellSize: cell)
    }

    private func isFire(_ action: Action) -> Bool { if case .fire = action { return true }; return false }

    func testABotFiresOnlyAtASnakeItSeesNow() throws {
        let floor = try world(String(repeating: ".", count: 12))
        let bot = try bot(at: 0, 0)
        var remembered = situation(floor)
        remembered.snake = [at(6, 0)]
        XCTAssertFalse(Deliberation.scores(for: bot, in: remembered).contains { isFire($0.action) },
                       "the bot fired at where the snake was")
        var seen = remembered
        seen.inView = seen.snake
        XCTAssertTrue(Deliberation.scores(for: bot, in: seen).contains { isFire($0.action) })

        // The same through a deliberation step: a sighting from before now is memory,
        // one made now is a target.
        var remembering = bot
        remembering.knowledge.snake = [0: .init(point: at(6, 0), time: 1)]
        var bots = [remembering]
        let quiet = Execution.deliberate(&bots, slots: [bot.id], world: floor, now: 2)
        XCTAssertTrue(quiet.shots.isEmpty, "the bot fired at where it remembered the snake")
        bots = [remembering]
        let volley = Execution.deliberate(&bots, slots: [bot.id], world: floor, now: 1)
        XCTAssertFalse(volley.shots.isEmpty, "the bot did not fire at a snake it sees, so the test proves nothing")
    }

    func testABotRunsAndHidesOnlyInCellsItKnows() throws {
        let floor = try world(String(repeating: ".", count: 16), ".#" + String(repeating: ".", count: 14))
        let bot = try bot(at: 4, 0)
        var blind = situation(floor)
        blind.snake = [at(0, 0)]
        blind.inView = blind.snake
        blind.knows = { _ in false }
        for scored in Deliberation.scores(for: bot, in: blind) {
            switch scored.action {
            case .flee, .takeCover: XCTFail("the bot set off for a cell it does not know: \(scored.action)")
            default: break
            }
        }
        let known: Set<NavigationGraph.Node> = [node(6, 0), node(7, 0), node(6, 1)]
        var some = blind
        some.knows = { known.contains($0) }
        var destinations = 0
        for scored in Deliberation.scores(for: bot, in: some) {
            switch scored.action {
            case .flee(let there), .takeCover(let there):
                XCTAssertTrue(known.contains(there), "the bot set off for \(there), which it does not know")
                destinations += 1
            default: break
            }
        }
        XCTAssertGreaterThan(destinations, 0, "with cells it knows, the bot went nowhere, so the test proves nothing")
    }

    func testWhereTheSnakeTrulyIsDoesNotMoveABotThatHasNotSeenIt() throws {
        // The bot remembers the snake to its west and looks east. The snake moves about
        // behind it, unseen: its choice stays what it was.
        let floor = try walled()
        let modules = Perception.modules(of: floor.map)
        var bot = try bot(at: 8, 0)
        bot.knowledge.snake = [0: .init(point: at(2, 0), time: 0)]
        Perception.lookAtMap(&bot, world: floor, modules: modules, now: 0)
        var choices: [Action?] = []
        for (step, hidden) in [at(1, 0), at(3, 2), at(0, 2)].enumerated() {
            var bots = [bot]
            let now = Double(step + 1)
            Perception.notice(&bots, snake: [hidden], plan: floor.plan, configuration: configuration, now: now)
            XCTAssertEqual(try element(0, of: bots).knowledge.snake, bot.knowledge.snake, "the bot saw behind it")
            _ = Execution.deliberate(&bots, slots: [bot.id], world: floor, now: now)
            choices.append(try element(0, of: bots).action)
        }
        XCTAssertNotNil(choices.first ?? nil)
        XCTAssertEqual(Set(choices.map { "\(String(describing: $0))" }).count, 1, "the choice moved with a snake the bot never saw: \(choices)")
    }
}

private extension NavigationGraph.Node {
    func on(_ floor: Int) -> NavigationGraph.Node { NavigationGraph.Node(floor: floor, x: x, z: z) }
}
