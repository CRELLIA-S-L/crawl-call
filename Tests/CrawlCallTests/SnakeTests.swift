// The head's movement and the tail that follows it. Geometry is compared within a
// tolerance, never for equality (`specs/50-verification.md`).
//
// verifies: FR-SNAKE-010, FR-SNAKE-015, FR-SNAKE-020, FR-SNAKE-030, FR-SNAKE-220, FR-MAP-025, FR-MAP-150, FR-SNAKE-260
import XCTest
@testable import CrawlCall

final class SnakeTests: XCTestCase {
    private var kit: Kit!
    private var tuning: TuningConfiguration!

    override func setUpWithError() throws {
        try super.setUpWithError()
        kit = try Kit.load(named: "blockout", from: .main)
        tuning = try Configurations.load(from: .main).tuning
    }

    /// A small room with a wall on its right and an upper floor joined by one cell.
    private func surfaces(_ text: String) throws -> Surfaces {
        let map = try MapParser.parse(text, kit: kit)
        return Surfaces(graph: NavigationGraph.derive(from: map, stepHeight: ShippedTuning.stepHeight), kit: kit, tuning: tuning, map: map)
    }

    private func snake(at x: Double, _ z: Double, floor: Int = 0, segments: Int = 4) -> Snake {
        Snake(head: SIMD3(x, Double(floor) * kit.floorHeight, z), floor: floor,
              segments: segments, segmentSpacing: tuning.bodyRadius * 2)
    }

    // MARK: the head

    func testTheHeadMovesTheWayThePlayerHolds() throws {
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n....\n....\n")
        var snake = self.snake(at: 0, 0)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.1, over: s)
        XCTAssertEqual(snake.head.x, 0.3, accuracy: 1e-9)
        XCTAssertEqual(snake.head.z, 0, accuracy: 1e-9)
    }

    func testItAdvancesAtTheSpeedItIsGivenForTheTimeItIsGiven() throws {
        // FR-SNAKE-030: the distance is speed × time and nothing else.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n......\n")
        var snake = self.snake(at: 0, 0)
        snake.advance(direction: SIMD2(1, 0), speed: 2, seconds: 0.25, over: s)
        XCTAssertEqual(snake.head.x, 0.5, accuracy: 1e-9)
        snake.advance(direction: SIMD2(1, 0), speed: 4, seconds: 0.25, over: s)
        XCTAssertEqual(snake.head.x, 1.5, accuracy: 1e-9)
    }

    func testADiagonalHoldIsNotFasterThanAStraightOne() throws {
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n....\n....\n")
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
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n.#\n")
        var snake = self.snake(at: 0, 0)
        snake.advance(direction: SIMD2(1, 0), speed: 10, seconds: 1, over: s)
        XCTAssertEqual(snake.head.x, 0, accuracy: 1e-9)
    }

    func testALongFrameDoesNotCarryTheHeadThroughAWall() throws {
        // A corridor with a wall in the middle and floor beyond it. One frame of half
        // a second at three metres a second is 1.5 m — past the wall, if the step is
        // taken whole.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n..#..\n")
        var snake = self.snake(at: 0, 0)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.5, over: s)
        XCTAssertLessThan(snake.head.x, 1.0, "the head passed through the wall at x = 1.0")
    }

    func testNoDirectionMeansNoMovement() throws {
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n....\n")
        var snake = self.snake(at: 0, 0)
        snake.advance(direction: SIMD2(0, 0), speed: 3, seconds: 0.1, over: s)
        XCTAssertEqual(snake.head.x, 0, accuracy: 1e-12)
        XCTAssertEqual(snake.trail.count, 1)
    }

    // MARK: sliding along what stopped it (FR-SNAKE-015)

    /// A wall running along z, with floor beside it, long enough for a second of
    /// sliding not to run off its end.
    private func wallAlongZ() throws -> Surfaces {
        try surfaces("kit blockout\nsetting greenholm\nfloor 0\n" + String(repeating: ".#\n", count: 12))
    }

    /// Where a head beside the wall of `wallAlongZ` stands with its body touching the
    /// wall's face: the face is half a cell from the head's cell, and the body is its
    /// radius wide (ADR-0021).
    private var touching: Double { 0.25 - tuning.bodyRadius }

    func testAHeadHeldIntoAWallAtAnAngleGoesAlongItAtTheBaseSpeed() throws {
        // Since 2026-09-30 the head goes round what it meets at the whole of its speed,
        // as a snake does, not at the part of it the stick lays along the wall (ADR-0069).
        let s = try wallAlongZ()
        var snake = self.snake(at: touching, 0)
        let before = snake.head
        snake.advance(direction: SIMD2(1, 1), speed: 3, seconds: 1, over: s)
        XCTAssertEqual(snake.head.x, before.x, accuracy: 1e-9, "the head went into the wall")
        XCTAssertEqual(snake.head.z - before.z, 3, accuracy: 1e-9)
    }

    func testAtAnyAngleIntoAWallTheHeadKeepsItsSpeedAndTheSideTheStickLeansTo() throws {
        // Two holds against the same wall, one nearly along it and one nearly into it:
        // both go the whole of the base speed, the way along the wall the stick leans.
        let s = try wallAlongZ()
        var shallow = snake(at: touching, 0)
        var steep = snake(at: touching, 0)
        shallow.advance(direction: SIMD2(0.2, 1), speed: 3, seconds: 0.5, over: s)
        steep.advance(direction: SIMD2(1, 0.2), speed: 3, seconds: 0.5, over: s)
        XCTAssertEqual(shallow.head.z, 1.5, accuracy: 1e-9)
        XCTAssertEqual(steep.head.z, 1.5, accuracy: 1e-9)
    }

    func testAHeadHeldSquarelyIntoAWallNearItsSouthEndGoesRoundNorth() throws {
        // The mirror of the test below: a cell from the wall's south end, the roomier side
        // is the north.
        let s = try wallAlongZ()
        var snake = self.snake(at: touching, 5.5)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.5, over: s)
        XCTAssertEqual(snake.head.x, touching, accuracy: 1e-9, "the head went into the wall")
        XCTAssertEqual(snake.head.z, 5.5 - 1.5, accuracy: 1e-9, "the head did not go round at its speed to the roomier side")
    }

    func testAHeadHeldSquarelyIntoAWallGoesRoundToTheSideWithMoreRoom() throws {
        // Leaning to neither side, it takes the side with more room: here, starting a
        // cell from the wall's north end, the south.
        let s = try wallAlongZ()
        var snake = self.snake(at: touching, 0.5)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.5, over: s)
        XCTAssertEqual(snake.head.x, touching, accuracy: 1e-9, "the head went into the wall")
        XCTAssertEqual(snake.head.z, 0.5 + 1.5, accuracy: 1e-9, "the head did not go round at its speed to the roomier side")
    }

    func testACornerStopsTheHeadBecauseNeitherWayIsOpen() throws {
        // Two walls, one on each way out. The same rule refuses twice.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n.#\n##\n")
        var snake = self.snake(at: touching, touching)
        snake.advance(direction: SIMD2(1, 1), speed: 3, seconds: 1, over: s)
        XCTAssertEqual(snake.head.x, touching, accuracy: 1e-9)
        XCTAssertEqual(snake.head.z, touching, accuracy: 1e-9)
    }

    func testTheHeadSlidesAlongTheLipOfAHoleAsAlongAWall() throws {
        // A cell with no module and nothing under it is refused by the same code path
        // a wall is (FR-SNAKE-220), so the requirement's "what it cannot pass" covers
        // both without naming them apart.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n" + String(repeating: ". \n", count: 12))
        var snake = self.snake(at: 0.24, 0)
        snake.advance(direction: SIMD2(1, 1), speed: 3, seconds: 1, over: s)
        XCTAssertEqual(snake.head.x, 0.24, accuracy: 1e-9, "the head walked out over the hole")
        XCTAssertEqual(snake.head.z, 3, accuracy: 1e-9)
        XCTAssertEqual(snake.floor, 0)
    }

    func testTheTailFollowsTheHeadAlongTheWallRatherThanThroughIt() throws {
        // The slide goes into the trail like any other movement, or the tail would
        // cut the corner the head just took (FR-SNAKE-020).
        let s = try wallAlongZ()
        var snake = self.snake(at: touching, 0, segments: 3)
        snake.advance(direction: SIMD2(1, 1), speed: 3, seconds: 1, over: s)
        XCTAssertEqual(snake.tail.count, 3)
        for segment in snake.tail {
            XCTAssertLessThanOrEqual(segment.x, touching + 1e-9, "a segment lies inside the wall")
        }
    }

    // MARK: the body against what stands on the ground (FR-SNAKE-010, ADR-0021)

    func testAHeadHeldIntoAWallStopsWithItsBodyAgainstTheFace() throws {
        // The wall's cell is x = 1.5, so its face is at 1.25 and the body, 0.3 m wide
        // either side of the head, touches it with the head at 0.95. Kept to walkable
        // cells alone, the head stopped at 1.0 — the last centre whose cell is floor —
        // with its body 5 cm into the wall (Q-230).
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n...#\n")
        var snake = self.snake(at: 0, 0)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 1, over: s)
        XCTAssertEqual(snake.head.x, 1.25 - tuning.bodyRadius, accuracy: 1e-6)
        // Going round it, the head gets no further than its one row of ground allows.
        XCTAssertLessThanOrEqual(abs(snake.head.z), 0.25 + 1e-9)
        XCTAssertTrue(s.fits(snake.head, floor: 0), "the body is in the wall")
    }

    func testAThinPartitionStopsTheBodyAtItsOwnFaceNotAtItsCell() throws {
        // The partition is 0.1 m deep in a cell of 0.5, centred in it: its face is
        // 0.05 m from the cell's centre, so the body stops 0.3 m short of that and
        // not at the cell's edge. The partition's cell is at z = 1.0.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n.\n.\n=\n.\n")
        var snake = self.snake(at: 0, 0)
        snake.advance(direction: SIMD2(0, 1), speed: 3, seconds: 1, over: s)
        XCTAssertEqual(snake.head.z, 1.0 - 0.05 - tuning.bodyRadius, accuracy: 1e-6)
    }

    func testTheBodyGoesThroughAGapWiderThanItself() throws {
        // The shipped blockout's one way between the partitions: rows 5 and 7 of
        // column 10 hold a partition each, row 6 is open, and the gap between the two
        // is 0.9 m — wide enough for a body of 0.6.
        let world = try Launch.world(map: "room").get()
        let surfaces = Surfaces(graph: world.graph, kit: world.kit, tuning: world.configurations.tuning, map: world.map)
        XCTAssertFalse(world.graph.isWalkable(NavigationGraph.Node(floor: 0, x: 10, z: 5)),
                       "the map changed: (10,5) is no longer a partition")
        XCTAssertFalse(world.graph.isWalkable(NavigationGraph.Node(floor: 0, x: 10, z: 7)),
                       "the map changed: (10,7) is no longer a partition")
        // From x = 4 to 5.8, through the partitions' column at 5.0 and short of the
        // crates further along the row at 7.0.
        var snake = Snake(head: SIMD3(4, 0, 3), floor: 0, segments: 4, segmentSpacing: tuning.bodyRadius * 2)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.6, over: surfaces)
        XCTAssertEqual(snake.head.x, 5.8, accuracy: 1e-9, "the body did not fit through the gap")
        XCTAssertEqual(snake.head.z, 3, accuracy: 1e-12)
    }

    func testAtTheEndOfAWallTheHeadRoundsTheCornerRatherThanCatchingOnIt() throws {
        // A wall along z, three cells long, whose far end has a corner at (0.25, 1.25).
        // The head touches that corner from beyond the wall's end, off to one side, and
        // is held diagonally into it. Both parts of the held direction lead into the
        // corner, so split along the axes the head would stand there; laid along the
        // face it touches, the rest of the step takes it round onto the wall's side
        // and down it.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n.#\n.#\n.#\n..\n..\n")
        let corner = SIMD2(0.25, 1.25)
        let outward = SIMD2(-0.8, 0.6)
        var snake = self.snake(at: corner.x + outward.x * tuning.bodyRadius,
                               corner.y + outward.y * tuning.bodyRadius)
        snake.advance(direction: SIMD2(1, -1), speed: 3, seconds: 0.5, over: s)
        XCTAssertLessThan(snake.head.z, 1.0, "the head caught on the corner")
        XCTAssertEqual(snake.head.x, touching, accuracy: 1e-6, "the head did not come to rest against the wall's side")
        XCTAssertTrue(s.fits(snake.head, floor: 0), "the body went into the wall rounding it")
    }

    func testInACornerTheHeadSlidesAlongTheWallItIsNotPressingInto() throws {
        // Found walking the blockout: in a corner the body touches two walls at once,
        // and a head held along one of them and slightly into the other froze there.
        // What it was laid along was the nearest wall, and with both at the same
        // distance that was whichever the map listed first — here the top wall, which
        // it was not pressing into. Top wall at z = 0, side wall at x = 1.0.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n###\n..#\n..#\n..#\n")
        let start = SIMD2(0.75 - tuning.bodyRadius, 0.25 + tuning.bodyRadius)
        var snake = self.snake(at: start.x, start.y)
        let held = SIMD2(0.11, 0.99)
        snake.advance(direction: held, speed: 3, seconds: 0.2, over: s)
        // At the whole of the base speed along the side wall (ADR-0069).
        XCTAssertEqual(snake.head.z, start.y + 0.6, accuracy: 1e-6, "the head froze in the corner")
        XCTAssertEqual(snake.head.x, start.x, accuracy: 1e-6)
    }

    func testHowEverTheHeadIsSteeredItsBodyStaysOutOfEveryWall() throws {
        // A room with a crate, a partition and walls, and the head steered round it
        // in every direction the stick has, long enough in each to reach something.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n#########\n#.......#\n#.......#\n#..o....#\n#.......#\n#....=..#\n#.......#\n#########\n")
        var snake = self.snake(at: 2, 1)
        XCTAssertTrue(s.fits(snake.head, floor: 0), "the test starts inside a wall")
        var touched = 0
        for turn in 0..<16 {
            let angle = Double(turn) * .pi / 8 + 0.3
            snake.advance(direction: SIMD2(cos(angle), sin(angle)), speed: 3, seconds: 0.8, over: s)
            let gap = try XCTUnwrap(s.clearance(at: snake.head, floor: 0)).metres
            XCTAssertGreaterThanOrEqual(gap, -1e-9, "the body is inside something after turn \(turn)")
            if gap < 1e-6 { touched += 1 }
        }
        XCTAssertGreaterThan(touched, 0, "the head never reached anything, so nothing was tested")
    }

    func testGroundIsInTheBodysWayOnlyWhereItStandsMoreThanAStepAboveItsFeet() throws {
        // ADR-0033: a step one step up is walked onto; one taller is the side of a
        // step, met like a wall. On a flight's first step, from the floor it stands on
        // the second step, two steps up, is in the way; from the first step itself it
        // is one step up, and is not.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n..>>>>>>>>.\nfloor 1\n          .\n")
        let rise = try Kit.load(named: "blockout", from: .main).floorHeight / 8
        // A clearance is the gap to the nearest thing in the way: negative is inside it.
        XCTAssertGreaterThan(try XCTUnwrap(s.clearance(at: SIMD3(0.5, 0, 0), feet: 0)).metres, 0,
                             "the first step, one step up, is in the body's way")
        XCTAssertLessThan(try XCTUnwrap(s.clearance(at: SIMD3(1.0, 0, 0), feet: 0)).metres, 0,
                          "the second step, two steps up, is not in the way of a body on the floor")
        XCTAssertGreaterThan(try XCTUnwrap(s.clearance(at: SIMD3(1.0, rise, 0), feet: rise)).metres, 0,
                             "standing on the first, the second is still a wall")
    }

    func testAWallOnTheFloorAboveIsNotInTheWayOfAHeadBelow() throws {
        // A balcony's wall stands over open ground; the head walks under it.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n....\nfloor 1\n  # \n")
        var snake = self.snake(at: 0, 0)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.5, over: s)
        XCTAssertEqual(snake.head.x, 1.5, accuracy: 1e-9)
        XCTAssertNil(s.clearance(at: SIMD3(1, 0, 0), floor: 0))
        XCTAssertNotNil(s.clearance(at: SIMD3(1, kit.floorHeight, 0), floor: 1),
                        "the wall above is not there at all, so the test proves nothing")
    }

    func testAHeadSetDownInsideAWallMayLeaveItButGoNoDeeper() throws {
        // Only a test or the start of a match puts a head there. It is never frozen:
        // along the wall and away from it are open, into it is not.
        // Deeper by 5 cm, which stays in the head's own cell: the grid has nothing to
        // say against it, and only the body can refuse it.
        let s = try wallAlongZ()
        var into = snake(at: 0.1, 0)
        into.advance(direction: SIMD2(1, 0), speed: 3, seconds: 1.0 / 60, over: s)
        XCTAssertEqual(into.head.x, 0.1, accuracy: 1e-12, "the head went deeper into the wall")

        var along = snake(at: 0.1, 0)
        along.advance(direction: SIMD2(0, 1), speed: 3, seconds: 0.2, over: s)
        XCTAssertEqual(along.head.z, 0.6, accuracy: 1e-9)
        XCTAssertEqual(along.head.x, 0.1, accuracy: 1e-12)

        var out = snake(at: 0.1, 0)
        out.advance(direction: SIMD2(-1, 0), speed: 3, seconds: 0.1, over: s)
        XCTAssertEqual(out.head.x, 0.1 - 0.3, accuracy: 1e-9)
    }

    func testTheMatchSetsTheHeadDownClearOfTheWalls() throws {
        // The blockout's start is its corner cell, a quarter of a metre from two walls;
        // the body, 0.3 m wide, would start the match 5 cm into both.
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        let game = Game(world: world, start: start)
        let surfaces = Surfaces(graph: world.graph, kit: world.kit, tuning: world.configurations.tuning, map: world.map)
        let size = world.configurations.tuning.navigationGraphCellSize
        let centre = SIMD3(Double(start.x) * size, 0, Double(start.z) * size)
        XCTAssertFalse(surfaces.fits(centre, floor: start.floor),
                       "the start cell's centre is clear already, so the test proves nothing")
        XCTAssertTrue(surfaces.fits(game.snake.head, floor: start.floor), "the match starts inside a wall")
        XCTAssertEqual(surfaces.cell(of: game.snake.head, floor: start.floor), start,
                       "the head was moved out of its start cell")
        // Moved out and no further: the body touches both walls.
        XCTAssertEqual(try XCTUnwrap(surfaces.clearance(at: game.snake.head, floor: start.floor)).metres, 0, accuracy: 1e-9)
    }

    func testALandingInsideSomethingBelowIsRefusedLikeAWall() throws {
        // The ledge ends at x = 0.25 and the ground below goes on, but a wall stands
        // down there beside the landing, a quarter of a metre off the line the head
        // drops along. Without the wall the same drop is taken.
        let blocked = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n..\n.#\nfloor 1\n. \n  \n")
        let open = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n..\n..\nfloor 1\n. \n  \n")
        var stopped = snake(at: 0, 0, floor: 1)
        var dropped = snake(at: 0, 0, floor: 1)
        stopped.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.2, over: blocked)
        dropped.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.2, over: open)
        XCTAssertEqual(stopped.floor, 1, "the head dropped into the wall below")
        XCTAssertEqual(dropped.floor, 0, "the drop was not open to begin with, so the test proves nothing")
    }

    // MARK: the drop

    func testSteeringOffALedgeLandsOnTheFloorBelow() throws {
        // FR-SNAKE-220: a drop is a path. The upper floor ends at x = 0; below it the
        // ground floor continues.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n..........\nfloor 1\n.         \n")
        var snake = self.snake(at: 0, 0, floor: 1)
        XCTAssertEqual(snake.head.y, kit.floorHeight, accuracy: 1e-9)
        for _ in 0..<90 { snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 1.0 / 60, over: s) }
        XCTAssertEqual(snake.floor, 0)
        XCTAssertNil(snake.drop, "the head is still in the air after a second and a half")
        XCTAssertEqual(snake.head.y, 0, accuracy: 1e-9)
    }

    /// Walks a snake off the upper floor's edge frame by frame and returns it the
    /// moment it goes over, with the arc it took.
    private func overTheEdge(_ s: Surfaces, speed: Double = 3) throws -> (Snake, Snake.Drop) {
        var snake = self.snake(at: 0, 0, floor: 1)
        var frames = 0
        while snake.drop == nil && snake.floor == 1 && frames < 120 {
            snake.advance(direction: SIMD2(1, 0), speed: speed, seconds: 1.0 / 60, over: s)
            frames += 1
        }
        return (snake, try XCTUnwrap(snake.drop, "the head did not go over the edge in an arc"))
    }

    func testADropIsAnArcAtTheWalkingSpeedUnderTheDropGravity() throws {
        // FR-SNAKE-220, ADR-0040: on across at the speed it walked off at, down as a
        // body falls, landing as far on as that takes it where the ground is open.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n..........\nfloor 1\n.         \n")
        XCTAssertEqual(s.dropGravity, tuning.dropGravity)
        let (start, arc) = try overTheEdge(s)
        let height = kit.floorHeight
        let fall = (2 * height / tuning.dropGravity).squareRoot()
        XCTAssertEqual(arc.seconds, fall, accuracy: 1e-9)
        XCTAssertEqual(arc.from.y, height, accuracy: 1e-9)
        XCTAssertEqual(arc.to.y, 0, accuracy: 1e-9)
        let across = arc.to.x - arc.from.x
        XCTAssertLessThanOrEqual(across, 3 * fall + 1e-9, "farther than the speed carries it in the fall")
        XCTAssertGreaterThan(across, 3 * fall - Motion.arcSearchStep - 1e-9, "shorter than open ground asks")
        XCTAssertEqual(arc.to.z, arc.from.z, accuracy: 1e-12)

        // Frame by frame: across at a steady rate, down as the square of the time.
        let frame = 1.0 / 60
        var snake = start
        var time = arc.elapsed
        while snake.drop != nil {
            snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: frame, over: s)
            time += frame
            guard snake.drop != nil else { break }
            let share = time / arc.seconds
            XCTAssertEqual(snake.head.x, arc.from.x + across * share, accuracy: 1e-9)
            XCTAssertEqual(snake.head.y, height * (1 - share * share), accuracy: 1e-9)
        }
        XCTAssertEqual(time, arc.seconds, accuracy: frame + 1e-9)
        XCTAssertEqual(snake.head.y, 0, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(snake.head.x, arc.to.x - 1e-9, "the head did not land where the arc ends")
    }

    func testAnArcIsCutShortWhereSomethingBelowIsInTheWay() throws {
        // A wall on the ground floor a metre and a half out: the arc lands short of
        // it, clear of it, rather than through it.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n...#......\nfloor 1\n.         \n")
        let (_, arc) = try overTheEdge(s)
        let cell = tuning.navigationGraphCellSize
        let wallStarts = 3 * cell - cell / 2
        XCTAssertLessThanOrEqual(arc.to.x, wallStarts - tuning.bodyRadius + 1e-9, "the arc lands in the wall")
        XCTAssertTrue(s.fits(arc.to, feet: arc.to.y, leaving: arc.from.y))
        XCTAssertGreaterThan(arc.to.x, arc.from.x, "the arc came straight down though the ground before the wall is open")
    }

    func testAnArcWithNoGroundFartherOnLandsOnTheGroundThereIs() throws {
        // The ground floor ends a cell past the edge: the arc lands on it, not beyond.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n..\nfloor 1\n. \n")
        let (_, arc) = try overTheEdge(s)
        let cell = tuning.navigationGraphCellSize
        XCTAssertLessThanOrEqual(arc.to.x, cell * 1.5 + 1e-9, "the arc landed where there is no ground")
        XCTAssertEqual(arc.to.y, 0, accuracy: 1e-9)
    }

    func testAnArcDoesNotGoOnUnderTheFloorItLeft() throws {
        // A hole two cells across in an upper floor, the floor going on past it: the
        // arc lands in the hole, not on across under the floor on the far side, which
        // it would pass through to get there.
        let upper = "......\n.  ...\n.  ...\n......"
        let ground = "......\n......\n......\n......"
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n\(ground)\nfloor 1\n\(upper)\n")
        var snake = self.snake(at: 0, 0.5, floor: 1)
        var frames = 0
        while snake.drop == nil && frames < 120 {
            snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 1.0 / 60, over: s)
            frames += 1
        }
        let arc = try XCTUnwrap(snake.drop, "the head did not go into the hole")
        let cell = tuning.navigationGraphCellSize
        let farSide = 3 * cell - cell / 2
        XCTAssertLessThan(arc.to.x, farSide, "the arc lands under the floor beyond the hole, at \(arc.to)")
        XCTAssertEqual(arc.to.y, 0, accuracy: 1e-9)
    }

    func testADropIsComeDownWithNoDirectionHeld() throws {
        // A drop is not walked: letting go of the stick does not leave the head in the air.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n..........\nfloor 1\n.         \n")
        var (snake, _) = try overTheEdge(s)
        for _ in 0..<90 { snake.advance(direction: .zero, speed: 3, seconds: 1.0 / 60, over: s) }
        XCTAssertNil(snake.drop)
        XCTAssertEqual(snake.head.y, 0, accuracy: 1e-9)
    }

    func testCrossingACornerOfACellOnAnUpperFloorIsNoLedge() throws {
        // A head that crosses a corner of its cell enters the cell corner to corner with
        // it. On a balcony that dropped it to the floor below wherever it happened; the
        // corner is ground, reached through either cell beside it (FR-SNAKE-220).
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n...\n...\n...\nfloor 1\n...\n...\n...\n")
        var snake = self.snake(at: 0.24, 0.24, floor: 1)
        let across = 0.5.squareRoot()
        snake.advance(direction: SIMD2(across, across), speed: 3, seconds: 1.0 / 60, over: s)
        XCTAssertGreaterThan(snake.head.x, 0.25, "the head did not cross the corner, so the test proves nothing")
        XCTAssertGreaterThan(snake.head.z, 0.25, "the head did not cross the corner, so the test proves nothing")
        XCTAssertEqual(snake.floor, 1, "the head dropped off a balcony at the corner of a cell")
        XCTAssertEqual(snake.head.y, kit.floorHeight, accuracy: 1e-9)
    }

    func testACornerWithNothingBeyondItIsStillALedge() throws {
        // Where the cell the corner leads to is not there on the upper floor, the head
        // goes off the edge as it would off a side.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n..\n..\nfloor 1\n..\n. \n")
        var snake = self.snake(at: 0.24, 0.24, floor: 1)
        let across = 0.5.squareRoot()
        snake.advance(direction: SIMD2(across, across), speed: 3, seconds: 1.0 / 60, over: s)
        XCTAssertEqual(snake.floor, 0)
    }

    // MARK: a gap narrower than the body

    /// Walks the snake east along the middle row of an upper floor and says where it got.
    private func crawl(_ upper: String, seconds: Double) throws -> Snake {
        let rows = upper.split(separator: "\n", omittingEmptySubsequences: false)
        let ground = rows.map { String(repeating: ".", count: $0.count) }.joined(separator: "\n")
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n\(ground)\nfloor 1\n\(upper)\n")
        var snake = self.snake(at: 0, 0.5, floor: 1)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: seconds, over: s)
        return snake
    }

    func testAGapInTheFloorNarrowerThanTheBodyIsCrawledAcross() throws {
        // A hole of one cell, 0.5 m, in a floor, crossed by a body 0.6 m wide
        // (FR-SNAKE-260). The head goes over it at the floor's height and on.
        let snake = try crawl("....\n. ..\n....", seconds: 0.4)
        XCTAssertGreaterThan(snake.head.x, 1.1, "the head did not get past the gap")
        XCTAssertEqual(snake.floor, 1, "the snake fell into a gap narrower than its body")
        XCTAssertTrue(snake.trail.allSatisfy { abs($0.y - kit.floorHeight) < 1e-9 },
                      "some part of the snake went down into the gap")
    }

    func testASlotNarrowerThanTheBodyIsCrawledAcrossWhateverItsLength() throws {
        // Two cells long, one across: the body cannot fall into it along its length.
        let snake = try crawl(".....\n.  ..\n.....", seconds: 0.5)
        XCTAssertGreaterThan(snake.head.x, 1.3, "the head did not get past the slot, which ends at 1.25")
        XCTAssertEqual(snake.floor, 1)
    }

    func testAGapAsWideAsTheBodyIsALedge() throws {
        // Two cells each way: the body fits, and drops (FR-SNAKE-220).
        let snake = try crawl("....\n.  .\n.  .\n....", seconds: 0.4)
        XCTAssertEqual(snake.floor, 0)
    }

    func testTwoCellsThatMeetAtAPointAreCrawledBetween() throws {
        // A joint is a gap of no width at all (FR-SNAKE-260).
        let point = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n..\n..\nfloor 1\n. \n .\n")
        var snake = self.snake(at: 0.24, 0.24, floor: 1)
        let across = 0.5.squareRoot()
        snake.advance(direction: SIMD2(across, across), speed: 3, seconds: 1.0 / 60, over: point)
        XCTAssertGreaterThan(snake.head.x, 0.25, "the head did not cross the joint, so the test proves nothing")
        XCTAssertEqual(snake.floor, 1, "the snake fell through a joint")
    }

    func testEveryDropOffTheShippedFlightAndBalconyLandsClear() throws {
        // The blockout's flight and balcony, walked off every way from every cell of
        // them: each arc lands where the body fits, on the ground it lands on, and
        // some go farther than straight down (FR-SNAKE-220, ADR-0040).
        let world = try Launch.world().get()
        let cell = world.configurations.tuning.navigationGraphCellSize
        let s = Surfaces(graph: world.graph, kit: world.kit, tuning: world.configurations.tuning, map: world.map)
        let raised = world.graph.nodes.filter { s.height(of: $0) > world.configurations.tuning.stepHeight }
        XCTAssertFalse(raised.isEmpty, "the shipped map has no flight or balcony, so the test proves nothing")
        var drops = 0, arcs = 0
        for node in raised {
            for direction in [SIMD2(1.0, 0), SIMD2(-1.0, 0), SIMD2(0, 1.0), SIMD2(0, -1.0)] {
                let start = SIMD3(Double(node.x) * cell, s.height(of: node), Double(node.z) * cell)
                guard s.fits(start, feet: start.y) else { continue }
                var snake = Snake(head: start, floor: node.floor, segments: 4, segmentSpacing: cell)
                var frames = 0
                while snake.drop == nil && frames < 60 {
                    snake.advance(direction: direction, speed: 3, seconds: 1.0 / 60, over: s)
                    frames += 1
                }
                guard let arc = snake.drop else { continue }
                drops += 1
                XCTAssertTrue(s.fits(arc.to, feet: arc.to.y, leaving: arc.from.y),
                              "an arc off \(node) going \(direction) lands inside something at \(arc.to)")
                XCTAssertLessThan(arc.to.y, arc.from.y, "an arc off \(node) does not go down")
                let across = ((arc.to.x - arc.from.x) * (arc.to.x - arc.from.x)
                              + (arc.to.z - arc.from.z) * (arc.to.z - arc.from.z)).squareRoot()
                if across > 0.1 { arcs += 1 }
                for _ in 0..<120 where snake.drop != nil {
                    snake.advance(direction: direction, speed: 3, seconds: 1.0 / 60, over: s)
                }
                XCTAssertNil(snake.drop, "the head off \(node) is still in the air after two seconds")
            }
        }
        XCTAssertGreaterThan(drops, 10, "hardly anything on the shipped map is a ledge, so the test proves little")
        XCTAssertGreaterThan(arcs, drops / 2, "most drops came straight down")
    }

    func testTheTrailFollowsTheArcDown() throws {
        // The tail lies down the drop: the trail holds the heights between the two
        // floors, each farther on than the one above it (FR-SNAKE-220).
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n..........\nfloor 1\n.         \n")
        var snake = self.snake(at: 0, 0, floor: 1, segments: 12)
        for _ in 0..<90 { snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 1.0 / 60, over: s) }
        let inAir = snake.trail.filter { $0.y > 1e-9 && $0.y < kit.floorHeight - 1e-9 }
        XCTAssertGreaterThan(inAir.count, 10, "the trail does not hold the arc")
        // Newest first: going back along the trail, higher and nearer the edge.
        for (later, earlier) in zip(inAir, inAir.dropFirst()) {
            XCTAssertGreaterThan(earlier.y, later.y)
            XCTAssertLessThan(earlier.x, later.x)
        }
        XCTAssertEqual(snake.head.y, 0, accuracy: 1e-9)
        XCTAssertEqual(snake.floor, 0)
    }

    func testADropWithNothingToLandOnIsAWall() throws {
        // Nothing below the edge: the head stays rather than falling out of the world.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 1\n. \n")
        var snake = self.snake(at: 0, 0, floor: 1)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.2, over: s)
        XCTAssertEqual(snake.floor, 1)
        XCTAssertEqual(snake.head.x, 0, accuracy: 1e-9)
    }

    // MARK: the tail

    func testTheTailLiesAlongThePathTheHeadTravelled() throws {
        // FR-SNAKE-020: each segment one spacing behind the last, back along the trail.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n........\n")
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
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n....\n....\n....\n")
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
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n.....\n.....\n.....\n.....\n")
        var snake = self.snake(at: 0, 0, segments: 2)
        for _ in 0..<4 { snake.advance(direction: SIMD2(0, 1), speed: 3, seconds: 1.0 / 12, over: s) }
        for _ in 0..<4 { snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 1.0 / 12, over: s) }
        XCTAssertEqual(snake.head.x, 1.0, accuracy: 1e-9)
        XCTAssertEqual(snake.head.z, 1.0, accuracy: 1e-9)

        let tail = snake.tail
        XCTAssertEqual(tail.count, 2)
        XCTAssertEqual(try element(0, of: tail).x, 0.4, accuracy: 1e-6)
        XCTAssertEqual(try element(0, of: tail).z, 1.0, accuracy: 1e-6)
        XCTAssertEqual(try element(1, of: tail).x, 0.0, accuracy: 1e-6)
        XCTAssertEqual(try element(1, of: tail).z, 0.8, accuracy: 1e-6)
    }

    func testAShortTrailGivesAsManySegmentsAsItCanCarry() throws {
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n....\n")
        var snake = self.snake(at: 0, 0, segments: 5)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 0.05, over: s)
        XCTAssertLessThan(snake.tail.count, 5)
    }

    func testTheTailFollowsTheHeadDownADrop() throws {
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n....\nfloor 1\n..  \n")
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
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n..\n")
        XCTAssertEqual(s.cellSize, tuning.navigationGraphCellSize)
        XCTAssertEqual(s.bodyRadius, tuning.bodyRadius)
        XCTAssertEqual(s.stepHeight, tuning.stepHeight)
        XCTAssertEqual(s.slopeAngle, tuning.slopeAngle)
        XCTAssertEqual(s.maximumDropHeight, tuning.maximumDropHeight)
        XCTAssertEqual(s.dropGravity, tuning.dropGravity)
        XCTAssertEqual(s.floorHeight, kit.floorHeight)
    }
}

/// The stairs half of FR-SNAKE-010: a way between floors is something the snake can
/// traverse (FR-MAP-010), not only something the bots path along — a flight on the
/// shipped map (FR-MAP-150), and the way straight up a `transition` line still makes
/// (Q-330), kept working for the tower that may want it.
///
/// verifies: FR-SNAKE-010, FR-MAP-010
final class SnakeClimbTests: XCTestCase {
    private var kit: Kit!
    private var tuning: TuningConfiguration!

    override func setUpWithError() throws {
        try super.setUpWithError()
        kit = try Kit.load(named: "blockout", from: .main)
        tuning = try Launch.world().get().configurations.tuning
    }

    private let cell = 0.5

    /// Three cells in a row on the ground floor, the last of them a stair that a
    /// transition links to the same cell one floor up.
    private func stairs() throws -> Surfaces {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\ntransition 2,0 0 1\nfloor 0\n../\nfloor 1\n  /\n", kit: kit)
        return Surfaces(graph: NavigationGraph.derive(from: map, stepHeight: ShippedTuning.stepHeight), kit: kit, tuning: tuning, map: map)
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
        // Up to the moment the head is at the top: once there, it goes on along the
        // balcony and draws the tail up after it.
        for _ in 0..<120 where body.head.y < kit.floorHeight - 1e-9 {
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
        // FR-MAP-010 asks that the floors be joined by a way the snake can traverse;
        // on the blockout it is the flight (FR-MAP-150). Steered from where a match
        // begins: down the west side to the flight's row, then east up it.
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        let size = world.configurations.tuning.navigationGraphCellSize
        let surfaces = Surfaces(graph: world.graph, kit: world.kit, tuning: world.configurations.tuning, map: world.map)
        var body = Game(world: world, start: start).snake
        let foot = try XCTUnwrap(world.map.placements.first { $0.step?.index == 1 })

        func steer(_ direction: SIMD2<Double>, until reached: (Snake) -> Bool) {
            for _ in 0..<2000 where !reached(body) {
                body.advance(direction: direction, speed: world.configurations.snake.baseSpeed,
                             seconds: 1.0 / 60, over: surfaces)
            }
        }
        steer(SIMD2(0, 1)) { Int(($0.head.z / size).rounded()) >= foot.z }
        steer(SIMD2(1, 0)) { $0.floor == 1 && abs($0.head.y - world.kit.floorHeight) < 1e-9 }

        XCTAssertEqual(body.floor, 1, "the balcony cannot be reached from the start")
        XCTAssertEqual(body.head.y, world.kit.floorHeight, accuracy: 1e-9)
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
        let wall = NavigationGraph.Node(floor: 1, x: 18, z: 18)
        let beside = NavigationGraph.Node(floor: 1, x: 19, z: 18)
        XCTAssertFalse(world.graph.isWalkable(wall), "the map changed: (18,18) is no longer a wall")
        XCTAssertTrue(world.graph.isWalkable(NavigationGraph.Node(floor: 0, x: 18, z: 18)),
                      "the map changed: there is no floor under that wall")

        // Clear of the wall to begin with: at the cell's centre the body, 0.6 m wide, is
        // already 5 cm into it, and a body is kept from going deeper than it starts, not
        // put out.
        let clear = size / 2 + world.configurations.tuning.bodyRadius
        var body = Snake(head: SIMD3(Double(wall.x) * size + clear + 0.01, world.kit.floorHeight,
                                     Double(beside.z) * size),
                         floor: 1, segments: 4, segmentSpacing: 0.6)
        XCTAssertTrue(surfaces.fits(body.head, floor: 1), "the body begins in the wall, so this proves nothing")
        // Held squarely into it, the head goes round it (FR-SNAKE-015), round its end and
        // on, or off the balcony's open side; through it it never goes: up on the balcony
        // its body never comes into the wall's cell.
        for _ in 0..<60 {
            body.advance(direction: SIMD2(-1, 0), speed: 3.0, seconds: 1.0 / 60, over: surfaces)
            guard body.floor == 1, body.drop == nil else { continue }
            XCTAssertTrue(surfaces.fits(body.head, floor: 1), "the head went into the balcony's wall")
        }

        // And the way down is the flight it came up: this balcony is walled on the two
        // sides that face the room and ends at the map's edge on the others, so with
        // the wall holding, a flight that only went up would make it a trap.
        let top = try XCTUnwrap(world.map.placements.first { $0.step.map { $0.index == $0.count } ?? false })
        var leaving = Snake(head: SIMD3(Double(top.x + 2) * size, world.kit.floorHeight, Double(top.z) * size),
                            floor: 1, segments: 4, segmentSpacing: 0.6)
        for _ in 0..<240 {
            leaving.advance(direction: SIMD2(-1, 0), speed: 3.0, seconds: 1.0 / 60, over: surfaces)
        }
        XCTAssertEqual(leaving.floor, 0, "the balcony is a trap: the flight does not go down")
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
