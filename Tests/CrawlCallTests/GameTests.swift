// The logic's edge: intents in, a snake moving, and nothing about touches anywhere
// near it (FR-VIEW-030).
//
// verifies: FR-VIEW-030, FR-SNAKE-030
import XCTest
@testable import CrawlCall

final class GameTests: XCTestCase {
    private func game() throws -> Game {
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        return Game(world: world, start: start)
    }

    func testAMatchStartsOnAWalkableCellOfTheLowestFloor() throws {
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        XCTAssertEqual(start.floor, 0)
        XCTAssertTrue(world.graph.isWalkable(start))
    }

    func testTheSnakeStartsWithTheSegmentsTheConfigurationSets() throws {
        let g = try game()
        XCTAssertEqual(g.snake.segments, g.world.configurations.snake.startingSegmentCount)
        XCTAssertEqual(g.snake.segmentSpacing,
                       g.world.configurations.tuning.bodyRadius * 2, accuracy: 1e-12)
    }

    func testNothingMovesUntilAnIntentSaysSo() throws {
        var g = try game()
        let before = g.snake.head
        g.advance(seconds: 0.1)
        XCTAssertEqual(g.snake.head.x, before.x, accuracy: 1e-12)
        XCTAssertEqual(g.snake.head.z, before.z, accuracy: 1e-12)
    }

    func testAMoveIntentIsHeldUntilAnotherReplacesIt() throws {
        var g = try game()
        let start = g.snake.head
        g.apply(.move(direction: SIMD2(1, 0)))
        g.advance(seconds: 0.1)
        g.advance(seconds: 0.1)
        // Held: two frames of movement from one intent.
        let speed = g.world.configurations.snake.baseSpeed
        XCTAssertEqual(g.snake.head.x - start.x, speed * 0.2, accuracy: 1e-9)

        g.apply(.move(direction: SIMD2(0, 0)))
        let stopped = g.snake.head
        g.advance(seconds: 0.1)
        XCTAssertEqual(g.snake.head.x, stopped.x, accuracy: 1e-12)
    }

    func testPauseStopsTheWorldAndReleasingItResumes() throws {
        var g = try game()
        g.apply(.move(direction: SIMD2(1, 0)))
        g.apply(.pause)
        let paused = g.snake.head
        g.advance(seconds: 0.5)
        XCTAssertEqual(g.snake.head.x, paused.x, accuracy: 1e-12)
        g.apply(.pause)
        g.advance(seconds: 0.1)
        XCTAssertGreaterThan(g.snake.head.x, paused.x)
    }

    func testTheSpeedIsTheConfigurationsAndNotAConstant() throws {
        var g = try game()
        let start = g.snake.head
        g.apply(.move(direction: SIMD2(1, 0)))
        g.advance(seconds: 1.0 / 60)
        let moved = g.snake.head.x - start.x
        XCTAssertEqual(moved, g.world.configurations.snake.baseSpeed / 60, accuracy: 1e-9)
    }

    func testIntentsTheMatchDoesNotUseYetAreAcceptedWithoutEffect() throws {
        // IF-VIEW-010 delivers four; the match consumes two of them today, and saying
        // so beats a crash or a silent drop.
        var g = try game()
        g.apply(.move(direction: SIMD2(1, 0)))
        let before = g.snake.head
        g.apply(.useAbility(segment: 0))
        g.apply(.point(at: SIMD2(5, 5)))
        g.advance(seconds: 0.1)
        XCTAssertGreaterThan(g.snake.head.x, before.x)   // still moving, nothing broke
        XCTAssertFalse(g.isPaused)
    }
}

/// The snake on screen: one body per segment, where the model says they are, however
/// many the snake has eaten its way to (FR-VIEW-180).
///
/// verifies: FR-SNAKE-010, FR-SNAKE-020, FR-VIEW-180
@MainActor
final class SnakeEntityTests: XCTestCase {
    func testThereIsAHeadAndOneBodyPerSegment() throws {
        let entity = SnakeEntity.make(radius: 0.3, segments: 4)
        XCTAssertEqual(entity.children.filter { $0.name == "head" }.count, 1)
        XCTAssertEqual(entity.children.filter { $0.name.hasPrefix("segment") }.count, 4)
    }

    func testEachBodyGoesWhereTheModelSaysAndTheRestAreHidden() throws {
        let world = try Launch.world().get()
        var game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        let entity = SnakeEntity.make(radius: world.configurations.tuning.bodyRadius,
                                      segments: game.snake.segments)

        // Nothing has moved yet, so the trail carries no segments: they hide.
        SnakeEntity.update(entity, from: game.snake, radius: world.configurations.tuning.bodyRadius)
        XCTAssertTrue(entity.children.filter { $0.name.hasPrefix("segment") }.allSatisfy { !$0.isEnabled })

        game.apply(.move(direction: SIMD2(1, 0)))
        for _ in 0..<60 { game.advance(seconds: 1.0 / 60) }
        SnakeEntity.update(entity, from: game.snake, radius: world.configurations.tuning.bodyRadius)

        let head = try XCTUnwrap(entity.children.first { $0.name == "head" })
        XCTAssertEqual(Double(head.position.x), game.snake.head.x, accuracy: 1e-5)
        let tail = game.snake.tail
        XCTAssertFalse(tail.isEmpty)
        for (index, place) in tail.enumerated() {
            let body = try XCTUnwrap(entity.children.first { $0.name == "segment\(index)" })
            XCTAssertTrue(body.isEnabled)
            XCTAssertEqual(Double(body.position.x), place.x, accuracy: 1e-5)
            XCTAssertEqual(Double(body.position.z), place.z, accuracy: 1e-5)
        }
    }

    func testASnakeThatHasEatenIsDrawnLongerThanItStarted() throws {
        // The defect this refuses: the bodies were made once, at the length the match
        // begins with, so a snake that ate past that length grew in the model and
        // stood still on screen (FR-SNAKE-060 true and invisible).
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        let cell = world.configurations.tuning.navigationGraphCellSize
        let surfaces = Surfaces(graph: world.graph, kit: world.kit,
                                tuning: world.configurations.tuning, map: world.map)
        let starting = world.configurations.snake.startingSegmentCount
        var snake = Snake(head: SIMD3(Double(start.x) * cell,
                                      Double(start.floor) * world.kit.floorHeight,
                                      Double(start.z) * cell),
                          floor: start.floor,
                          segments: starting,
                          segmentSpacing: world.configurations.tuning.bodyRadius * 2)
        let entity = SnakeEntity.make(radius: world.configurations.tuning.bodyRadius,
                                      segments: snake.segments)

        // Eat a heavy's worth, then walk far enough for the trail to carry it all.
        snake.grow(by: try XCTUnwrap(world.configurations.snake.segmentsPerArchetype["heavy"]))
        for _ in 0..<600 {
            snake.advance(direction: SIMD2(1, 0), speed: world.configurations.snake.baseSpeed,
                          seconds: 1.0 / 60, over: surfaces)
        }
        SnakeEntity.update(entity, from: snake, radius: world.configurations.tuning.bodyRadius)

        let drawn = entity.children.filter { $0.name.hasPrefix("segment") && $0.isEnabled }
        XCTAssertEqual(drawn.count, snake.tail.count)
        XCTAssertGreaterThan(drawn.count, starting,
                             "the snake ate and the screen still shows the length it started with")
        // And every one of them is where the model put it, not parked on the head.
        for (index, place) in snake.tail.enumerated() {
            let body = try XCTUnwrap(entity.children.first { $0.name == "segment\(index)" })
            XCTAssertEqual(Double(body.position.x), place.x, accuracy: 1e-5)
            XCTAssertEqual(Double(body.position.z), place.z, accuracy: 1e-5)
        }
    }

    func testTheBodiesTrailBehindTheHeadRatherThanSittingOnIt() throws {
        // Driven through `Snake` rather than through a match: what is being checked
        // is that the tail lies along the path, and a match now has bots in it that
        // shoot the tail off while the test is walking it.
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        let cell = world.configurations.tuning.navigationGraphCellSize
        let surfaces = Surfaces(graph: world.graph, kit: world.kit,
                                tuning: world.configurations.tuning, map: world.map)
        var snake = Snake(head: SIMD3(Double(start.x) * cell,
                                      Double(start.floor) * world.kit.floorHeight,
                                      Double(start.z) * cell),
                          floor: start.floor,
                          segments: world.configurations.snake.startingSegmentCount,
                          segmentSpacing: world.configurations.tuning.bodyRadius * 2)
        for _ in 0..<120 {
            snake.advance(direction: SIMD2(1, 0), speed: world.configurations.snake.baseSpeed,
                          seconds: 1.0 / 60, over: surfaces)
        }
        let entity = SnakeEntity.make(radius: world.configurations.tuning.bodyRadius,
                                      segments: snake.segments)
        SnakeEntity.update(entity, from: snake, radius: world.configurations.tuning.bodyRadius)
        let head = try XCTUnwrap(entity.children.first { $0.name == "head" })
        let first = try XCTUnwrap(entity.children.first { $0.name == "segment0" })
        XCTAssertLessThan(first.position.x, head.position.x)
        XCTAssertEqual(Double(head.position.x - first.position.x),
                       snake.segmentSpacing, accuracy: 1e-4)
    }
}
