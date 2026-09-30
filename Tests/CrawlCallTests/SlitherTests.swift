// The snake slithers (FR-VIEW-330): its drawn body sways to either side of the path by
// the configured amplitude, the wave laid on the ground so that a point of the path
// sways the same way whenever the body passes over it, the head swaying with it — and
// only the drawing: the snake the match knows stays on its path.
//
// verifies: FR-VIEW-330
import RealityKit
import simd
import XCTest
@testable import CrawlCall

final class SlitherTests: XCTestCase {
    private var shipped: World!
    private let frame = 1.0 / 60

    override func setUpWithError() throws {
        try super.setUpWithError()
        shipped = try Launch.world().get()
    }

    private var slither: ViewConfiguration.Slither { shipped.configurations.view.slither }
    private var radius: Double { shipped.configurations.tuning.bodyRadius }

    private func sway(_ snake: Snake) -> SnakeBody.Sway {
        SnakeBody.Sway(amplitude: slither.amplitude, wavelength: slither.wavelength, crawled: snake.crawled)
    }

    /// A snake crawled straight along +x over open ground, from x = 1.
    private func crawled(_ seconds: Double) throws -> Snake {
        let rows = Array(repeating: String(repeating: ".", count: 60), count: 5)
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        let tuning = shipped.configurations.tuning
        let floor = Surfaces(graph: NavigationGraph.derive(from: map, stepHeight: tuning.stepHeight),
                             kit: shipped.kit, tuning: tuning, map: map)
        var snake = Snake(head: SIMD3(1, 0, 1), floor: 0, segments: 6, segmentSpacing: radius * 2)
        for _ in 0..<Int((seconds / frame).rounded()) {
            snake.advance(direction: SIMD2(1, 0), speed: shipped.configurations.snake.baseSpeed, seconds: frame, over: floor)
        }
        return snake
    }

    func testTheConfigurationSwaysALittle() {
        XCTAssertGreaterThan(slither.amplitude, 0)
        XCTAssertLessThan(slither.amplitude, radius, "a sway wider than the body is not a little")
        XCTAssertGreaterThan(slither.wavelength, 0)
    }

    func testTheShippedSwayIsTheMaintainers() {
        // 5 cm on a 1.2 m wave at first; on 2026-09-30 the sway narrowed and its wave
        // stretched, each by 30 %.
        XCTAssertEqual(slither.amplitude, 0.035, accuracy: 1e-9)
        XCTAssertEqual(slither.wavelength, 1.56, accuracy: 1e-9)
    }

    func testTheBodySwaysToEitherSideByTheAmplitudeAndNoMore() throws {
        let snake = try crawled(2)
        let line = SnakeBody.centreLine(head: snake.head, tail: snake.tail, sway: sway(snake))
        let aside = line.points.map { $0.z - snake.head.z }
        XCTAssertLessThanOrEqual(aside.map(abs).max() ?? .infinity, slither.amplitude + 1e-9)
        XCTAssertGreaterThan(aside.max() ?? 0, slither.amplitude * 0.9, "the body never swayed out to one side")
        XCTAssertLessThan(aside.min() ?? 0, -slither.amplitude * 0.9, "the body never swayed out to the other")
        // And straight without a sway: the drawing's doing, not the path's.
        let straight = SnakeBody.centreLine(head: snake.head, tail: snake.tail)
        XCTAssertEqual(straight.points.map { abs($0.z - snake.head.z) }.max() ?? .infinity, 0, accuracy: 1e-9)
    }

    func testAPointOfThePathSwaysTheSameWayWhenTheBodyHasMovedOnOverIt() throws {
        // Two moments of one crawl: wherever both bodies lie over the same ground, they
        // are shifted the same way there.
        let early = try crawled(2)
        // Half a wave on: a sway that went with the body would be the other way round here.
        let later = try crawled(2.2)
        let a = SnakeBody.centreLine(head: early.head, tail: early.tail, sway: sway(early))
        let b = SnakeBody.centreLine(head: later.head, tail: later.tail, sway: sway(later))
        // Read between two rings of the later body in a straight line, a wave is off by
        // at most the amplitude times 1 − cos(π·gap/wavelength), the gap being a ring's.
        let gap = radius * 2 / Double(SnakeShape.ringsBetweenPoints)
        let reading = slither.amplitude * (1 - cos(.pi * gap / slither.wavelength)) + 1e-6
        var compared = 0
        for point in a.points {
            // The point of the later body over the same ground, between two of its own.
            guard let after = b.points.indices.dropFirst().first(where: { b.points[$0].x <= point.x }) else { continue }
            let (p, q) = (b.points[after - 1], b.points[after])
            guard p.x - q.x > 1e-9, p.x >= point.x else { continue }
            let t = (p.x - point.x) / (p.x - q.x)
            let there = p.z + (q.z - p.z) * t
            XCTAssertEqual(there, point.z, accuracy: reading, "the sway moved with the body at x \(point.x)")
            compared += 1
        }
        XCTAssertGreaterThan(compared, 5, "the two bodies hardly lay over the same ground")
    }

    @MainActor
    func testTheHeadSwaysWithTheBodyAndPointsAlongIt() throws {
        let snake = try crawled(2)
        let still = SnakeEntity.make(radius: radius, segments: snake.tail.count)
        SnakeEntity.update(still, from: snake, radius: radius)
        let moving = SnakeEntity.make(radius: radius, segments: snake.tail.count)
        let wave = sway(snake)
        SnakeEntity.update(moving, from: snake, radius: radius, sway: wave)
        let a = try XCTUnwrap(still.children.first { $0.name == EntityName.head })
        let b = try XCTUnwrap(moving.children.first { $0.name == EntityName.head })
        let line = SnakeBody.centreLine(head: snake.head, tail: snake.tail, sway: wave)
        let first = try XCTUnwrap(line.points.first)
        XCTAssertEqual(Double(b.position.z - a.position.z), first.z - snake.head.z, accuracy: 1e-4,
                       "the head did not go aside with the body's end")
        XCTAssertEqual(Double(b.position.x - a.position.x), 0, accuracy: 1e-4)
        // It points the way the body's end runs, not along the path.
        let facing = b.orientation.act(SIMD3<Float>(0, 0, 1))
        let along = try XCTUnwrap(line.points.first) - (try XCTUnwrap(line.points.dropFirst().first))
        XCTAssertEqual(Double(atan2(facing.z, facing.x)), atan2(along.z, along.x), accuracy: 0.05)
    }

    @MainActor
    func testASnakeThatHasNotMovedYetDoesNotTurnItsHeadFrameAfterFrame() throws {
        // Found on the phone: at the whistle, with no tail behind the head to say which
        // way it faces, the head spun where it stood, turned by the sway once a frame.
        let snake = Snake(head: SIMD3(1, 0, 1), floor: 0, segments: 6, segmentSpacing: radius * 2)
        let entity = SnakeEntity.make(radius: radius, segments: snake.tail.count)
        let wave = sway(snake)
        XCTAssertNotEqual(wave.slopeAtHead, 0, "a sway with no slope at the head proves nothing here")
        SnakeEntity.update(entity, from: snake, radius: radius, sway: wave)
        let head = try XCTUnwrap(entity.children.first { $0.name == EntityName.head })
        let first = head.orientation
        for _ in 0..<30 { SnakeEntity.update(entity, from: snake, radius: radius, sway: wave) }
        XCTAssertEqual(Double(abs(simd_dot(head.orientation.vector, first.vector))), 1, accuracy: 1e-5,
                       "the head turned while the snake stood still")
    }

    func testTheSwayCostsNoTriangles() throws {
        let snake = try crawled(2)
        let plain = SnakeBody.tube(head: snake.head, tail: snake.tail, radius: radius)
        let swaying = SnakeBody.tube(head: snake.head, tail: snake.tail, radius: radius, sway: sway(snake))
        XCTAssertEqual(swaying.triangles, plain.triangles)
    }
}
