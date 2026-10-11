// The head and what is in its way, as the snake turns on an arc (FR-SNAKE-290): an
// obstacle it is going into is slid along to the side the stick leans to (FR-SNAKE-015),
// and its own body past the neck is crawled over (FR-SNAKE-055). Found on the phone on
// 2026-09-30: a head in a corner pulled back folded the snake in two, through itself.
//
// file verifies: FR-SNAKE-015, FR-SNAKE-016, FR-SNAKE-055, FR-SNAKE-056
import XCTest
@testable import CrawlCall

final class OwnBodyTests: XCTestCase {
    private var shipped: World!
    private var snakeConfiguration: SnakeConfiguration { shipped.configurations.snake }
    private var tuning: TuningConfiguration { shipped.configurations.tuning }
    private let frame = 1.0 / 60

    override func setUpWithError() throws {
        try super.setUpWithError()
        shipped = try Launch.world().get()
    }

    private func surfaces(_ rows: [String]) throws -> Surfaces {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        return Surfaces(graph: NavigationGraph.derive(from: map, stepHeight: tuning.stepHeight),
                        kit: shipped.kit, tuning: tuning, map: map)
    }

    private func crawl(_ snake: inout Snake, _ direction: SIMD2<Double>, frames: Int, over floor: Surfaces,
                       neck: Int? = nil) {
        let length = (direction * direction).sum().squareRoot()
        for _ in 0..<frames {
            snake.advance(direction: direction / length, speed: snakeConfiguration.baseSpeed, seconds: frame,
                          over: floor, turningRadius: snakeConfiguration.turningRadius, neck: neck)
        }
    }

    // MARK: to the side the stick leans to (FR-SNAKE-015)

    /// A snake crawled north along the east wall of a room, up against it.
    private func alongTheEastWall() throws -> (Snake, Surfaces) {
        let floor = try surfaces(Array(repeating: "..........#", count: 24))
        var snake = Snake(head: SIMD3(4.6, 0, 10), floor: 0, segments: 6, segmentSpacing: tuning.bodyRadius * 2)
        crawl(&snake, SIMD2(0, -1), frames: 60, over: floor)
        crawl(&snake, SIMD2(1, -1), frames: 30, over: floor)
        return (snake, floor)
    }

    /// A snake crawling south-east towards the east wall of a room, a frame or two short
    /// of it: at the wall it is still going south-east, whatever it is steered to after.
    private func towardsTheEastWall(_ row: String = "..........#", frames: Int = 20) throws -> (Snake, Surfaces) {
        let floor = try surfaces(Array(repeating: row, count: 24))
        var snake = Snake(head: SIMD3(3.4, 0, 6), floor: 0, segments: 6, segmentSpacing: tuning.bodyRadius * 2)
        crawl(&snake, SIMD2(1, 0.3), frames: frames, over: floor)
        return (snake, floor)
    }

    func testAHeadGoingIntoAWallSlidesToTheSideTheStickLeansTo() throws {
        var (snake, floor) = try towardsTheEastWall()
        let start = snake.head
        XCTAssertGreaterThan(try XCTUnwrap(snake.heading).x, 0.9, "the head was not going into the wall, so this proves nothing")
        // Into the wall going south-east, and the stick leaning north-east: at the wall it
        // slides north, the way the stick leans, and not south, the way the head was going.
        // A stick leaning back behind the head would be a turn back, which goes round on the
        // arc (FR-SNAKE-290).
        crawl(&snake, SIMD2(1, -0.5), frames: 10, over: floor)
        XCTAssertLessThan(snake.head.z, start.z - 0.05, "the head went on the way it was going, not the way the stick leans")
        XCTAssertGreaterThan(snake.head.x, start.x + 0.05, "the head never reached the wall, so this proves nothing")
    }

    func testAlongTheEdgeOfTheGroundTheHeadSlidesToTheSideTheStickLeansTo() throws {
        // The edge of the ground, with nothing below to drop to, is a side of a cell the
        // graph refuses rather than a face (FR-SNAKE-220): the same rule holds along it.
        var (snake, floor) = try towardsTheEastWall("..........     ", frames: 27)
        let start = snake.head
        XCTAssertGreaterThan(try XCTUnwrap(snake.heading).x, 0.9, "the head was not going into the edge, so this proves nothing")
        crawl(&snake, SIMD2(1, -0.5), frames: 10, over: floor)
        XCTAssertLessThan(snake.head.z, start.z - 0.05, "the head went on the way it was going, not the way the stick leans")
        XCTAssertGreaterThan(snake.head.x, start.x + 0.05, "the head never reached the edge, so this proves nothing")
        XCTAssertNil(snake.drop, "the head went off the edge")
    }

    func testAHeadPushedSquarelyIntoAWallGoesRoundItAtItsSpeed() throws {
        // Leaning to neither side it takes the roomier, or where both are open the one
        // nearer the way it was going — north, along the wall — at the whole of its speed.
        var (snake, floor) = try alongTheEastWall()
        let start = snake.head
        crawl(&snake, SIMD2(1, 0), frames: 10, over: floor)
        XCTAssertEqual(snake.head.x, start.x, accuracy: 0.02, "the head left the wall")
        XCTAssertEqual(start.z - snake.head.z, snakeConfiguration.baseSpeed * frame * 10, accuracy: 0.02,
                       "the head did not go on along the wall at its speed")
    }

    func testPushedStraightIntoACornerTheHeadStandsAndDoesNotRise() throws {
        // Found on the phone on 2026-09-30: held into a corner, between its two walls, the
        // head went from one wall to the other and back every frame, its body piled up on
        // the spot, and the snake rose into the air. Held there it stands, on the ground.
        let floor = try surfaces(["################"] + Array(repeating: "...............#", count: 8))
        var snake = Snake(head: SIMD3(4.0, 0, 2.5), floor: 0, segments: 8, segmentSpacing: tuning.bodyRadius * 2)
        let into = SIMD2(1.0, -1.0) / 2.0.squareRoot()
        func step() {
            crawl(&snake, into, frames: 1, over: floor, neck: snakeConfiguration.neckSegments)
            snake.settle(seconds: frame, neck: snakeConfiguration.neckSegments, gravity: tuning.dropGravity)
        }
        for _ in 0..<150 { step() }
        let wedged = snake.head
        for _ in 0..<240 {
            step()
            XCTAssertEqual(Perception.metres(snake.head, wedged), 0, accuracy: 1e-3, "the head is going back and forth in the corner")
            XCTAssertEqual(snake.lift, 0, accuracy: 1e-9, "the snake rose off the ground in the corner")
        }
    }

    func testGoingAlongAWallIntoACornerWithTheStickIntoTheWallTheHeadTurnsBack() throws {
        // Going north along the east wall, the stick held into that wall and leaning to
        // neither side, into the corner with the north wall: it cannot go on, and at rest
        // there it goes to the side with more room — back south along the wall — rather
        // than standing for good.
        let floor = try surfaces(["################"] + Array(repeating: "...............#", count: 12))
        var snake = Snake(head: SIMD3(6.95, 0, 5.0), floor: 0, segments: 6, segmentSpacing: tuning.bodyRadius * 2)
        crawl(&snake, SIMD2(0, -1), frames: 30, over: floor, neck: snakeConfiguration.neckSegments)
        let into = SIMD2(1.0, 0.02)
        for _ in 0..<90 { crawl(&snake, into, frames: 1, over: floor, neck: snakeConfiguration.neckSegments) }
        XCTAssertGreaterThan(snake.head.z, 1.2, "the head stands in the corner for good")
    }

    func testAlongTheEdgeOfTheGroundATremblingStickDoesNotTurnTheHeadBackAndForth() throws {
        // The stick held square into the ground's edge, a thumb trembling a degree to either
        // side every frame: the head goes on along the edge the way it was going.
        let floor = try surfaces(Array(repeating: "..........     ", count: 24))
        var snake = Snake(head: SIMD3(4.6, 0, 10), floor: 0, segments: 6, segmentSpacing: tuning.bodyRadius * 2)
        crawl(&snake, SIMD2(0, -1), frames: 60, over: floor)
        crawl(&snake, SIMD2(1, -1), frames: 30, over: floor)
        var last = snake.head.z
        for frame in 0..<60 {
            let tremble = frame.isMultiple(of: 2) ? 0.017 : -0.017
            crawl(&snake, SIMD2(1, tremble), frames: 1, over: floor)
            XCTAssertLessThanOrEqual(snake.head.z, last + 1e-9, "the head turned back along the edge")
            last = snake.head.z
        }
        XCTAssertNil(snake.drop, "the head went off the edge")
    }

    func testInADeadEndTheHeadDoesNotGoBack() throws {
        // A corridor one cell wide, a partition across it: pushed into the partition the
        // head has nowhere to go round, and stands; it does not turn back against the stick.
        let floor = try surfaces([".", ".", "=", "."])
        var snake = Snake(head: .zero, floor: 0, segments: 4, segmentSpacing: tuning.bodyRadius * 2)
        var furthest = 0.0
        for _ in 0..<60 {
            crawl(&snake, SIMD2(0, 1), frames: 1, over: floor)
            XCTAssertGreaterThanOrEqual(snake.head.z, furthest - 1e-9, "the head went back against the stick")
            furthest = max(furthest, snake.head.z)
        }
    }

    // MARK: feeling ahead (FR-SNAKE-016)

    /// The frame the head gets past a crate — its middle east of the crate's far side and
    /// the body clear of it — steered all along at a point past the crate whose line
    /// grazes it: `past` metres north of the crate's middle. Nil where it never does.
    private func framesToPassACrate(feel: Double?, past: Double) throws -> Int? {
        let floor = try surfaces(Array(repeating: "................", count: 5) + ["..........o....."]
                                 + Array(repeating: "................", count: 5))
        var snake = Snake(head: SIMD3(1.0, 0, 2.5), floor: 0, segments: 6, segmentSpacing: tuning.bodyRadius * 2)
        let target = SIMD2(7.5, 2.5 - past)
        for frame in 0..<300 {
            let to = target - SIMD2(snake.head.x, snake.head.z)
            let length = (to * to).sum().squareRoot()
            guard length > 0.2 else { return nil }
            snake.advance(direction: to / length, speed: snakeConfiguration.baseSpeed, seconds: self.frame, over: floor,
                          turningRadius: snakeConfiguration.turningRadius, feel: feel)
            if snake.head.x > 5.25 + tuning.bodyRadius { return frame }
        }
        return nil
    }

    func testAimedAtAPointBehindACrateTheHeadGetsPastItWhereverTheLineRuns() throws {
        // Found on the phone on 2026-09-30: the snake ran its nose into things and stayed
        // there. Aimed straight through a crate or just past its side, the head goes round
        // it and on, in about the time the way round takes at its speed.
        for past in stride(from: 0.0, through: 1.0, by: 0.1) {
            let frames = try XCTUnwrap(try framesToPassACrate(feel: snakeConfiguration.feelDistance, past: past),
                                       "aimed \(past) m past the crate's middle, the head never got past it")
            XCTAssertLessThan(frames, 120, "aimed \(past) m past the crate's middle, the head was held up at it")
        }
    }

    func testFeelingAheadTheHeadTurnsBeforeItTouches() throws {
        // Aimed just past the crate's side, a head that feels it half a metre ahead turns
        // off along it early and is past sooner than one that turns only on touching it.
        for past in [0.1, 0.2, 0.3, 0.4] {
            let feeling = try XCTUnwrap(try framesToPassACrate(feel: snakeConfiguration.feelDistance, past: past))
            let blind = try XCTUnwrap(try framesToPassACrate(feel: nil, past: past))
            XCTAssertLessThan(feeling, blind, "aimed \(past) m past, feeling ahead gained nothing")
        }
    }

    func testTheShippedFeelIsTheMaintainersHalfMetre() {
        XCTAssertEqual(snakeConfiguration.feelDistance, 0.5, accuracy: 1e-9)
    }

    // MARK: over its own body (FR-SNAKE-055)

    /// The nearest the head's centre comes, in three dimensions, to the line through its
    /// body past the neck and one segment more — past the bend the neck makes as the head
    /// turns — and, where the two are within a body's width level, how high the head
    /// rides.
    private func nearestToOwnBody(_ snake: Snake) -> Double {
        let body = Array(snake.tail.dropFirst(snakeConfiguration.neckSegments + 1))
        return zip(body, body.dropFirst()).map { Flight.nearest(snake.drawnHead, $0, $1) }.min() ?? .infinity
    }

    func testPulledBackOutOfACornerTheHeadGoesOverItsBodyNotThroughIt() throws {
        // Two bodies side by side touch where their centre lines are a body's width apart.
        // Folded, the head lies half across its body at the ground; crawled over, it rides
        // up onto it, and its centre never comes nearer the body's than that width. The
        // body drawn on after the head comes in a few centimetres as it follows.
        let width = tuning.bodyRadius * 2
        let floor = try surfaces(["################"] + Array(repeating: "...............#", count: 8))
        var snake = Snake(head: SIMD3(2.0, 0, 0.9), floor: 0, segments: 8, segmentSpacing: width)
        crawl(&snake, SIMD2(1, -0.15), frames: 300, over: floor, neck: snakeConfiguration.neckSegments)
        let start = snake.head
        var nearest = Double.infinity
        var highest = 0.0
        for _ in 0..<120 {
            crawl(&snake, SIMD2(-1, 0), frames: 1, over: floor, neck: snakeConfiguration.neckSegments)
            nearest = min(nearest, nearestToOwnBody(snake))
            highest = max(highest, snake.lift)
        }
        XCTAssertGreaterThan(highest, width / 2, "the head never rose onto its body, so this proves nothing")
        XCTAssertGreaterThan(nearest, width * 0.9, "the head went through its own body")
        XCTAssertGreaterThan(Perception.metres(snake.head, start), 1.0, "the head stood in the corner rather than turning out of it")
    }

    func testTheHeadCrossesItsBodyOverTheTopAndTheBodyFollowsItOver() throws {
        // Laid out with no turning radius: east three metres, south a metre, west a
        // metre; then steered north, straight across the body's east leg, a metre north.
        let width = tuning.bodyRadius * 2
        let floor = try surfaces(Array(repeating: "................", count: 16))
        var snake = Snake(head: SIMD3(1.0, 0, 3.0), floor: 0, segments: 12, segmentSpacing: width)
        func lay(_ direction: SIMD2<Double>, metres: Double) {
            snake.advance(direction: direction, speed: metres, seconds: 1, over: floor)
        }
        lay(SIMD2(1, 0), metres: 3)
        lay(SIMD2(0, 1), metres: 1)
        lay(SIMD2(-1, 0), metres: 1)
        var lifts: [(z: Double, lift: Double)] = []
        for _ in 0..<60 {
            let before = snake.head.z
            crawl(&snake, SIMD2(0, -1), frames: 1, over: floor, neck: snakeConfiguration.neckSegments)
            XCTAssertLessThan(snake.head.z, before - 1e-3, "the head was held up at its own body")
            lifts.append((snake.head.z, snake.lift))
        }
        // Right over the body's line it rides a body's width up, and on the ground again
        // well away from it either side.
        let over = try XCTUnwrap(lifts.min { abs($0.z - 3.0) < abs($1.z - 3.0) })
        XCTAssertEqual(over.lift, width, accuracy: 0.05, "the head is not resting on its body where it crosses it")
        for step in lifts where abs(step.z - 3.0) > width + 0.05 {
            XCTAssertEqual(step.lift, 0, accuracy: 1e-9, "the head rose where there is nothing under it")
        }
        // Going up and down by no more than the ground covered each frame allows: no step.
        for (a, b) in zip(lifts, lifts.dropFirst()) {
            XCTAssertLessThan(abs(b.lift - a.lift), abs(b.z - a.z) * 4 + 0.05, "the head jumped up or down")
        }
        // The body laid behind the head goes over too.
        XCTAssertGreaterThan(snake.tail.map(\.y).max() ?? 0, width / 2, "the body did not follow the head over")
    }

    func testATurnOnTheArcDoesNotClimbTheNeck() throws {
        // A full turn round at the turning radius in the open: the head passes within a
        // body's width of its neck, and of nothing past it.
        let floor = try surfaces(Array(repeating: "................", count: 16))
        var snake = Snake(head: SIMD3(1.0, 0, 4.0), floor: 0, segments: 8, segmentSpacing: tuning.bodyRadius * 2)
        crawl(&snake, SIMD2(1, 0), frames: 60, over: floor, neck: snakeConfiguration.neckSegments)
        var highest = 0.0
        for _ in 0..<90 {
            crawl(&snake, SIMD2(-1, 0), frames: 1, over: floor, neck: snakeConfiguration.neckSegments)
            highest = max(highest, snake.lift)
        }
        XCTAssertEqual(highest, 0, accuracy: 1e-9, "the head climbed its own neck turning round")
    }

    func testACoilDoesNotClimbTheBodyItLiesAgainst() throws {
        // The ring round a bot closes where the body already lies: a coil is not crawled
        // over (FR-SNAKE-280).
        let floor = try surfaces(Array(repeating: "..........", count: 10))
        let width = tuning.bodyRadius * 2
        var snake = Snake(head: SIMD3(1.0, 0, 2.5), floor: 0, segments: 8, segmentSpacing: width)
        crawl(&snake, SIMD2(1, 0), frames: 40, over: floor, neck: snakeConfiguration.neckSegments)
        var prey = try XCTUnwrap(Bot(id: 1, squad: .red, archetype: .assault, at: snake.head + SIMD3(width, 0, 0),
                                     floor: 0, configuration: shipped.configurations.bot))
        var current = Coil(prey: prey.id, at: prey.position, head: snake.head, radius: width, room: prey.position,
                           configuration: snakeConfiguration.coil)
        var highest = 0.0
        for _ in 0..<120 {
            let done = Game.coil(&current, snake: &snake, prey: &prey, seconds: frame,
                                 configuration: snakeConfiguration, over: floor)
            highest = max(highest, snake.lift)
            if done { break }
        }
        XCTAssertEqual(highest, 0, accuracy: 1e-9, "the head climbed its own body going round the bot")
    }

    func testAHeadThatStopsClimbingComesDownOverTheGroundItCovers() throws {
        // On top of its own body when a coil begins — a lunge that ended on it — the head
        // does not drop to the ground in one frame: a coil does not climb, and the head
        // comes down as it goes round.
        let width = tuning.bodyRadius * 2
        let floor = try surfaces(Array(repeating: "................", count: 16))
        var snake = Snake(head: SIMD3(1.0, 0, 3.0), floor: 0, segments: 12, segmentSpacing: width)
        snake.advance(direction: SIMD2(1, 0), speed: 3, seconds: 1, over: floor)
        snake.advance(direction: SIMD2(0, 1), speed: 1, seconds: 1, over: floor)
        snake.advance(direction: SIMD2(-1, 0), speed: 1, seconds: 1, over: floor)
        while snake.head.z > 3.0 {
            crawl(&snake, SIMD2(0, -1), frames: 1, over: floor, neck: snakeConfiguration.neckSegments)
        }
        XCTAssertGreaterThan(snake.lift, width * 0.8, "the head is not on its body, so this proves nothing")
        var prey = try XCTUnwrap(Bot(id: 1, squad: .red, archetype: .assault, at: snake.head + SIMD3(0, 0, -width),
                                     floor: 0, configuration: shipped.configurations.bot))
        var current = Coil(prey: prey.id, at: prey.position, head: snake.head, radius: width, room: prey.position,
                           configuration: snakeConfiguration.coil)
        for _ in 0..<60 {
            let before = (head: snake.head, lift: snake.lift)
            let done = Game.coil(&current, snake: &snake, prey: &prey, seconds: frame,
                                 configuration: snakeConfiguration, over: floor)
            let run = SIMD2(snake.head.x - before.head.x, snake.head.z - before.head.z)
            let covered = (run * run).sum().squareRoot()
            XCTAssertLessThanOrEqual(before.lift - snake.lift, covered * Motion.liftSlope + 1e-9,
                                     "the head dropped off its body faster than it went round")
            if done { break }
        }
        XCTAssertEqual(snake.lift, 0, accuracy: 1e-9, "the head never came down off its body going round")
    }

    // MARK: nothing hangs in the air (FR-SNAKE-056)

    func testAPartLyingOnTheBodyStaysWhileItIsThereAndComesDownOnceItIsGone() throws {
        // Laid with no turning radius: east three metres, south a metre, west a metre, then
        // north across the east leg, where the body goes over itself. The east leg under the
        // crossing is four metres of path older than the crossing; with twelve segments,
        // 7.2 m of tail, it is gone when the head has come 7.2 m on from it and the crossing
        // is still 3.2 m behind the head.
        let width = tuning.bodyRadius * 2
        let gravity = tuning.dropGravity
        let floor = try surfaces(Array(repeating: "........................", count: 24))
        var snake = Snake(head: SIMD3(1.0, 0, 6.0), floor: 0, segments: 12, segmentSpacing: width)
        func lay(_ direction: SIMD2<Double>, metres: Double) {
            snake.advance(direction: direction, speed: metres, seconds: 1, over: floor)
        }
        lay(SIMD2(1, 0), metres: 3)
        lay(SIMD2(0, 1), metres: 1)
        lay(SIMD2(-1, 0), metres: 1)
        func step(_ direction: SIMD2<Double>) {
            crawl(&snake, direction, frames: 1, over: floor, neck: snakeConfiguration.neckSegments)
            snake.settle(seconds: frame, neck: snakeConfiguration.neckSegments, gravity: gravity)
        }
        // Across the east leg and a little on.
        while snake.head.z > 5.4 { step(SIMD2(0, -1)) }
        let highest = { snake.trail.map(\.y).max() ?? 0 }
        XCTAssertGreaterThan(highest(), width * 0.9, "the body did not go over itself, so this proves nothing")
        // On north: the crossing still lies on the east leg for a while, and stays up.
        for _ in 0..<30 { step(SIMD2(0, -1)) }
        XCTAssertGreaterThan(highest(), width * 0.9, "a part came down while the body under it was still there")
        // On until the east leg under the crossing has been drawn off the ground behind.
        var frames = 0
        var fell = false
        var first: Double?
        while frames < 600 {
            let before = highest()
            step(SIMD2(0, -1))
            frames += 1
            if before - highest() > 1e-6, first == nil { first = before - highest() }
            if highest() < 1e-6 { fell = true; break }
        }
        XCTAssertTrue(fell, "the part that lay on the body stayed in the air once the body under it had gone")
        // Under gravity, from rest: the first frame's fall is g·t², no more, not a drop in one go.
        XCTAssertLessThanOrEqual(try XCTUnwrap(first), gravity * frame * frame + 1e-9, "it fell faster than gravity")
    }

    func testTheShippedNeckIsTheMaintainersTwoSegments() {
        XCTAssertEqual(snakeConfiguration.neckSegments, 2)
    }
}
