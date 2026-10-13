// A target the graph cannot route to (FR-BOT-167): the action is spent, the bot gets a
// slot without waiting its turn, and that action alone is left out of it — until the
// slot after, because the way may be open again by then.
//
// The arena is two rooms with no door between them, so that a cell can be known, be the
// nearest to what a bot believes, and still be somewhere it cannot get to.
//
// file verifies: FR-BOT-167
import XCTest
@testable import CrawlCall

final class UnreachableTests: XCTestCase {
    private var shipped: World!
    private var world: World!
    private let now = 10.0
    /// The enemy this bot has seen, as its knowledge keys its sightings.
    private let rival = 1

    /// Two rooms of ten cells, a wall of solid crates between them: no route either way.
    private let rooms = ["..........oo..........",
                         "..........oo..........",
                         "..........oo.........."]

    override func setUpWithError() throws {
        try super.setUpWithError()
        shipped = try Launch.world().get()
        world = try make(rooms)
    }

    private func make(_ rows: [String]) throws -> World {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        let cell = shipped.configurations.tuning.navigationGraphCellSize
        return World(configurations: shipped.configurations, kit: shipped.kit, map: map, setting: shipped.setting,
                     graph: NavigationGraph.derive(from: map, stepHeight: shipped.configurations.tuning.stepHeight),
                     plan: ScenePlan.make(map: map, kit: shipped.kit, cellSize: cell))
    }

    private var configuration: BotConfiguration { world.configurations.bot }
    private var cell: Double { world.configurations.tuning.navigationGraphCellSize }

    private func at(_ x: Int, _ z: Int) -> SIMD3<Double> { SIMD3(Double(x) * cell, 0, Double(z) * cell) }
    private func node(_ x: Int, _ z: Int) -> NavigationGraph.Node { NavigationGraph.Node(floor: 0, x: x, z: z) }

    /// A bot in the left room, believing the enemy to be in the right one.
    private func westerner(_ id: Int = 0) throws -> Bot {
        var bot = try XCTUnwrap(Bot(id: id, squad: .red, archetype: .assault, at: at(2, 1), floor: 0,
                                    configuration: configuration))
        bot.knowledge.enemies[rival] = .init(point: at(20, 1), time: now)
        return bot
    }

    private func situation() -> Deliberation.Situation {
        var here = Deliberation.Situation(plan: world.plan, graph: world.graph,
                                         configuration: configuration, cellSize: cell)
        here.enemyBelief = at(20, 1)
        return here
    }

    func testTheRoomsAreTrulyApart() throws {
        // The premise every test below rests on, asserted rather than assumed.
        XCTAssertTrue(Route.between(node(2, 1), node(20, 1), in: world.graph).isEmpty,
                      "the two rooms are joined, so nothing here is about an unreachable target")
        XCTAssertFalse(Route.between(node(2, 1), node(8, 1), in: world.graph).isEmpty,
                       "the left room is not walkable within itself")
    }

    func testAnActionTheGraphCannotRouteToIsSpentAndRemembered() throws {
        var bots = [try westerner()]
        bots = bots.map { bot in var copy = bot; copy.action = .advance(to: node(20, 1)); return copy }
        Execution.walk(&bots, seconds: 1.0 / 60, world: world, routeOrder: [], holding: nil, now: now)

        XCTAssertNil(try element(0, of: bots).action, "the action with no route was not spent")
        XCTAssertEqual(try element(0, of: bots).unreachable, .advance(to: node(20, 1)),
                       "the action with no route was not remembered")
    }

    func testArrivingIsNotBeingCutOffAndExcludesNothing() throws {
        // A bot standing on the cell its action names has arrived: the action is spent
        // the same way and nothing is held against the next slot.
        var bots = [try westerner()]
        bots = bots.map { bot in var copy = bot; copy.action = .explore(to: node(2, 1)); return copy }
        Execution.walk(&bots, seconds: 1.0 / 60, world: world, routeOrder: [], holding: nil, now: now)

        XCTAssertNil(try element(0, of: bots).action)
        XCTAssertNil(try element(0, of: bots).unreachable, "arriving was read as being cut off")
    }

    func testTheExcludedAdvanceIsLeftOutOfTheSlotItEarns() throws {
        // The quiet motives are where an advance is offered, so that is where the
        // exclusion has to bite: the bot goes to look instead. It has not seen the far
        // end of its own room, so looking is somewhere it can go.
        var bot = try westerner()
        var here = situation()
        here.knows = { $0.x < 8 }
        XCTAssertEqual(Deliberation.quiet(for: bot, in: here), .advance(to: node(20, 1)),
                       "the bot does not advance on what it believes, so this test proves nothing")

        bot.unreachable = .advance(to: node(20, 1))
        let instead = try XCTUnwrap(Deliberation.quiet(for: bot, in: here),
                                    "with the advance excluded the bot was given nothing at all")
        XCTAssertNotEqual(instead, .advance(to: node(20, 1)), "the excluded advance was offered again")
        if case .explore = instead {} else { XCTFail("expected it to go and look, got \(instead)") }
    }

    func testAnExcludedCoverIsLeftOutOfTheScores() throws {
        // The same for an action `scores` does offer. A room of its own for this one: a
        // wall to hide behind, and the snake in the open where it can see the bot.
        let walled = try make(["..........",
                               ".#........"])
        var bot = try XCTUnwrap(Bot(id: 0, squad: .red, archetype: .assault, at: at(1, 0), floor: 0,
                                    configuration: configuration))
        var here = Deliberation.Situation(plan: walled.plan, graph: walled.graph,
                                          configuration: configuration, cellSize: cell)
        here.snake = [at(9, 0)]
        here.inView = here.snake
        let cover = try XCTUnwrap(Deliberation.cover(for: bot, from: here.snake, enemies: [], in: here),
                                  "no cover to exclude, so this test proves nothing")

        XCTAssertTrue(Deliberation.scores(for: bot, in: here).contains { $0.action == .takeCover(at: cover.node) })
        bot.unreachable = .takeCover(at: cover.node)
        XCTAssertFalse(Deliberation.scores(for: bot, in: here).contains { $0.action == .takeCover(at: cover.node) },
                       "the excluded cover was scored anyway")
    }

    func testTheSlotSpendsTheExclusionAndTheSlotAfterScoresItAgain() throws {
        // Three slots with a walk between each: advance, something else, advance again.
        var bots = [try westerner()]
        let step = 1.0 / 60
        func slot() { _ = Execution.deliberate(&bots, slots: [0], world: world, now: now) }
        func walk() { Execution.walk(&bots, seconds: step, world: world, routeOrder: [], holding: nil, now: now) }

        slot()
        let first = try XCTUnwrap(try element(0, of: bots).action, "the first slot chose nothing")
        guard case .advance(let goal) = first else { return XCTFail("it did not try the other room, it chose \(first)") }
        XCTAssertGreaterThan(goal.x, 11, "it did not try the other room, it advanced to \(goal)")
        walk()
        XCTAssertNotNil(try element(0, of: bots).unreachable)

        slot()
        let second = try XCTUnwrap(try element(0, of: bots).action, "the slot it earned chose nothing")
        XCTAssertNotEqual(second, .advance(to: goal), "it asked for the route it cannot have")
        XCTAssertNil(try element(0, of: bots).unreachable, "the exclusion outlived the slot it was for")
    }

    func testBothSquadsStartInOneRoomSoNoMatchHereCanCutABotOff() throws {
        // Why there is no match-level test above, written down rather than left for
        // somebody to wonder about. FR-BOT-350 places the squads around the two cells
        // farthest apart *that the snake's start reaches*, so in a cut arena both
        // squads land in the snake's room and each bot's belief about the other crew is
        // somewhere it can walk to. Everything a bot makes for in a connected arena is
        // walked out over the graph and reachable by construction — cover, flight, the
        // cell it has not seen, the ordered zone — so the only way a route comes back
        // empty in play is the one FR-SNAKE-040 will make, with the tail across a
        // passage. Until then this branch is exercised on a cut map and not in a match.
        let game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        let rooms = Set(game.bots.map { Execution.cell(of: $0, world: world).x < 10 })
        XCTAssertEqual(rooms.count, 1, "the squads did land in different rooms, so a match-level test is possible")
        XCTAssertFalse(game.bots.isEmpty, "no bots were placed at all")
    }
}
