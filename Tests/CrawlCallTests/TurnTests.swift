// The head turns on an arc (FR-SNAKE-290): steered back the way it came, it goes round
// no tighter than the turning radius instead of folding the snake in two, and a lunge
// or a coil, which steer the head themselves, are not held to it.
//
// verifies: FR-SNAKE-290
import simd
import XCTest
@testable import CrawlCall

final class TurnTests: XCTestCase {
    private var shipped: World!
    private let frame = 1.0 / 60

    override func setUpWithError() throws {
        try super.setUpWithError()
        shipped = try Launch.world().get()
    }

    private var radius: Double { shipped.configurations.snake.turningRadius }
    private var speed: Double { shipped.configurations.snake.baseSpeed }

    /// Open ground, forty cells by twenty.
    private func open() throws -> (World, Surfaces) {
        let rows = Array(repeating: String(repeating: ".", count: 40), count: 20)
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        let tuning = shipped.configurations.tuning
        let world = World(configurations: shipped.configurations, kit: shipped.kit, map: map, setting: shipped.setting,
                          graph: NavigationGraph.derive(from: map, stepHeight: tuning.stepHeight),
                          plan: ScenePlan.make(map: map, kit: shipped.kit, cellSize: tuning.navigationGraphCellSize))
        return (world, Surfaces(graph: world.graph, kit: world.kit, tuning: tuning, map: map))
    }

    private func angle(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
        abs(atan2(a.x * b.y - a.y * b.x, a.x * b.x + a.y * b.y))
    }

    func testATurnIsHeldToTheAngleGivenAndAHalfTurnAlwaysGoesOneWay() {
        let east = SIMD2(1.0, 0), north = SIMD2(0.0, 1)
        XCTAssertEqual(angle(Snake.turn(east, towards: north, by: 0.1), east), 0.1, accuracy: 1e-12)
        XCTAssertEqual(Snake.turn(east, towards: north, by: 2), north, "a turn that fits was not taken whole")
        let back = Snake.turn(east, towards: SIMD2(-1, 0), by: 0.1)
        let backOtherZero = Snake.turn(east, towards: SIMD2(-1, -0.0), by: 0.1)
        XCTAssertEqual(back.y, backOtherZero.y, accuracy: 1e-12, "the half turn went a different way for a zero's sign")
    }

    func testSteeredBackTheSnakeGoesRoundNoTighterThanTheTurningRadius() throws {
        let (_, floor) = try open()
        var snake = Snake(head: SIMD3(5, 0, 5), floor: 0, segments: 6, segmentSpacing: 0.6)
        for _ in 0..<60 { snake.advance(direction: SIMD2(1, 0), speed: speed, seconds: frame, over: floor, turningRadius: radius) }
        let start = snake.head
        var widest = 0.0
        var heading = try XCTUnwrap(snake.heading)
        for _ in 0..<120 {
            let before = snake.head
            snake.advance(direction: SIMD2(-1, 0), speed: speed, seconds: frame, over: floor, turningRadius: radius)
            let now = try XCTUnwrap(snake.heading)
            let moved = simd_distance(SIMD2(before.x, before.z), SIMD2(snake.head.x, snake.head.z))
            XCTAssertLessThanOrEqual(angle(heading, now), moved / radius + 1e-6, "turned tighter than the radius")
            heading = now
            widest = max(widest, abs(snake.head.z - start.z))
        }
        XCTAssertEqual(angle(heading, SIMD2(-1, 0)), 0, accuracy: 1e-6, "never came round to the way held")
        // Round a half circle: as far to the side as its diameter, not back through its neck.
        XCTAssertGreaterThan(widest, radius * 2 * 0.9, "folded back on itself")
    }

    func testALungeOrACoilTurnsTheHeadAtOnce() throws {
        let (_, floor) = try open()
        var snake = Snake(head: SIMD3(5, 0, 5), floor: 0, segments: 6, segmentSpacing: 0.6)
        for _ in 0..<60 { snake.advance(direction: SIMD2(1, 0), speed: speed, seconds: frame, over: floor) }
        snake.advance(direction: SIMD2(-1, 0), speed: speed, seconds: frame, over: floor)
        XCTAssertEqual(angle(try XCTUnwrap(snake.heading), SIMD2(-1, 0)), 0, accuracy: 1e-9)
    }

    func testInAMatchTheStickTurnsTheSnakeOnAnArc() throws {
        let (world, _) = try open()
        var game = Game(world: world, start: NavigationGraph.Node(floor: 0, x: 10, z: 10))
        game.apply(.move(direction: SIMD2(1, 0)))
        for _ in 0..<60 { game.advance(seconds: frame) }
        game.apply(.move(direction: SIMD2(-1, 0)))
        var heading = try XCTUnwrap(game.snake.heading)
        for _ in 0..<10 {
            let before = game.snake.head
            game.advance(seconds: frame)
            let now = try XCTUnwrap(game.snake.heading)
            let moved = simd_distance(SIMD2(before.x, before.z), SIMD2(game.snake.head.x, game.snake.head.z))
            XCTAssertLessThanOrEqual(angle(heading, now), moved / radius + 1e-6, "the match let the head fold back")
            heading = now
        }
    }
}
