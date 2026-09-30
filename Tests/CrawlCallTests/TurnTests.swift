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

    func testATurnGivenItsWayRoundGoesThatWayEvenTheLongerWay() {
        let east = SIMD2(1.0, 0), north = SIMD2(0.0, 1)
        let shorter = Snake.clockwise(east, towards: north)
        let longer = Snake.turn(east, towards: north, by: 0.1, clockwise: !shorter)
        XCTAssertEqual(angle(longer, east), 0.1, accuracy: 1e-12)
        XCTAssertLessThan((longer * north).sum(), 0, "the longer way round turned towards the held direction")
        XCTAssertEqual(Snake.turn(east, towards: north, by: 2, clockwise: !shorter).y, -sin(2), accuracy: 1e-12,
                       "a turn the longer way round was cut short at the shorter's length")
        XCTAssertEqual(Snake.turn(east, towards: north, by: 2, clockwise: shorter), north)
    }

    /// Walls or no ground east of x = 5, open ground west of it, twenty-four metres long.
    private func besideAnEdge(_ row: String) throws -> Surfaces {
        let rows = Array(repeating: row, count: 48)
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        let tuning = shipped.configurations.tuning
        return Surfaces(graph: NavigationGraph.derive(from: map, stepHeight: tuning.stepHeight),
                        kit: shipped.kit, tuning: tuning, map: map)
    }

    func testTurnedBackAlongAWallTheSnakeGoesRoundAwayFromItNotBackOverItsNeck() throws {
        // Found on the phone on 2026-09-30: going along a wall, touching it, and steered
        // back, the snake broke — the shorter way round led into the wall, the wall stopped
        // the turn, and the slide sent the head straight back along the wall over its neck.
        let snake = shipped.configurations.snake
        for (edge, row) in [("wall", "..........#"), ("edge of the ground", "..........     ")] {
            let floor = try besideAnEdge(row)
            for back in [SIMD2(0.0, 1), SIMD2(0.3, 1), SIMD2(1, 0.5)] {
                var body = Snake(head: SIMD3(4.6, 0, 20), floor: 0, segments: 10, segmentSpacing: 0.6)
                func crawl(_ direction: SIMD2<Double>, frames: Int, each: (Snake, Snake) throws -> Void = { _, _ in }) rethrows {
                    for _ in 0..<frames {
                        let before = body
                        body.advance(direction: direction / simd_length(direction), speed: speed, seconds: frame, over: floor,
                                     turningRadius: radius, neck: snake.neckSegments, feel: snake.feelDistance)
                        try each(before, body)
                    }
                }
                // North along it, the stick leaning into it.
                try crawl(SIMD2(0, -1), frames: 60)
                try crawl(SIMD2(0.3, -1), frames: 60)
                let start = body.head
                let which = "\(edge), held \(back)"
                let held = back / simd_length(back)
                try crawl(back, frames: 90) { before, after in
                    // While the turn is still back — once round, the head meets the wall
                    // again as it would anywhere, and slides along it (FR-SNAKE-015).
                    let heading = try XCTUnwrap(before.heading)
                    guard simd_dot(heading, held) < 0 else { return }
                    let moved = simd_distance(SIMD2(before.head.x, before.head.z), SIMD2(after.head.x, after.head.z))
                    XCTAssertLessThanOrEqual(angle(heading, try XCTUnwrap(after.heading)), moved / radius + 1e-6,
                                             "turned tighter than the radius: \(which)")
                    XCTAssertEqual(after.lift, 0, accuracy: 1e-9, "went back over its own neck: \(which)")
                    XCTAssertLessThanOrEqual(after.head.x, start.x + 0.02, "went round into the \(edge): \(which)")
                }
                XCTAssertGreaterThan(body.head.z, start.z + 1, "never came round the way held: \(which)")
                XCTAssertNil(body.drop, "went off the edge: \(which)")
            }
        }
    }

    func testATurnBackBrokenOffByALungeIsNotTakenOnTheOldWayRound() throws {
        // The other way round is kept while the turn back lasts; a lunge ends it, and the
        // next turn back goes the shorter way where that is open.
        let floor = try besideAnEdge("..........#")
        var body = Snake(head: SIMD3(4.6, 0, 20), floor: 0, segments: 10, segmentSpacing: 0.6)
        func crawl(_ direction: SIMD2<Double>, frames: Int, turning: Double?) {
            for _ in 0..<frames {
                body.advance(direction: direction / simd_length(direction), speed: speed, seconds: frame, over: floor,
                             turningRadius: turning)
            }
        }
        crawl(SIMD2(0, -1), frames: 60, turning: radius)
        crawl(SIMD2(0.3, -1), frames: 60, turning: radius)
        // Back along the wall: round the other way, away from it.
        crawl(SIMD2(0, 1), frames: 3, turning: radius)
        // A lunge west, away from the wall.
        crawl(SIMD2(-1, -0.2), frames: 10, turning: nil)
        let before = try XCTUnwrap(body.heading)
        let held = SIMD2(0.5, -1.0) / simd_length(SIMD2(0.5, -1.0))
        XCTAssertLessThan(simd_dot(before, held), 0, "the stick is not behind the head, so this proves nothing")
        crawl(held, frames: 1, turning: radius)
        let after = try XCTUnwrap(body.heading)
        XCTAssertLessThan(angle(after, held), angle(before, held), "turned the longer way round, as the broken-off turn had")
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
