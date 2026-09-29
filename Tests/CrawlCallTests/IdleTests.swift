// A bot with nothing else worth doing: it advances on where it believes the enemy is
// (FR-BOT-360), goes to see what it has not seen (FR-BOT-370), and, standing, looks
// round towards where a threat may be (FR-BOT-380) — and none of it ever outweighs
// something that scores.
//
// verifies: FR-BOT-360, FR-BOT-370, FR-BOT-380
import XCTest
@testable import CrawlCall

final class IdleTests: XCTestCase {
    private var shipped: World!
    private var configuration: BotConfiguration!
    private let cell = 0.5

    override func setUpWithError() throws {
        try super.setUpWithError()
        shipped = try Launch.world().get()
        configuration = shipped.configurations.bot
    }

    private func world(_ rows: [String]) throws -> World {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        return World(configurations: shipped.configurations, kit: shipped.kit, map: map, setting: shipped.setting,
                     graph: NavigationGraph.derive(from: map, stepHeight: shipped.configurations.tuning.stepHeight),
                     plan: ScenePlan.make(map: map, kit: shipped.kit, cellSize: cell))
    }

    private var strip: [String] { Array(repeating: String(repeating: ".", count: 40), count: 3) }

    private func situation(in world: World) -> Deliberation.Situation {
        Deliberation.Situation(plan: world.plan, graph: world.graph, configuration: configuration, cellSize: cell)
    }

    private func at(_ x: Int, _ z: Int) -> SIMD3<Double> { SIMD3(Double(x) * cell, 0, Double(z) * cell) }

    private func bot(at x: Int, _ z: Int = 1, aggression: Double = 0.5, squad: Squad = .red, id: Int = 0) throws -> Bot {
        var bot = try XCTUnwrap(Bot(id: id, squad: squad, archetype: .assault, at: at(x, z), floor: 0,
                                    configuration: configuration))
        bot.weights = BotConfiguration.Weights(panic: bot.weights.panic, discipline: bot.weights.discipline,
                                               aggression: aggression, selfSacrifice: bot.weights.selfSacrifice)
        bot.ammunition = try XCTUnwrap(configuration.archetypes[Archetype.assault.rawValue]).magazine
        return bot
    }

    // MARK: advancing and looking (FR-BOT-360, FR-BOT-370)

    func testWithNothingElseToDoABotAdvancesOnWhereItBelievesTheEnemyIs() throws {
        var here = situation(in: try world(strip))
        here.enemyBelief = at(35, 1)
        let choice = Deliberation.choose(for: try bot(at: 2), in: here)
        guard case .advance(let to) = choice else { return XCTFail("chose \(String(describing: choice))") }
        XCTAssertEqual(to, NavigationGraph.Node(floor: 0, x: 35, z: 1))
    }

    func testWithNothingElseToDoABotGoesToTheNearestCellItHasNotSeen() throws {
        var here = situation(in: try world(strip))
        // It knows the cells up to column 9; the first it does not is column 10.
        here.knows = { $0.x < 10 }
        let choice = Deliberation.choose(for: try bot(at: 2), in: here)
        guard case .explore(let to) = choice else { return XCTFail("chose \(String(describing: choice))") }
        XCTAssertEqual(to.x, 10)
    }

    func testAggressionDecidesBetweenAdvancingAndLooking() throws {
        var here = situation(in: try world(strip))
        here.enemyBelief = at(35, 1)
        here.knows = { $0.x < 10 }
        guard case .advance = Deliberation.choose(for: try bot(at: 2, aggression: 0.8), in: here)
        else { return XCTFail("an aggressive bot went looking") }
        guard case .explore = Deliberation.choose(for: try bot(at: 2, aggression: 0.2), in: here)
        else { return XCTFail("a cautious bot went on at the enemy") }
    }

    func testAMotiveForTheQuietNeverOutweighsAThreat() throws {
        // The snake in view and near: whatever it chooses, it is not a stroll.
        var here = situation(in: try world(strip))
        here.enemyBelief = at(35, 1)
        here.knows = { $0.x < 10 }
        here.snake = [at(6, 1)]
        here.inView = here.snake
        here.snakeHead = here.snake.first
        let choice = try XCTUnwrap(Deliberation.choose(for: try bot(at: 2, aggression: 1), in: here))
        switch choice {
        case .advance, .explore: XCTFail("went on a stroll with the snake two metres off: \(choice)")
        default: break
        }
    }

    func testABotThatHasSeenEverythingAndBelievesNothingHasNowhereToGo() throws {
        let here = situation(in: try world(strip))
        XCTAssertNil(Deliberation.quiet(for: try bot(at: 2), in: here))
    }

    // MARK: finding a place empty (FR-BOT-360)

    func testComingToWhereAnEnemyWasSeenAndFindingNobodyItIsNotBelievedAgain() throws {
        let world = try world(strip)
        let enemy = 7
        var seeker = try bot(at: 20)
        seeker.knowledge.enemies[enemy] = .init(point: at(20, 1), time: 1)
        seeker.knowledge.enemyStart = Knowledge.Area(centre: at(38, 1), radius: 1)
        var bots = [seeker]
        _ = Execution.deliberate(&bots, slots: [seeker.id], world: world, now: 5)
        let after = try XCTUnwrap(bots.first)
        XCTAssertNil(after.knowledge.enemies[enemy], "still believes the enemy is where it is not")
        // Nor is it told it again by a squadmate who saw it there before.
        var told = after.knowledge
        var mate = Knowledge()
        mate.enemies[enemy] = .init(point: at(20, 1), time: 1)
        told.hear(mate, seenBy: 4)
        XCTAssertNil(told.enemies[enemy], "a squadmate's old sighting brought it back")
        // A newer one is believed.
        mate.enemies[enemy] = .init(point: at(30, 1), time: 6)
        told.hear(mate, seenBy: 7)
        XCTAssertNotNil(told.enemies[enemy])
        // With the sighting gone, the enemy's start is where it goes.
        guard case .advance(let to) = after.action else { return XCTFail("chose \(String(describing: after.action))") }
        XCTAssertEqual(to.x, 38)
    }

    func testTheEnemysStartIsNoLongerBelievedOnceTheBotHasBeenThere() throws {
        let world = try world(strip)
        var seeker = try bot(at: 30)
        seeker.knowledge.enemyStart = Knowledge.Area(centre: at(31, 1), radius: 2)
        var bots = [seeker]
        _ = Execution.deliberate(&bots, slots: [seeker.id], world: world, now: 1)
        XCTAssertNil(bots.first?.knowledge.enemyStart)
    }

    func testInAMatchTheSquadsGoOutAndFindEachOther() throws {
        // The squads at the strip's two ends, the snake held still out of their sight:
        // left to themselves, they meet.
        // The snake at the far end of a corridor off the strip's middle, out of sight of it.
        let corridor = String(repeating: " ", count: 40) + "." + String(repeating: " ", count: 39)
        let rows = Array(repeating: String(repeating: ".", count: 80), count: 3) + Array(repeating: corridor, count: 30)
        var game = Game(world: try world(rows), start: NavigationGraph.Node(floor: 0, x: 40, z: 32))
        func apart() -> Double {
            let red = game.bots.filter { $0.squad == .red }.map(\.position.x)
            let blue = game.bots.filter { $0.squad == .blue }.map(\.position.x)
            return abs(red.reduce(0, +) / Double(red.count) - blue.reduce(0, +) / Double(blue.count))
        }
        let before = apart()
        var met = false
        for _ in 0..<(60 * 30) where !met {
            game.advance(seconds: 1.0 / 60)
            met = game.bots.contains { !$0.knowledge.enemies.isEmpty || !$0.knowledge.fallen.isEmpty }
        }
        XCTAssertTrue(met, "in thirty seconds no bot saw anybody of the other squad")
        XCTAssertLessThan(apart(), before)
    }

    // MARK: looking round (FR-BOT-380)

    func testABotStandingIdleLooksRoundOnceAnIntervalTowardsAThreatFirst() throws {
        let world = try world(strip)
        var sentry = try bot(at: 20)
        sentry.knowledge.outline = world.graph.nodes
        sentry.facing = 0 // +z: across the strip, at its edge
        // What it believes of the enemy lies along the strip, to −x.
        sentry.knowledge.enemyStart = Knowledge.Area(centre: at(2, 1), radius: 1)
        var bots = [sentry]
        let interval = configuration.lookRoundInterval
        let frame = 1.0 / 60
        var now = 10.0
        // As it stops it turns from the edge before it (FR-BOT-340), and that is its
        // first look; it holds it for the interval.
        Execution.walk(&bots, seconds: frame, world: world, now: now)
        let first = try XCTUnwrap(bots.first?.lookout)
        now += interval * 0.5
        Execution.walk(&bots, seconds: frame, world: world, now: now)
        XCTAssertEqual(try XCTUnwrap(bots.first?.lookout), first, accuracy: 1e-12, "looked round before the interval")
        // Then a new way, and the threat's.
        now += interval * 0.5
        Execution.walk(&bots, seconds: frame, world: world, now: now)
        let second = try XCTUnwrap(bots.first?.lookout)
        XCTAssertGreaterThan(abs(atan2(sin(second - first), cos(second - first))), 1e-6, "did not look anywhere new")
        XCTAssertLessThan(abs(atan2(sin(second + .pi / 2), cos(second + .pi / 2))), .pi / 8,
                          "did not turn towards the threat, but to \(second)")
    }

    func testABotLookingRoundDoesNotLookAtAWall() throws {
        // A wall along the strip's +z edge, a cell away: the ways into it are not looked at.
        let world = try world(["........................................",
                               "........................................",
                               "########################################"])
        var sentry = try bot(at: 20, 1)
        sentry.knowledge.outline = world.graph.nodes
        for x in 0..<40 {
            let wall = NavigationGraph.Node(floor: 0, x: x, z: 2)
            sentry.knowledge.outline.insert(wall)
            sentry.knowledge.cells[wall] = .init(stands: "wall", time: 0)
        }
        var bots = [sentry]
        for step in 0..<6 {
            Execution.walk(&bots, seconds: 1.0 / 60, world: world, now: Double(step) * configuration.lookRoundInterval)
            let way = try XCTUnwrap(bots.first?.lookout)
            XCTAssertGreaterThanOrEqual(Execution.openGround(for: try XCTUnwrap(bots.first), towards: way, world: world),
                                        Looking.openEnough, "looked at the wall, \(way)")
        }
    }

    func testABotWithSomethingToDoDoesNotLookRound() throws {
        let world = try world(strip)
        var busy = try bot(at: 20)
        busy.action = .reload
        busy.facing = 1
        busy.knowledge.outline = world.graph.nodes
        busy.knowledge.enemyStart = Knowledge.Area(centre: at(2, 1), radius: 1)
        var bots = [busy]
        Execution.walk(&bots, seconds: 1.0 / 60, world: world, now: 10)
        let first = try XCTUnwrap(bots.first?.lookout)
        for step in 1...3 {
            Execution.walk(&bots, seconds: 1.0 / 60, world: world, now: 10 + Double(step) * configuration.lookRoundInterval)
            XCTAssertEqual(try XCTUnwrap(bots.first?.lookout), first, accuracy: 1e-12, "a bot with something to do looked round")
        }
    }
}
