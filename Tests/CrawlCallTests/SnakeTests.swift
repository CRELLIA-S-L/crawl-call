// The head's movement and the tail that follows it. Geometry is compared within a
// tolerance, never for equality (`specs/50-verification.md`).
//
// verifies: FR-SNAKE-010, FR-SNAKE-020, FR-SNAKE-030, FR-SNAKE-220, FR-MAP-025
import XCTest
@testable import CrawlCall

final class SnakeTests: XCTestCase {
    private lazy var kit: Kit = { try! Kit.load(named: "blockout", from: .main) }()
    private lazy var tuning: TuningConfiguration = { try! Configurations.load(from: .main).tuning }()

    /// A small room with a wall on its right and an upper floor joined by one cell.
    private func surfaces(_ text: String) throws -> Surfaces {
        let map = try MapParser.parse(text, kit: kit)
        return Surfaces(graph: NavigationGraph.derive(from: map), kit: kit, tuning: tuning)
    }

    private func snake(at x: Double, _ z: Double, floor: Int = 0, segments: Int = 4) -> Snake {
        Snake(head: SIMD3(x, Double(floor) * kit.floorHeight, z), floor: floor,
              segments: segments, segmentSpacing: tuning.bodyRadius * 2)
    }

    // MARK: the head

    func testTheHeadMovesTheWayThePlayerHolds() throws {
        let s = try surfaces("kit blockout\nfloor 0\n....\n....\n")
        var snake = self.snake(at: 0, 0)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.1, over: s)
        XCTAssertEqual(snake.head.x, 0.3, accuracy: 1e-9)
        XCTAssertEqual(snake.head.z, 0, accuracy: 1e-9)
    }

    func testItAdvancesAtTheSpeedItIsGivenForTheTimeItIsGiven() throws {
        // FR-SNAKE-030: the distance is speed × time and nothing else.
        let s = try surfaces("kit blockout\nfloor 0\n......\n")
        var snake = self.snake(at: 0, 0)
        snake.advance(direction: SIMD2(1, 0), speed: 2, seconds: 0.25, over: s)
        XCTAssertEqual(snake.head.x, 0.5, accuracy: 1e-9)
        snake.advance(direction: SIMD2(1, 0), speed: 4, seconds: 0.25, over: s)
        XCTAssertEqual(snake.head.x, 1.5, accuracy: 1e-9)
    }

    func testADiagonalHoldIsNotFasterThanAStraightOne() throws {
        let s = try surfaces("kit blockout\nfloor 0\n....\n....\n")
        var straight = snake(at: 0, 0)
        var diagonal = snake(at: 0, 0)
        straight.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.1, over: s)
        diagonal.advance(direction: SIMD2(1, 1), speed: 3, seconds: 0.1, over: s)
        let a = straight.head - SIMD3(0, 0, 0)
        let b = diagonal.head - SIMD3(0, 0, 0)
        XCTAssertEqual((a.x * a.x + a.z * a.z).squareRoot(),
                       (b.x * b.x + b.z * b.z).squareRoot(), accuracy: 1e-9)
    }

    func testAWallStopsTheHeadWhereItIs() throws {
        // FR-SNAKE-010: never through walls.
        let s = try surfaces("kit blockout\nfloor 0\n.#\n")
        var snake = self.snake(at: 0, 0)
        snake.advance(direction: SIMD2(1, 0), speed: 10, seconds: 1, over: s)
        XCTAssertEqual(snake.head.x, 0, accuracy: 1e-9)
    }

    func testALongFrameDoesNotCarryTheHeadThroughAWall() throws {
        // A corridor with a wall in the middle and floor beyond it. One frame of half
        // a second at three metres a second is 1.5 m — past the wall, if the step is
        // taken whole.
        let s = try surfaces("kit blockout\nfloor 0\n..#..\n")
        var snake = self.snake(at: 0, 0)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.5, over: s)
        XCTAssertLessThan(snake.head.x, 1.0, "the head passed through the wall at x = 1.0")
    }

    func testNoDirectionMeansNoMovement() throws {
        let s = try surfaces("kit blockout\nfloor 0\n....\n")
        var snake = self.snake(at: 0, 0)
        snake.advance(direction: SIMD2(0, 0), speed: 3, seconds: 0.1, over: s)
        XCTAssertEqual(snake.head.x, 0, accuracy: 1e-12)
        XCTAssertEqual(snake.trail.count, 1)
    }

    // MARK: the drop

    func testSteeringOffALedgeLandsOnTheFloorBelow() throws {
        // FR-SNAKE-220: a drop is a path. The upper floor ends at x = 0; below it the
        // ground floor continues.
        let s = try surfaces("kit blockout\nfloor 0\n..\nfloor 1\n. \n")
        var snake = self.snake(at: 0, 0, floor: 1)
        XCTAssertEqual(snake.head.y, kit.floorHeight, accuracy: 1e-9)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.2, over: s)
        XCTAssertEqual(snake.floor, 0)
        XCTAssertEqual(snake.head.y, 0, accuracy: 1e-9)
        XCTAssertEqual(snake.head.x, 0.6, accuracy: 1e-9)
    }

    func testTheDropIsInTheTrailAsAVerticalPortion() throws {
        let s = try surfaces("kit blockout\nfloor 0\n..\nfloor 1\n. \n")
        var snake = self.snake(at: 0, 0, floor: 1)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.2, over: s)

        // Somewhere in the trail two points share a place on the map and differ in
        // height: that pair is the drop, and it is what the tail lies down. Where it
        // sits in the trail depends on how the frame was cut into steps, which is not
        // what the requirement is about.
        let vertical = zip(snake.trail, snake.trail.dropFirst()).first { a, b in
            abs(a.x - b.x) < 1e-12 && abs(a.z - b.z) < 1e-12 && abs(a.y - b.y) > 1e-9
        }
        let pair = try XCTUnwrap(vertical, "no vertical portion in the trail")
        XCTAssertEqual(abs(pair.0.y - pair.1.y), kit.floorHeight, accuracy: 1e-9)
        XCTAssertEqual(snake.head.y, 0, accuracy: 1e-9)
        XCTAssertEqual(snake.floor, 0)
    }

    func testADropWithNothingToLandOnIsAWall() throws {
        // Nothing below the edge: the head stays rather than falling out of the world.
        let s = try surfaces("kit blockout\nfloor 1\n. \n")
        var snake = self.snake(at: 0, 0, floor: 1)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.2, over: s)
        XCTAssertEqual(snake.floor, 1)
        XCTAssertEqual(snake.head.x, 0, accuracy: 1e-9)
    }

    // MARK: the tail

    func testTheTailLiesAlongThePathTheHeadTravelled() throws {
        // FR-SNAKE-020: each segment one spacing behind the last, back along the trail.
        let s = try surfaces("kit blockout\nfloor 0\n........\n")
        var snake = self.snake(at: 0, 0, segments: 3)
        for _ in 0..<20 { snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.05, over: s) }
        let tail = snake.tail
        XCTAssertEqual(tail.count, 3)
        for (index, segment) in tail.enumerated() {
            let expected = snake.head.x - Double(index + 1) * snake.segmentSpacing
            XCTAssertEqual(segment.x, expected, accuracy: 1e-6)
            XCTAssertEqual(segment.z, 0, accuracy: 1e-9)
        }
    }

    func testTheTailTurnsTheCornerRatherThanCuttingIt() throws {
        let s = try surfaces("kit blockout\nfloor 0\n....\n....\n....\n")
        var snake = self.snake(at: 0, 0, segments: 2)
        for _ in 0..<12 { snake.advance(direction: SIMD2(0, 1), speed: 3, seconds: 0.05, over: s) }
        for _ in 0..<12 { snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.05, over: s) }
        // The head went along z and then along x; a segment far enough back is still
        // on the first leg, which a straight line from the head could not be.
        let tail = snake.tail
        XCTAssertEqual(tail.count, 2)
        XCTAssertTrue(tail.contains { $0.x < snake.head.x - 1e-6 })
    }

    func testTheSegmentsSitWhereWalkingBackAlongThePathPutsThem() throws {
        // Worked out away from the code: one metre north, then one metre east, with
        // segments 0.6 apart. Walking back from the head, the first lands 0.6 into the
        // east leg; the second uses up that leg's metre and spends the remaining 0.2
        // on the north one.
        let s = try surfaces("kit blockout\nfloor 0\n.....\n.....\n.....\n.....\n")
        var snake = self.snake(at: 0, 0, segments: 2)
        for _ in 0..<4 { snake.advance(direction: SIMD2(0, 1), speed: 3, seconds: 1.0 / 12, over: s) }
        for _ in 0..<4 { snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 1.0 / 12, over: s) }
        XCTAssertEqual(snake.head.x, 1.0, accuracy: 1e-9)
        XCTAssertEqual(snake.head.z, 1.0, accuracy: 1e-9)

        let tail = snake.tail
        XCTAssertEqual(tail.count, 2)
        XCTAssertEqual(tail[0].x, 0.4, accuracy: 1e-6)
        XCTAssertEqual(tail[0].z, 1.0, accuracy: 1e-6)
        XCTAssertEqual(tail[1].x, 0.0, accuracy: 1e-6)
        XCTAssertEqual(tail[1].z, 0.8, accuracy: 1e-6)
    }

    func testAShortTrailGivesAsManySegmentsAsItCanCarry() throws {
        let s = try surfaces("kit blockout\nfloor 0\n....\n")
        var snake = self.snake(at: 0, 0, segments: 5)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.05, over: s)
        XCTAssertLessThan(snake.tail.count, 5)
    }

    func testTheTailFollowsTheHeadDownADrop() throws {
        let s = try surfaces("kit blockout\nfloor 0\n....\nfloor 1\n..  \n")
        var snake = self.snake(at: 0, 0, floor: 1, segments: 3)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.1, over: s)   // along the upper floor
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.3, over: s)   // off the edge
        XCTAssertEqual(snake.floor, 0)
        let tail = snake.tail
        XCTAssertFalse(tail.isEmpty)
        // Somewhere behind the head the tail is still up on the floor it came from.
        XCTAssertTrue(tail.contains { $0.y > 0.1 }, "the tail did not follow the head down")
    }

    // MARK: the numbers come from the configuration

    func testTheSurfacesReadTheirNumbersFromTheTuningConfiguration() throws {
        // FR-MAP-025: one set of values for the snake and for the graph.
        let s = try surfaces("kit blockout\nfloor 0\n..\n")
        XCTAssertEqual(s.cellSize, tuning.navigationGraphCellSize)
        XCTAssertEqual(s.bodyRadius, tuning.bodyRadius)
        XCTAssertEqual(s.stepHeight, tuning.stepHeight)
        XCTAssertEqual(s.slopeAngle, tuning.slopeAngle)
        XCTAssertEqual(s.maximumDropHeight, tuning.maximumDropHeight)
        XCTAssertEqual(s.floorHeight, kit.floorHeight)
    }
}
