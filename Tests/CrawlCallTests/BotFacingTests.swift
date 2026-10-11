// A bot turns to face where it goes (FR-BOT-280): the way it walks, or while it fires
// what it fires at, no faster than the turn speed; the two squads start facing each
// other; and the figure on screen faces as the model does.
//
// file verifies: FR-BOT-280, FR-BOT-430
import RealityKit
import XCTest
@testable import CrawlCall

final class BotFacingTests: XCTestCase {
    private var world: World!
    private var cell: Double { world.configurations.tuning.navigationGraphCellSize }
    private var perFrame: Double { world.configurations.bot.turnSpeed * .pi / 180 / 60 }

    override func setUpWithError() throws {
        try super.setUpWithError()
        world = try Launch.world().get()
    }

    private func bot(at node: NavigationGraph.Node, id: Int = 0) throws -> Bot {
        try XCTUnwrap(Bot(id: id, squad: .red, archetype: .assault,
                          at: SIMD3(Double(node.x) * cell, 0, Double(node.z) * cell), floor: 0,
                          configuration: world.configurations.bot))
    }

    private func gap(_ a: Double, _ b: Double) -> Double {
        abs(atan2(sin(a - b), cos(a - b)))
    }

    func testTheShortWayRoundIsTakenNoFasterThanAllowed() {
        XCTAssertEqual(Turning.toward(0.1, from: 0, by: 1), 0.1, accuracy: 1e-12)
        XCTAssertEqual(Turning.toward(.pi / 2, from: 0, by: 0.2), 0.2, accuracy: 1e-12)
        // From just short of a half turn one way to just past it: the short way is
        // across the half turn, not back through zero.
        let turned = Turning.toward(-3.0, from: 3.0, by: 0.1)
        XCTAssertEqual(gap(turned, 3.1), 0, accuracy: 1e-9)
        XCTAssertEqual(Turning.angle(from: .zero, to: SIMD3(1, 0, 0)) ?? .nan, .pi / 2, accuracy: 1e-12)
        XCTAssertNil(Turning.angle(from: .zero, to: SIMD3(0, 2, 0)), "a point straight above is no way to face")
    }

    func testAWalkingBotComesRoundToFaceTheWayItWalks() throws {
        // Along the room's north side, eastwards (+x): facing a quarter turn from +z.
        let start = NavigationGraph.Node(floor: 0, x: 6, z: 6), goal = NavigationGraph.Node(floor: 0, x: 20, z: 6)
        var bot = try bot(at: start)
        bot.facing = .pi   // facing west, away from where it is going
        bot.action = .flee(to: goal)
        bot.path = Route.between(start, goal, in: world.graph)
        var bots = [bot]
        var last = bot.facing
        for _ in 0..<60 {
            Execution.walk(&bots, seconds: 1.0 / 60, world: world)
            let now = try element(0, of: bots).facing
            XCTAssertLessThanOrEqual(gap(now, last), perFrame + 1e-9, "it turned faster than the turn speed")
            last = now
        }
        XCTAssertEqual(gap(last, .pi / 2), 0, accuracy: 1e-6, "the bot does not face the way it walks")
    }

    func testAFiringBotFacesWhatItFiresAtAndAStandingOneKeepsItsFacing() throws {
        let here = NavigationGraph.Node(floor: 0, x: 10, z: 10)
        var firing = try bot(at: here)
        let target = SIMD3(Double(here.x) * cell, 0, Double(here.z) * cell - 3)   // due -z
        firing.action = .fire(at: .snake(at: target))
        var standing = try bot(at: NavigationGraph.Node(floor: 0, x: 12, z: 10), id: 1)
        standing.facing = 1.0
        var bots = [firing, standing]
        for _ in 0..<60 { Execution.walk(&bots, seconds: 1.0 / 60, world: world) }
        // Where it stands now: with no cover beside it, it moves as it fires (FR-BOT-430).
        let towards = try XCTUnwrap(Turning.angle(from: try element(0, of: bots).position, to: target))
        XCTAssertEqual(gap(try element(0, of: bots).facing, towards), 0, accuracy: 1e-2,
                       "the firing bot does not face its target")
        XCTAssertEqual(try element(1, of: bots).facing, 1.0, accuracy: 1e-12, "a bot that neither fired nor moved turned")
    }

    func testABotInTheSnakesMouthDoesNotTurn() throws {
        var held = try bot(at: NavigationGraph.Node(floor: 0, x: 10, z: 10))
        held.action = .fire(at: .snake(at: SIMD3(10, 0, 10)))
        held.facing = 0.3
        var bots = [held]
        for _ in 0..<30 { Execution.walk(&bots, seconds: 1.0 / 60, world: world, holding: held.id) }
        XCTAssertEqual(try element(0, of: bots).facing, 0.3, accuracy: 1e-12)
    }

    func testTheSquadsStartFacingEachOther() throws {
        let start = try XCTUnwrap(Game.firstStart(in: world))
        let game = Game(world: world, start: start)
        let red = game.bots.filter { $0.squad == .red }, blue = game.bots.filter { $0.squad == .blue }
        XCTAssertFalse(red.isEmpty || blue.isEmpty)
        func centre(_ bots: [Bot]) -> SIMD3<Double> { bots.map(\.position).reduce(.zero, +) / Double(bots.count) }
        for (squad, other) in [(red, centre(blue)), (blue, centre(red))] {
            for bot in squad {
                let towards = try XCTUnwrap(Turning.angle(from: bot.position, to: other))
                XCTAssertLessThan(gap(bot.facing, towards), .pi / 4, "\(bot.squad) bot \(bot.id) does not face the other squad")
            }
        }
    }

    @MainActor
    func testTheFigureFacesAsTheModelDoes() throws {
        var bot = try bot(at: NavigationGraph.Node(floor: 0, x: 10, z: 10))
        bot.facing = 1.2
        let entity = BotEntity.make(for: [bot], height: world.configurations.bot.figureHeight)
        BotEntity.update(entity, from: [bot])
        let figure = try XCTUnwrap(entity.children.first)
        let front = figure.orientation.act(SIMD3<Float>(0, 0, 1))
        XCTAssertEqual(Double(atan2(front.x, front.z)), 1.2, accuracy: 1e-5)
    }
}
