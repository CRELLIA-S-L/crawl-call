// A bot gathers speed and slows to a stop (FR-BOT-290), and bots do not pass through
// one another (FR-BOT-300): walked frame by frame over the shipped map.
//
// verifies: FR-BOT-290, FR-BOT-300
import XCTest
@testable import CrawlCall

final class BotMotionTests: XCTestCase {
    private var world: World!
    private let frame = 1.0 / 60
    private var cell: Double { world.configurations.tuning.navigationGraphCellSize }
    private var radius: Double { world.configurations.tuning.bodyRadius }
    private var acceleration: Double { world.configurations.bot.acceleration }

    override func setUpWithError() throws {
        try super.setUpWithError()
        world = try Launch.world().get()
    }

    private func bot(_ id: Int = 0, at node: NavigationGraph.Node) throws -> Bot {
        try XCTUnwrap(Bot(id: id, squad: .red, archetype: .assault,
                          at: SIMD3(Double(node.x) * cell, 0, Double(node.z) * cell), floor: 0,
                          configuration: world.configurations.bot))
    }

    private func sent(_ bot: Bot, to goal: NavigationGraph.Node) -> Bot {
        var bot = bot
        let here = NavigationGraph.Node(floor: 0, x: Int((bot.position.x / cell).rounded()),
                                        z: Int((bot.position.z / cell).rounded()))
        bot.action = .flee(to: goal)
        bot.path = Route.between(here, goal, in: world.graph)
        return bot
    }

    func testABotGathersSpeedThenSlowsToAStopWhereItsRouteEnds() throws {
        let start = NavigationGraph.Node(floor: 0, x: 6, z: 6), goal = NavigationGraph.Node(floor: 0, x: 24, z: 6)
        var bots = [sent(try bot(at: start), to: goal)]
        let top = try XCTUnwrap(world.configurations.bot.archetypes["assault"]).runSpeed
        let end = SIMD3(Double(goal.x) * cell, 0, Double(goal.z) * cell)
        var last = 0.0, fastest = 0.0, frames = 0
        while !(try element(0, of: bots)).path.isEmpty && frames < 600 {
            Execution.walk(&bots, seconds: frame, world: world)
            let now = try element(0, of: bots)
            XCTAssertLessThanOrEqual(abs(now.speed - last), acceleration * frame + 1e-9, "speed changed faster than the acceleration")
            XCTAssertLessThanOrEqual(now.speed, top + 1e-9)
            // Never faster than it could still stop by the end, braking at the
            // acceleration.
            let left = Execution.remaining(of: now, over: world.graph, cellSize: cell, floorHeight: world.kit.floorHeight)
            XCTAssertLessThanOrEqual(now.speed * now.speed, 2 * acceleration * (left + now.speed * frame) + 1e-6)
            fastest = max(fastest, now.speed)
            last = now.speed
            frames += 1
        }
        let arrived = try element(0, of: bots)
        XCTAssertEqual(fastest, top, accuracy: 1e-9, "the bot never reached its run speed over nine metres")
        XCTAssertEqual(arrived.speed, 0, "the bot did not come to rest")
        XCTAssertEqual(Perception.metres(arrived.position, end), 0, accuracy: 1e-6, "the bot stopped short or overshot")
        // Its first frame was a start, not a leap.
        var fresh = [sent(try bot(at: start), to: goal)]
        Execution.walk(&fresh, seconds: frame, world: world)
        XCTAssertEqual(try element(0, of: fresh).speed, acceleration * frame, accuracy: 1e-9)
    }

    func testABotWithNowhereToWalkStands() throws {
        var standing = try bot(at: NavigationGraph.Node(floor: 0, x: 10, z: 10))
        standing.speed = 3
        standing.action = .reload
        var bots = [standing]
        let was = standing.position
        Execution.walk(&bots, seconds: frame, world: world)
        XCTAssertEqual(try element(0, of: bots).speed, 0)
        XCTAssertEqual(try element(0, of: bots).position, was)
    }

    func testTwoBotsOnOneSpotPartToTwoRadiiApart() throws {
        let here = NavigationGraph.Node(floor: 0, x: 10, z: 10)
        var bots = [try bot(0, at: here), try bot(1, at: here)]
        for _ in 0..<5 { Execution.walk(&bots, seconds: frame, world: world) }
        let apart = Perception.metres(try element(0, of: bots).position, try element(1, of: bots).position)
        XCTAssertGreaterThanOrEqual(apart, 2 * radius - 1e-9, "the two bots still stand inside each other")
        for bot in bots {
            let under = NavigationGraph.Node(floor: 0, x: Int((bot.position.x / cell).rounded()), z: Int((bot.position.z / cell).rounded()))
            XCTAssertTrue(world.graph.isWalkable(under))
        }
    }

    func testNoBotIsPushedWhereNoneCanStand() throws {
        // Two bots in a corner of the room, one on top of the other: whatever parting
        // they manage, neither ends up over a wall.
        let corner = NavigationGraph.Node(floor: 0, x: 5, z: 5)
        XCTAssertTrue(world.graph.isWalkable(corner), "the room's corner moved, so the test proves nothing")
        var bots = [try bot(0, at: corner), try bot(1, at: corner), try bot(2, at: corner)]
        for _ in 0..<30 { Execution.walk(&bots, seconds: frame, world: world) }
        for bot in bots {
            let under = NavigationGraph.Node(floor: 0, x: Int((bot.position.x / cell).rounded()), z: Int((bot.position.z / cell).rounded()))
            XCTAssertTrue(world.graph.isWalkable(under), "bot \(bot.id) was pushed over \(under)")
        }
    }

    func testABotInTheSnakesMouthIsNotPushedAndTheOtherGivesWayByAllOfIt() throws {
        let here = NavigationGraph.Node(floor: 0, x: 10, z: 10)
        var held = try bot(0, at: here)
        var other = try bot(1, at: here)
        other.position.x += 0.1
        held.action = nil
        var bots = [held, other]
        let still = held.position
        Execution.walk(&bots, seconds: frame, world: world, holding: held.id)
        XCTAssertEqual(try element(0, of: bots).position, still, "the bot being eaten was pushed")
        XCTAssertEqual(Perception.metres(try element(0, of: bots).position, try element(1, of: bots).position),
                       2 * radius, accuracy: 1e-9)
    }
}
