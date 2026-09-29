// A shot has to be visible (FR-VIEW-170): the model has to say one happened and
// where it went, and the view has to put a line on exactly that.
//
// verifies: FR-VIEW-170, FR-BOT-060
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

    func testAShotIsReportedWithBothItsEnds() throws {
        let world = try world()
        let here = try element(0, of: cells(in: world))
        let cell = world.configurations.tuning.navigationGraphCellSize
        var bots = [try bot(at: here, in: world)]
        bots[try checkedIndex(0, of: bots)].knowledge.snake = [0: .init(point: .zero, time: 0)]
        let target = SIMD3(Double(here.x) * cell + cell, 0, Double(here.z) * cell)

        let volley = Execution.deliberate(&bots, slots: [0], snake: [target], world: world)
        let shot = try XCTUnwrap(volley.shots.first)
        XCTAssertEqual(volley.shots.count, 1, "one shot a step is the cadence FR-BOT-060 fixes")
        // From the shooter's eyes, which is where it looked and fired from (ADR-0022).
        XCTAssertEqual(shot.from.x, try element(0, of: bots).position.x, accuracy: 1e-12)
        XCTAssertEqual(shot.from.y, try element(0, of: bots).position.y + world.configurations.bot.eyeHeight, accuracy: 1e-12)
        XCTAssertEqual(shot.from.z, try element(0, of: bots).position.z, accuracy: 1e-12)
        XCTAssertEqual(shot.to, target)
        XCTAssertEqual(shot.squad, .red)
        XCTAssertEqual(shot.left, world.configurations.bot.deliberationPeriod)
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
        XCTAssertEqual(volley.shots.count, 1, "the bot saw the snake over the box and did not fire")
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
        let shot = try XCTUnwrap(volley.shots.first)
        XCTAssertEqual(shot.from.y, try element(0, of: bots).position.y + 0.5, accuracy: 1e-12)
    }

    func testShotsLastTheirPeriodAndDoNotPileUp() throws {
        // Driven through a real match rather than asserted about the type: what the
        // requirement promises is that what is on screen at any moment is the shots
        // being fired, and a list that only grew would satisfy "a line is drawn" and
        // none of the rest.
        //
        // The snake is walked at a bot, because a snake standing still is a snake
        // nobody notices and therefore nobody shoots at (FR-BOT-050) — the first
        // version of this test waited thirty seconds in the corner for a shot that
        // had no reason to come.
        let world = try world()
        let period = world.configurations.bot.deliberationPeriod
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
        var aged = false
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
            fired = fired || !game.shots.isEmpty
            aged = aged || game.shots.contains { $0.left < period }
            most = max(most, game.shots.count)
            XCTAssertTrue(game.shots.allSatisfy { $0.left > 0 && $0.left <= period },
                          "a line outlived its shot or stayed on after it")
        }
        XCTAssertTrue(fired, "nobody fired in thirty seconds of walking into two squads")
        XCTAssertTrue(aged, "no line ever grew older, so nothing is counting them down")
        // One line a bot a step, and a step's worth can overlap the next by the frame
        // the two share, so two a bot is the bound. What it refuses is accumulation:
        // thirty seconds of never clearing the list would be a thousand.
        XCTAssertLessThanOrEqual(most, game.bots.count * 2,
                                 "lines are piling up rather than expiring")
    }

    @MainActor
    func testTheLineRunsFromTheShooterToWhatWasAimedAt() throws {
        let from = SIMD3(1.0, 1.25, 2.0)
        let to = SIMD3(4.0, 1.25, 6.0)       // three by four: a line five metres long
        let entity = ShotEntity.make(for: [try bot(at: NavigationGraph.Node(floor: 0, x: 0, z: 0),
                                                   in: try world())])
        ShotEntity.update(entity, from: [Shot(from: from, to: to, squad: .red, left: 0.2)])

        let drawn = entity.children.filter(\.isEnabled)
        XCTAssertEqual(drawn.count, 1)
        let bar = try XCTUnwrap(drawn.first)

        // The bar is a metre deep and scaled along +z, so its two ends are half its
        // length either way along its own z, turned and moved into the scene.
        let half = SIMD3<Float>(0, 0, bar.scale.z / 2)
        let head = bar.position + bar.orientation.act(half)
        let tail = bar.position - bar.orientation.act(half)
        // Drawn between the two ends exactly as the model has them, adding nothing.
        let start = SIMD3<Float>(from)
        let end = SIMD3<Float>(to)
        let ends = simd_distance(head, end) + simd_distance(tail, start)
        let swapped = simd_distance(head, start) + simd_distance(tail, end)
        XCTAssertEqual(min(ends, swapped), 0, accuracy: 1e-3,
                       "the line does not join the two points it is supposed to join")
        XCTAssertEqual(Double(bar.scale.z), 5, accuracy: 1e-3)
    }

    @MainActor
    func testALineIsTakenOffScreenWhenItsShotIsOver() throws {
        let entity = ShotEntity.make(for: [try bot(at: NavigationGraph.Node(floor: 0, x: 0, z: 0),
                                                   in: try world())])
        ShotEntity.update(entity, from: [Shot(from: SIMD3(0, 0, 0), to: SIMD3(2, 0, 0),
                                              squad: .red, left: 0.2)])
        XCTAssertEqual(entity.children.filter(\.isEnabled).count, 1)

        ShotEntity.update(entity, from: [])
        XCTAssertEqual(entity.children.filter(\.isEnabled).count, 0,
                       "a line stayed on screen after its shot was over")
    }

    @MainActor
    func testEachSquadsShotIsDrawnInItsOwnColour() throws {
        let world = try world()
        let two = [try bot(at: element(0, of: cells(in: world)), in: world),
                   try XCTUnwrap(Bot(id: 1, squad: .blue, archetype: .assault,
                                     at: SIMD3(2, 0, 2), floor: 0,
                                     configuration: world.configurations.bot))]
        let entity = ShotEntity.make(for: two)
        ShotEntity.update(entity, from: [Shot(from: SIMD3(0, 0, 0), to: SIMD3(2, 0, 0), squad: .red, left: 0.2),
                                         Shot(from: SIMD3(0, 0, 1), to: SIMD3(2, 0, 1), squad: .blue, left: 0.2)])

        let drawn = entity.children.filter(\.isEnabled)
        XCTAssertEqual(drawn.count, 2)
        // FR-VIEW-060 asks the three channels to agree, so a red shot is drawn with
        // the colour a red body is drawn with.
        XCTAssertEqual(drawn.filter { $0.name.hasSuffix("r") }.count, 1)
        XCTAssertEqual(drawn.filter { $0.name.hasSuffix("b") }.count, 1)
    }
}
