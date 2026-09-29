// The lunge at what the snake would eat (FR-SNAKE-270): held through its wind-up, then
// sent at the prey by the snake's own movement rules for no longer than its reach takes,
// ending in a meal where it reaches the prey and nowhere where it does not. And how it
// is drawn (FR-VIEW-310). Geometry is compared within a tolerance, never for equality
// (`specs/50-verification.md`).
//
// verifies: FR-SNAKE-270, FR-SNAKE-280, FR-VIEW-310, FR-VIEW-160
import XCTest
@testable import CrawlCall

final class LungeTests: XCTestCase {
    private var shipped: World!
    private var lunge: SnakeConfiguration.Lunge { shipped.configurations.snake.lunge }
    private var tuning: TuningConfiguration { shipped.configurations.tuning }
    private let frame = 1.0 / 60

    override func setUpWithError() throws {
        try super.setUpWithError()
        shipped = try Launch.world().get()
    }

    private func surfaces(_ rows: String...) throws -> Surfaces {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        return Surfaces(graph: NavigationGraph.derive(from: map, stepHeight: tuning.stepHeight),
                        kit: shipped.kit, tuning: tuning, map: map)
    }

    private func snake(at x: Double, _ z: Double) -> Snake {
        Snake(head: SIMD3(x, 0, z), floor: 0, segments: 4, segmentSpacing: tuning.bodyRadius * 2)
    }

    /// Frames of a lunge at a prey that stands at `prey`, or moves by `run` every frame,
    /// until it is no longer under way; the result, and where the head went each frame.
    private func run(_ snake: inout Snake, at prey: SIMD3<Double>, moving run: SIMD3<Double> = .zero,
                     over surfaces: Surfaces) -> (result: Lunge.Result, heads: [SIMD3<Double>], prey: SIMD3<Double>) {
        var current = Lunge(prey: 1, configuration: lunge)
        var there = prey
        var heads: [SIMD3<Double>] = []
        for _ in 0..<600 {
            there += run
            let result = Lunge.step(&current, snake: &snake, prey: there, seconds: frame,
                                    bite: Game.biteReach(tuning), over: surfaces)
            heads.append(snake.head)
            if result != .going { return (result, heads, there) }
        }
        return (.going, heads, there)
    }

    // MARK: the lunge's own clock

    func testTheShippedLungeIsTheMaintainersThreeCells() {
        XCTAssertEqual(lunge.reach, 1.5, accuracy: 1e-9)
        XCTAssertGreaterThan(lunge.windUp, 0)
        XCTAssertGreaterThan(lunge.speed, shipped.configurations.snake.baseSpeed, "a lunge slower than a crawl")
    }

    func testTheWindUpIsSpentBeforeTheHeadTravels() {
        var current = Lunge(prey: 1, configuration: lunge)
        XCTAssertTrue(current.isWindingUp)
        let waiting = current.advance(seconds: lunge.windUp / 2)
        XCTAssertEqual(waiting.seconds, 0, accuracy: 1e-12, "the head travelled in the wind-up")
        XCTAssertEqual(waiting.metres, 0, accuracy: 1e-12)
        XCTAssertTrue(current.isWindingUp)
        // A frame that runs past the wind-up's end travels only for what is left of it.
        XCTAssertEqual(current.advance(seconds: lunge.windUp).seconds, lunge.windUp / 2, accuracy: 1e-12)
        XCTAssertFalse(current.isWindingUp)
    }

    func testALungeTravelsItsReachInTheTimeItsSpeedTakesAndEasesOutToAStop() throws {
        var current = Lunge(prey: 1, configuration: lunge)
        var steps: [(seconds: Double, metres: Double)] = []
        for _ in 0..<600 {
            let step = current.advance(seconds: frame)
            if step.seconds > 0 { steps.append(step) }
        }
        XCTAssertEqual(steps.map(\.seconds).reduce(0, +), lunge.reach / lunge.speed, accuracy: 1e-9)
        XCTAssertEqual(steps.map(\.metres).reduce(0, +), lunge.reach, accuracy: 1e-9)
        XCTAssertTrue(current.isSpent)
        // Fastest as it sets off, slowing every frame, and all but stopped as it ends.
        let speeds = steps.map { $0.metres / $0.seconds }
        for (earlier, later) in zip(speeds, speeds.dropFirst()) { XCTAssertGreaterThan(earlier, later) }
        XCTAssertGreaterThan(try XCTUnwrap(speeds.first), lunge.speed, "it set off no faster than its average")
        XCTAssertLessThan(try XCTUnwrap(speeds.last), lunge.speed * 0.3, "it stopped at full tilt")
    }

    func testTheWayToThePreyIsLevelAndOfUnitLength() {
        let way = Lunge.direction(from: SIMD3(1, 0, 1), to: SIMD3(4, 2, 5))
        XCTAssertEqual(way.x, 0.6, accuracy: 1e-9)
        XCTAssertEqual(way.y, 0.8, accuracy: 1e-9)
        XCTAssertEqual(Lunge.direction(from: SIMD3(1, 0, 1), to: SIMD3(1, 3, 1)), .zero)
    }

    // MARK: the lunge on the ground

    func testALungeAtAPreyStandingWithinReachEndsInTheMeal() throws {
        let floor = try surfaces("............", "............", "............")
        var snake = self.snake(at: 0.5, 0.5)
        let prey = SIMD3(0.5 + lunge.reach * 0.9, 0, 0.5)
        let (result, heads, _) = run(&snake, at: prey, over: floor)
        XCTAssertEqual(result, .reached)
        XCTAssertLessThanOrEqual(Perception.metres(snake.head, prey), Game.biteReach(tuning) + 1e-9)
        // The head stood still through the wind-up: every frame of it but the one it ends in.
        let held = Int((lunge.windUp / frame).rounded(.down))
        for head in heads.prefix(held - 1) {
            XCTAssertEqual(head.x, 0.5, accuracy: 1e-9, "the head moved in the wind-up")
            XCTAssertEqual(head.z, 0.5, accuracy: 1e-9)
        }
        // And it went at the lunge speed, not the crawl's.
        let last = try XCTUnwrap(heads.last)
        XCTAssertGreaterThan(last.x - 0.5, shipped.configurations.snake.baseSpeed * Double(heads.count - held) * frame)
    }

    func testAPreyThatRunsOutOfReachIsMissedAndTheHeadStopsWhereItGot() throws {
        let floor = try surfaces("........................", "........................", "........................")
        var snake = self.snake(at: 0.5, 0.5)
        // Running away faster than the head closes in over the lunge's time.
        let (result, heads, _) = run(&snake, at: SIMD3(0.5 + lunge.reach * 0.9, 0, 0.5),
                                     moving: SIMD3(8 * frame, 0, 0), over: floor)
        XCTAssertEqual(result, .missed)
        XCTAssertLessThanOrEqual(snake.head.x - 0.5, lunge.reach + 1e-9, "the head went further than the reach")
        XCTAssertEqual(Double(heads.count) * frame, lunge.windUp + lunge.reach / lunge.speed, accuracy: frame * 1.5)
    }

    func testAWallBetweenStopsTheHeadAndTheLungeMisses() throws {
        // A wall across the whole room between the head and the prey: the head goes by
        // the snake's own rules, so it stops at the wall (FR-SNAKE-010).
        let room = try surfaces("...#....", "...#....", "...#....")
        var snake = self.snake(at: 0.5, 0.5)
        let prey = SIMD3(2.0, 0, 0.5)
        XCTAssertLessThanOrEqual(Perception.metres(snake.head, prey), lunge.reach)
        let (result, _, _) = run(&snake, at: prey, over: room)
        XCTAssertEqual(result, .missed)
        XCTAssertLessThan(snake.head.x, 1.25, "the head went through the wall")
    }

    func testALungeOffALedgeEndsInTheAirWithNothing() throws {
        // The head goes by the snake's own rules, and those take it off an edge; nothing
        // is eaten in the air (FR-SNAKE-220), so the lunge ends there.
        let ledge = try surfaces("..........", "floor 1", ".         ")
        var snake = Snake(head: SIMD3(0, shipped.kit.floorHeight, 0), floor: 1, segments: 4,
                          segmentSpacing: tuning.bodyRadius * 2)
        let (result, _, _) = run(&snake, at: SIMD3(1.2, 0, 0), over: ledge)
        XCTAssertEqual(result, .missed)
        XCTAssertNotNil(snake.drop, "the lunge did not end where the head went over the edge")
    }

    // MARK: the eat intent in a match

    func testTheEatIntentWithNobodyWithinReachLungesAtNothing() throws {
        var game = Game(world: shipped, start: try XCTUnwrap(Game.firstStart(in: shipped)))
        XCTAssertFalse(game.canLunge, "the squads spawn beyond the lunge's reach")
        game.apply(.eat)
        XCTAssertNil(game.lunge)
        XCTAssertNil(game.eating)
    }

    func testTheNearestBotWithinTheLungesReachIsTheOneLungedAt() throws {
        let head = SIMD3<Double>(5, 0, 5)
        func bot(_ id: Int, at offset: Double) throws -> Bot {
            try XCTUnwrap(Bot(id: id, squad: .red, archetype: .assault, at: head + SIMD3(offset, 0, 0), floor: 0,
                              configuration: shipped.configurations.bot))
        }
        let near = try bot(1, at: lunge.reach * 0.5)
        let far = try bot(2, at: lunge.reach * 0.95)
        let beyond = try bot(3, at: lunge.reach * 1.2)
        XCTAssertEqual(Game.preyWithinReach(of: head, among: [beyond, far, near], reach: lunge.reach), near.id)
        XCTAssertEqual(Game.preyWithinReach(of: head, among: [beyond, far], reach: lunge.reach), far.id)
        XCTAssertNil(Game.preyWithinReach(of: head, among: [beyond], reach: lunge.reach))
    }

    func testInAMatchTheHeadIsHeldThenTheLungeEndsAndTheStickIsNotHeardMeanwhile() throws {
        let world = try Launch.world(map: "room").get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        var game = Game(world: world, start: start)
        try walk(&game, toLungeRangeIn: world, from: start)
        XCTAssertTrue(game.canLunge)

        game.apply(.eat)
        let lunged = try XCTUnwrap(game.lunge)
        XCTAssertFalse(game.canLunge, "a second lunge was on offer during the first")
        // Pushing the stick the other way through the wind-up does not move the head.
        game.apply(.move(direction: SIMD2(-1, 0)))
        let stood = game.snake.head
        let held = Int((world.configurations.snake.lunge.windUp / frame).rounded(.down))
        for _ in 0..<(held - 1) { game.advance(seconds: frame) }
        XCTAssertEqual(Perception.metres(game.snake.head, stood), 0, accuracy: 1e-9)

        for _ in 0..<60 where game.lunge != nil { game.advance(seconds: frame) }
        XCTAssertNil(game.lunge, "the lunge outlasted its time")
        XCTAssertNotNil(game.landedAt)
        // A living bot reached is coiled round first, and then eaten (FR-SNAKE-280).
        if let coiled = game.coil {
            XCTAssertEqual(coiled.prey, lunged.prey, "the coil is round another bot")
            XCTAssertNil(game.eating, "the meal began before the coil was done")
            for _ in 0..<120 where game.coil != nil { game.advance(seconds: frame) }
            XCTAssertNil(game.coil, "the coil outlasted its time")
        }
        if let meal = game.eating { XCTAssertEqual(meal.prey, lunged.prey, "the meal is of another bot") }
    }

    /// Steers the head along the graph to the first bot on floor 0 until one is within
    /// the lunge's reach.
    private func walk(_ game: inout Game, toLungeRangeIn world: World, from start: NavigationGraph.Node) throws {
        let cell = world.configurations.tuning.navigationGraphCellSize
        let prey = try XCTUnwrap(game.bots.filter { $0.floor == 0 }.first)
        var route = Route.between(start,
                                  NavigationGraph.Node(floor: 0, x: Int((prey.position.x / cell).rounded()),
                                                       z: Int((prey.position.z / cell).rounded())),
                                  in: world.graph)
        for _ in 0..<1800 where !game.canLunge {
            if let next = route.first {
                let head = game.snake.head
                let toward = SIMD2(Double(next.x) * cell - head.x, Double(next.z) * cell - head.z)
                let length = (toward * toward).sum().squareRoot()
                if length < 0.1 { route.removeFirst() }
                game.apply(.move(direction: length > 0 ? toward / length : .zero))
            }
            game.advance(seconds: frame)
        }
    }

    // MARK: how it is drawn (FR-VIEW-310)

    func testTheHeadSquashesThroughTheWindUpStretchesAsItGoesAndSquashesWhereItStops() {
        let prey = SIMD3<Double>(2, 0, 0)
        var current = Lunge(prey: 1, configuration: lunge)
        let rest = LungePose.of(lunge: current, windUp: lunge.windUp, prey: prey, sinceLanding: nil)
        XCTAssertEqual(rest.along, 1, accuracy: 1e-9, "squashed before the wind-up began")
        XCTAssertEqual(rest.aim, prey, "the head does not turn to its prey")

        _ = current.advance(seconds: lunge.windUp * 0.9)
        let wound = LungePose.of(lunge: current, windUp: lunge.windUp, prey: prey, sinceLanding: nil)
        XCTAssertLessThan(wound.along, 1)
        XCTAssertGreaterThan(wound.across, 1)

        _ = current.advance(seconds: lunge.windUp)
        let going = LungePose.of(lunge: current, windUp: lunge.windUp, prey: prey, sinceLanding: nil)
        XCTAssertGreaterThan(going.along, 1)
        XCTAssertLessThan(going.across, 1)

        let landed = LungePose.of(lunge: nil, windUp: lunge.windUp, prey: nil, sinceLanding: 0)
        XCTAssertLessThan(landed.along, 1)
        XCTAssertGreaterThan(landed.across, 1)
        XCTAssertNil(landed.aim)
        let over = LungePose.of(lunge: nil, windUp: lunge.windUp, prey: nil, sinceLanding: LungeLook.landingSeconds)
        XCTAssertEqual(over, LungePose(), "the squash outlasted its moment")
        XCTAssertEqual(LungePose.of(lunge: nil, windUp: lunge.windUp, prey: nil, sinceLanding: nil), LungePose())
    }
}
