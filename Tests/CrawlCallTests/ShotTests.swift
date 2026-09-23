// A shot has to be visible (FR-VIEW-170): the model has to say one happened and
// where it went, and the view has to put a line on exactly that.
//
// verifies: FR-VIEW-170
import RealityKit
import XCTest
@testable import CrawlCall

final class ShotTests: XCTestCase {
    private func world() throws -> World { try Launch.world().get() }

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
        let here = cells(in: world)[0]
        let cell = world.configurations.tuning.navigationGraphCellSize
        var bots = [try bot(at: here, in: world)]
        bots[0].knowsSnake = true
        let target = SIMD3(Double(here.x) * cell + cell, 0, Double(here.z) * cell)

        let volley = Execution.deliberate(&bots, slots: [0], snake: [target], world: world)
        let shot = try XCTUnwrap(volley.shots.first)
        XCTAssertEqual(volley.shots.count, 1, "one shot a step is the cadence FR-BOT-060 fixes")
        XCTAssertEqual(shot.from, bots[0].position)
        XCTAssertEqual(shot.to, target)
        XCTAssertEqual(shot.squad, .red)
        XCTAssertEqual(shot.left, world.configurations.bot.deliberationPeriod)
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
        let start = try XCTUnwrap(Game.start(in: world))
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
        let from = SIMD3(1.0, 0, 2.0)
        let to = SIMD3(4.0, 0, 6.0)          // three by four: a line five metres long
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
        let start = SIMD3<Float>(Float(from.x), Float(ShotEntity.height), Float(from.z))
        let end = SIMD3<Float>(Float(to.x), Float(ShotEntity.height), Float(to.z))
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
        let two = [try bot(at: cells(in: world)[0], in: world),
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
