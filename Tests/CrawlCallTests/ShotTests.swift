// A round has to be visible (FR-VIEW-170): the model has to say where each round in
// flight is, and the view has to put a streak on exactly that.
//
// file verifies: FR-VIEW-170, FR-BOT-060
import RealityKit
import XCTest
@testable import CrawlCall

final class ShotTests: XCTestCase {
    private func world() throws -> World { try Launch.world(map: "room").get() }

    private func cells(in world: World) -> [NavigationGraph.Node] {
        world.graph.nodes.filter { $0.floor == 0 }.sorted { ($0.z, $0.x) < ($1.z, $1.x) }
    }

    private func bot(at node: NavigationGraph.Node, in world: World) throws -> Bot {
        let cell = world.configurations.tuning.navigationGraphCellSize
        return try XCTUnwrap(Bot(id: 0, squad: .red, archetype: .assault,
                                 at: SIMD3(Double(node.x) * cell, 0, Double(node.z) * cell),
                                 floor: 0, configuration: world.configurations.bot))
    }

    func testARoundIsReportedFromTheShootersEyesAtTheSnakesMiddle() throws {
        let world = try world()
        let here = try element(0, of: cells(in: world))
        let cell = world.configurations.tuning.navigationGraphCellSize
        var bots = [try bot(at: here, in: world)]
        bots[try checkedIndex(0, of: bots)].knowledge.snake = [0: .init(point: .zero, time: 0)]
        let target = SIMD3(Double(here.x) * cell + cell, 0, Double(here.z) * cell)

        let volley = Execution.deliberate(&bots, slots: [0], snake: [target], world: world)
        let round = try XCTUnwrap(volley.rounds.first)
        XCTAssertEqual(volley.rounds.count, 1, "one round a step is the cadence FR-BOT-060 fixes")
        // From the shooter's eyes, which is where it looked and fired from (ADR-0022).
        XCTAssertEqual(round.from.x, try element(0, of: bots).position.x, accuracy: 1e-12)
        XCTAssertEqual(round.from.y, try element(0, of: bots).position.y + world.configurations.bot.eyeHeight, accuracy: 1e-12)
        XCTAssertEqual(round.from.z, try element(0, of: bots).position.z, accuracy: 1e-12)
        XCTAssertEqual(round.position, round.from, "a round just sent is somewhere other than where it left")
        // At the middle of the body over the part it saw, which lies on the ground.
        let radius = world.configurations.tuning.bodyRadius
        XCTAssertEqual(Perception.metres(round.towards, target + SIMD3(0, radius, 0)), 0, accuracy: 1e-12)
        XCTAssertEqual(round.squad, .red)
    }

    func testABotFiresOverWhatItLooksOver() throws {
        // A bot that sees the snake over a box lower than its eyes can shoot it there:
        // the line of fire leaves from the same eyes as the line of sight (ADR-0022).
        // Fired from the floor, the box would stop the shot the bot could see to take.
        let base = try world()
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n............\n", kit: base.kit)
        let cell = base.configurations.tuning.navigationGraphCellSize
        let floor = ScenePlan.make(map: map, kit: base.kit, cellSize: cell)
        let low = base.configurations.bot.eyeHeight / 2
        let box = ScenePlan.Piece(module: "kerb", size: SIMD3(cell, low, cell),
                                  centre: SIMD3(cell, low / 2 - MapGrid.surfaceOverlap, 0),
                                  colour: SIMD3(0.5, 0.5, 0.5), level: 0)
        let plan = ScenePlan(pieces: floor.pieces + [box], cellSize: floor.cellSize, floorHeight: floor.floorHeight)
        let world = World(configurations: base.configurations, kit: base.kit, map: map,
                          setting: base.setting, graph: NavigationGraph.derive(from: map, stepHeight: ShippedTuning.stepHeight), plan: plan)
        var bots = [try bot(at: NavigationGraph.Node(floor: 0, x: 0, z: 0), in: world)]
        let snake = [SIMD3(4.0, 0, 0)]
        XCTAssertTrue(Sight.isClear(from: try element(0, of: bots).eye, to: try element(0, of: snake), through: plan))
        XCTAssertFalse(Sight.isClear(from: try element(0, of: bots).position, to: try element(0, of: snake), through: plan),
                       "the box does not stand in the way from the floor, so this proves nothing")
        bots[try checkedIndex(0, of: bots)].knowledge.snake = [0: .init(point: .zero, time: 0)]
        let volley = Execution.deliberate(&bots, slots: [0], snake: snake, world: world)
        XCTAssertEqual(volley.rounds.count, 1, "the bot saw the snake over the box and did not fire")
    }

    func testABotLooksAndFiresFromTheEyeHeightItIsConfiguredWith() throws {
        // Not the shipped number: a bot configured with its eyes at half a metre fires
        // from half a metre, so the height comes from the configuration and not from
        // anywhere in the code (IF-BOT-010, ADR-0022).
        let base = try world()
        let url = try XCTUnwrap(Bundle.main.url(forResource: "bot", withExtension: "json", subdirectory: "config"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as? [String: Any])
        json["eyeHeight"] = 0.5
        let configuration = try Configurations.decode(BotConfiguration.self, named: "bot", schema: BotConfiguration.schema,
                                                      from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNotEqual(configuration.eyeHeight, base.configurations.bot.eyeHeight, accuracy: 1e-9,
                          "the shipped eye height is half a metre already, so this proves nothing")
        let world = World(configurations: Configurations(snake: base.configurations.snake, tuning: base.configurations.tuning,
                                                         view: base.configurations.view, bot: configuration,
                                                         match: base.configurations.match, scoring: base.configurations.scoring),
                          kit: base.kit, map: base.map, setting: base.setting, graph: base.graph, plan: base.plan)
        let here = try element(0, of: cells(in: world))
        let cell = world.configurations.tuning.navigationGraphCellSize
        var bots = [try bot(at: here, in: world)]
        bots[try checkedIndex(0, of: bots)].knowledge.snake = [0: .init(point: .zero, time: 0)]
        let target = SIMD3(Double(here.x) * cell + cell, 0, Double(here.z) * cell)
        let volley = Execution.deliberate(&bots, slots: [0], snake: [target], world: world)
        let round = try XCTUnwrap(volley.rounds.first)
        XCTAssertEqual(round.from.y, try element(0, of: bots).position.y + 0.5, accuracy: 1e-12)
    }

    func testRoundsFlyAndAreSpentRatherThanPilingUp() throws {
        // Driven through a real match rather than asserted about the type: what the
        // requirement promises is that what is on screen at any moment is the rounds
        // in flight, and a list that only grew would satisfy "a streak is drawn" and
        // none of the rest.
        //
        // The snake is walked at a bot, because a snake standing still is a snake
        // nobody notices and therefore nobody shoots at (FR-BOT-050).
        let world = try world()
        let configuration = world.configurations.bot
        let cell = world.configurations.tuning.navigationGraphCellSize
        let start = try XCTUnwrap(Game.firstStart(in: world))
        var game = Game(world: world, start: start)
        let prey = try XCTUnwrap(game.bots.filter { $0.floor == 0 }.first)
        var route = Route.between(start,
                                  NavigationGraph.Node(floor: 0,
                                                       x: Int((prey.position.x / cell).rounded()),
                                                       z: Int((prey.position.z / cell).rounded())),
                                  in: world.graph)
        var fired = false
        var flew = false
        var most = 0
        for _ in 0..<1800 {
            if let next = route.first {
                let there = SIMD3(Double(next.x) * cell, 0, Double(next.z) * cell)
                let toward = SIMD2(there.x - game.snake.head.x, there.z - game.snake.head.z)
                let length = (toward.x * toward.x + toward.y * toward.y).squareRoot()
                if length < 0.1 { route.removeFirst() }
                game.apply(.move(direction: length > 0 ? SIMD2(toward.x / length, toward.y / length) : .zero))
            }
            game.advance(seconds: 1.0 / 60)
            fired = fired || !game.rounds.isEmpty
            flew = flew || game.rounds.contains { $0.flown > 0 }
            most = max(most, game.rounds.count)
            XCTAssertTrue(game.rounds.allSatisfy { $0.flown < configuration.roundRange },
                          "a round outlived its range")
        }
        XCTAssertTrue(fired, "nobody fired in thirty seconds of walking into two squads")
        XCTAssertTrue(flew, "no round ever left its shooter's eyes")
        // As many as a bot can have in flight, a bot: the pool the view draws them with.
        // What it refuses is accumulation: thirty seconds of never clearing the list
        // would be a thousand.
        XCTAssertLessThanOrEqual(most, game.bots.count * Tracers.perBot(for: configuration),
                                 "rounds are piling up rather than being spent")
    }

    func testThePoolHoldsWhatOneBotCanHaveInFlight() throws {
        // The shipped numbers: 20 m at 25 m/s is 0.8 s, four periods of 0.2 s, and one
        // more for the frame one is sent in as another is spent.
        let configuration = try world().configurations.bot
        let flight = configuration.roundRange / configuration.roundSpeed
        XCTAssertEqual(Tracers.perBot(for: configuration),
                       Int((flight / configuration.deliberationPeriod).rounded(.up)) + 1)
        XCTAssertEqual(Tracers.perBot(for: configuration), Tracers.perBot,
                       "a pool made without the configuration holds a different number from the shipped one")
    }

    private func round(from: SIMD3<Double>, towards: SIMD3<Double>, flown: Double, squad: Squad = .red) throws -> Round {
        var made = try XCTUnwrap(Round(shooter: 0, squad: squad, from: from, towards: towards, damage: 1))
        made.position = from + made.direction * flown
        made.flown = flown
        return made
    }

    /// The two ends of a bar as drawn: it is a metre deep and scaled along +z, so its
    /// ends are half its length either way along its own z, turned and moved into the
    /// scene.
    @MainActor
    private func ends(of bar: Entity) -> (SIMD3<Float>, SIMD3<Float>) {
        let half = SIMD3<Float>(0, 0, bar.scale.z / 2)
        return (bar.position + bar.orientation.act(half), bar.position - bar.orientation.act(half))
    }

    @MainActor
    func testARoundIsDrawnAsAStreakEndingWhereItIs() throws {
        let from = SIMD3(1.0, 1.25, 2.0)
        let towards = SIMD3(4.0, 1.25, 6.0)       // three by four: five metres, along (0.6, 0, 0.8)
        let flying = try round(from: from, towards: towards, flown: 3)
        let entity = ShotEntity.make(for: [try bot(at: NavigationGraph.Node(floor: 0, x: 0, z: 0),
                                                   in: try world())])
        ShotEntity.update(entity, from: [flying])

        let drawn = entity.children.filter(\.isEnabled)
        XCTAssertEqual(drawn.count, 1)
        let (head, tail) = ends(of: try XCTUnwrap(drawn.first))
        // From where it is back along its way by the streak's length.
        let front = SIMD3<Float>(flying.position)
        let back = SIMD3<Float>(flying.position - flying.direction * Tracers.streak)
        let matched = min(simd_distance(head, front) + simd_distance(tail, back),
                          simd_distance(head, back) + simd_distance(tail, front))
        XCTAssertEqual(matched, 0, accuracy: 1e-3, "the streak does not end where the round is")
        XCTAssertEqual(Double(simd_distance(head, tail)), Tracers.streak, accuracy: 1e-3)
    }

    @MainActor
    func testAStreakReachesNoFurtherBackThanTheShootersEyes() throws {
        let from = SIMD3(0.0, 1.0, 0.0)
        let short = Tracers.streak / 4
        let flying = try round(from: from, towards: SIMD3(5, 1, 0), flown: short)
        let entity = ShotEntity.make(for: [try bot(at: NavigationGraph.Node(floor: 0, x: 0, z: 0),
                                                   in: try world())])
        ShotEntity.update(entity, from: [flying])
        let (head, tail) = ends(of: try XCTUnwrap(entity.children.first(where: \.isEnabled)))
        XCTAssertEqual(Double(simd_distance(head, tail)), short, accuracy: 1e-4)
        XCTAssertEqual(Double(min(simd_distance(head, SIMD3<Float>(from)), simd_distance(tail, SIMD3<Float>(from)))),
                       0, accuracy: 1e-4, "the streak starts somewhere other than the shooter's eyes")
    }

    @MainActor
    func testAStreakIsTakenOffScreenWhenItsRoundIsSpent() throws {
        let entity = ShotEntity.make(for: [try bot(at: NavigationGraph.Node(floor: 0, x: 0, z: 0),
                                                   in: try world())])
        ShotEntity.update(entity, from: [try round(from: .zero, towards: SIMD3(2, 0, 0), flown: 1)])
        XCTAssertEqual(entity.children.filter(\.isEnabled).count, 1)

        ShotEntity.update(entity, from: [])
        XCTAssertEqual(entity.children.filter(\.isEnabled).count, 0,
                       "a streak stayed on screen after its round was spent")
    }

    @MainActor
    func testEachSquadsRoundIsDrawnInItsOwnColour() throws {
        let world = try world()
        let two = [try bot(at: element(0, of: cells(in: world)), in: world),
                   try XCTUnwrap(Bot(id: 1, squad: .blue, archetype: .assault,
                                     at: SIMD3(2, 0, 2), floor: 0,
                                     configuration: world.configurations.bot))]
        let entity = ShotEntity.make(for: two)
        ShotEntity.update(entity, from: [try round(from: .zero, towards: SIMD3(2, 0, 0), flown: 1, squad: .red),
                                         try round(from: SIMD3(0, 0, 1), towards: SIMD3(2, 0, 1), flown: 1, squad: .blue)])

        let drawn = entity.children.filter(\.isEnabled)
        XCTAssertEqual(drawn.count, 2)
        // FR-VIEW-060 asks the three channels to agree, so a red round is drawn with
        // the colour a red body is drawn with.
        XCTAssertEqual(drawn.filter { $0.name.hasSuffix("r") }.count, 1)
        XCTAssertEqual(drawn.filter { $0.name.hasSuffix("b") }.count, 1)
    }
}
