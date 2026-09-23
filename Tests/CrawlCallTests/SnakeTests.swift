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
        return Surfaces(graph: NavigationGraph.derive(from: map), kit: kit, tuning: tuning, map: map)
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

/// The stairs half of FR-SNAKE-010: a map's vertical transition is something the
/// snake can traverse (FR-MAP-010), not only something the bots path along.
///
/// verifies: FR-SNAKE-010, FR-MAP-010
final class SnakeClimbTests: XCTestCase {
    private lazy var kit: Kit = { try! Kit.load(named: "blockout", from: .main) }()
    private lazy var tuning: TuningConfiguration = { try! Launch.world().get().configurations.tuning }()
    private let cell = 0.5

    /// Three cells in a row on the ground floor, the last of them a stair that a
    /// transition links to the same cell one floor up.
    private func stairs() throws -> Surfaces {
        let map = try MapParser.parse("kit blockout\ntransition 2,0 0 1\nfloor 0\n../\nfloor 1\n  /\n", kit: kit)
        return Surfaces(graph: NavigationGraph.derive(from: map), kit: kit, tuning: tuning, map: map)
    }

    private func snake(at x: Int) -> Snake {
        Snake(head: SIMD3(Double(x) * cell, 0, 0), floor: 0, segments: 4, segmentSpacing: cell)
    }

    func testWalkingIntoAStairTakesTheHeadUp() throws {
        let surfaces = try stairs()
        var body = snake(at: 0)
        // Two seconds: one to walk the metre to the stair and one to walk its three
        // metres of height at three metres a second.
        for _ in 0..<120 {
            body.advance(direction: SIMD2(1, 0), speed: 3.0, seconds: 1.0 / 60, over: surfaces)
        }
        XCTAssertEqual(body.floor, 1, "the head is still on the ground floor")
        XCTAssertEqual(body.head.y, kit.floorHeight, accuracy: 1e-9)
    }

    func testTheTrailCarriesBothHeightsSoTheTailClimbsToo() throws {
        let surfaces = try stairs()
        var body = snake(at: 0)
        for _ in 0..<120 {
            body.advance(direction: SIMD2(1, 0), speed: 3.0, seconds: 1.0 / 60, over: surfaces)
        }
        // What the path is for is the tail, so that is what is asked: with the head
        // at the top, the segments behind it stand at the heights it came up
        // through, not on the floor below or on the balcony with it.
        XCTAssertEqual(body.head.y, kit.floorHeight, accuracy: 1e-9)
        let tail = body.tail
        XCTAssertEqual(tail.count, 4)
        XCTAssertTrue(tail.allSatisfy { $0.y > 1e-9 && $0.y <= kit.floorHeight + 1e-9 },
                      "the tail hangs below the stair: \(tail.map(\.y))")
        XCTAssertTrue(tail.contains { $0.y < kit.floorHeight - 1e-9 },
                      "the whole tail is already at the top: \(tail.map(\.y))")
    }

    func testAHeadAlreadyInAStairsCellIsNotCarriedUpByStandingInIt() throws {
        // Entering the cell is what climbs. A head that is already in it — because it
        // dropped in, or because it is crossing it — moves inside it without being
        // taken up, or a snake that came down the stair would bounce straight back.
        let surfaces = try stairs()
        var body = Snake(head: SIMD3(2 * cell, 0, 0), floor: 0, segments: 4, segmentSpacing: cell)
        body.advance(direction: SIMD2(-1, 0), speed: 3.0, seconds: 1.0 / 60, over: surfaces)
        XCTAssertEqual(body.floor, 0, "the head was carried up while moving inside the cell")
        XCTAssertLessThan(body.head.x, 2 * cell, "the head did not move at all")

        // Walking on out of the cell leaves it on the ground floor, and walking back
        // in is an entry, which is the case that does climb.
        for _ in 0..<20 {
            body.advance(direction: SIMD2(-1, 0), speed: 3.0, seconds: 1.0 / 60, over: surfaces)
        }
        XCTAssertEqual(body.floor, 0)
        for _ in 0..<40 {
            body.advance(direction: SIMD2(1, 0), speed: 3.0, seconds: 1.0 / 60, over: surfaces)
        }
        XCTAssertEqual(body.floor, 1, "walking back onto the stair did not take the head up")
    }

    func testTheShippedBlockoutsBalconyCanBeReachedFromTheStart() throws {
        // The map declares one transition and FR-MAP-010 asks that it be one the
        // snake can traverse. Steered from where a match begins: along the top row to
        // the stair's column, then down it to the stair.
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.start(in: world))
        let size = world.configurations.tuning.navigationGraphCellSize
        let surfaces = Surfaces(graph: world.graph, kit: world.kit, tuning: world.configurations.tuning, map: world.map)
        var body = Snake(head: SIMD3(Double(start.x) * size, 0, Double(start.z) * size),
                         floor: start.floor,
                         segments: world.configurations.snake.startingSegmentCount,
                         segmentSpacing: world.configurations.tuning.bodyRadius * 2)
        let stair = try XCTUnwrap(world.map.transitions.first)

        func steer(_ direction: SIMD2<Double>, until reached: (Snake) -> Bool) {
            for _ in 0..<2000 where !reached(body) {
                body.advance(direction: direction, speed: world.configurations.snake.baseSpeed,
                             seconds: 1.0 / 60, over: surfaces)
            }
        }
        steer(SIMD2(1, 0)) { Int(($0.head.x / size).rounded()) >= stair.x }
        steer(SIMD2(0, 1)) { $0.floor != start.floor }
        // And then up it, which takes the height's worth of walking.
        steer(SIMD2(0, 1)) { $0.head.y >= Double(stair.to) * world.kit.floorHeight - 1e-9 }

        XCTAssertEqual(body.floor, stair.to, "the balcony cannot be reached from the start")
        XCTAssertEqual(body.head.y, Double(stair.to) * world.kit.floorHeight, accuracy: 1e-9)
    }

    func testAClimbTakesTheTimeItsHeightIsWorth() throws {
        // FR-SNAKE-030: the stair is walked at the configured speed, so three metres
        // of it cost a second at three metres a second — a climb that cost nothing
        // read as a teleport on the device.
        let surfaces = try stairs()
        var body = snake(at: 1)          // one cell from the stair
        let speed = 3.0
        var frames = 0
        while body.floor == 0, frames < 600 {
            body.advance(direction: SIMD2(1, 0), speed: speed, seconds: 1.0 / 60, over: surfaces)
            frames += 1
        }
        let atFoot = frames
        while body.head.y < kit.floorHeight - 1e-9, frames < 600 {
            body.advance(direction: SIMD2(1, 0), speed: speed, seconds: 1.0 / 60, over: surfaces)
            frames += 1
        }
        let climbing = Double(frames - atFoot) / 60
        XCTAssertEqual(climbing, kit.floorHeight / speed, accuracy: 0.05,
                       "the climb took \(climbing) s for \(kit.floorHeight) m at \(speed) m/s")
    }

    func testTheHeadRisesThroughTheHeightsRatherThanJumpingToTheTop() throws {
        let surfaces = try stairs()
        var body = snake(at: 1)
        var heights: [Double] = []
        for _ in 0..<120 {
            body.advance(direction: SIMD2(1, 0), speed: 3.0, seconds: 1.0 / 60, over: surfaces)
            heights.append(body.head.y)
        }
        // Something in between, which is what the tail follows up the stair.
        let between = heights.filter { $0 > 1e-9 && $0 < kit.floorHeight - 1e-9 }
        XCTAssertGreaterThan(between.count, 30, "the head went up in one jump")
        XCTAssertEqual(try XCTUnwrap(heights.last), kit.floorHeight, accuracy: 1e-9)
    }

    func testAWallOnTheBalconyIsAWallAndNotALedge() throws {
        // Found by walking the shipped map: the balcony's west edge is a wall
        // standing on it, with open floor below. A drop that asked only what was
        // underneath took the head through that wall and down (FR-SNAKE-010).
        let world = try Launch.world().get()
        let size = world.configurations.tuning.navigationGraphCellSize
        let surfaces = Surfaces(graph: world.graph, kit: world.kit,
                                tuning: world.configurations.tuning, map: world.map)
        let wall = NavigationGraph.Node(floor: 1, x: 14, z: 12)
        let beside = NavigationGraph.Node(floor: 1, x: 15, z: 12)
        XCTAssertFalse(world.graph.isWalkable(wall), "the map changed: (14,12) is no longer a wall")
        XCTAssertTrue(world.graph.isWalkable(NavigationGraph.Node(floor: 0, x: 14, z: 12)),
                      "the map changed: there is no floor under that wall")

        var body = Snake(head: SIMD3(Double(beside.x) * size, world.kit.floorHeight,
                                     Double(beside.z) * size),
                         floor: 1, segments: 4, segmentSpacing: 0.6)
        for _ in 0..<60 {
            body.advance(direction: SIMD2(-1, 0), speed: 3.0, seconds: 1.0 / 60, over: surfaces)
        }
        XCTAssertEqual(body.floor, 1, "the head went through the balcony's wall and fell")
        XCTAssertEqual(body.head.y, world.kit.floorHeight, accuracy: 1e-9)

        // And the way down is the stair it came up: this balcony is walled on the two
        // sides that face the room and ends at the map's edge on the others, so with
        // the wall holding, a one-way transition would make it a trap.
        let stair = try XCTUnwrap(world.map.transitions.first)
        var leaving = Snake(head: SIMD3(Double(stair.x) * size, world.kit.floorHeight,
                                        Double(stair.z + 2) * size),
                            floor: 1, segments: 4, segmentSpacing: 0.6)
        for _ in 0..<180 {
            leaving.advance(direction: SIMD2(0, -1), speed: 3.0, seconds: 1.0 / 60, over: surfaces)
        }
        XCTAssertEqual(leaving.floor, stair.from, "the balcony is a trap: the stair does not go down")
        XCTAssertEqual(leaving.head.y, 0, accuracy: 1e-9)
    }

    func testAStairIsOnlyAWayUpFromBelow() throws {
        let surfaces = try stairs()
        XCTAssertEqual(surfaces.rise(at: SIMD3(2 * cell, 0, 0), from: 0), 1)
        XCTAssertNil(surfaces.rise(at: SIMD3(2 * cell, kit.floorHeight, 0), from: 1),
                     "the stair offered a floor above the top one")
        XCTAssertNil(surfaces.rise(at: SIMD3(0, 0, 0), from: 0), "a plain floor cell offered a way up")
    }
}
