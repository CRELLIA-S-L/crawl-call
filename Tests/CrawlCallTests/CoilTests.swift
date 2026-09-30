// The coil round a living bot before the meal (FR-SNAKE-280): the head goes once round
// the bot and the body lies round it, the bot shoved out of a corner to where the ring
// fits, at no more than the shove speed. Geometry is compared within a tolerance, never
// for equality (`specs/50-verification.md`).
//
// verifies: FR-SNAKE-280, FR-SNAKE-285
import XCTest
@testable import CrawlCall

final class CoilTests: XCTestCase {
    private var shipped: World!
    private var coil: SnakeConfiguration.Coil { shipped.configurations.snake.coil }
    private var tuning: TuningConfiguration { shipped.configurations.tuning }
    private var radius: Double { tuning.bodyRadius * 2 }
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

    private func level(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = SIMD2(a.x - b.x, a.z - b.z)
        return (d * d).sum().squareRoot()
    }

    private func ringFits(round centre: SIMD3<Double>, over s: Surfaces) -> Bool {
        (0..<32).allSatisfy { k in
            let angle = Double(k) / 32 * 2 * .pi
            let point = centre + SIMD3(cos(angle), 0, sin(angle)) * radius
            return s.graph.isWalkable(s.cell(of: point, floor: 0)) && s.fits(point, floor: 0)
        }
    }

    // MARK: room for the ring

    func testInTheOpenTheBotIsCoiledRoundWhereItStands() throws {
        let open = try surfaces("..........", "..........", "..........", "..........", "..........")
        let prey = SIMD3(2.5, 0, 1.0)
        let room = Coil.room(around: prey, floor: 0, radius: radius, reach: coil.shoveReach, over: open)
        XCTAssertEqual(level(room, prey), 0, accuracy: 1e-9)
    }

    func testByAWallTheBotIsShovedOutToTheNearestPlaceTheRingFits() throws {
        let room = try surfaces("#.........", "#.........", "#.........", "#.........", "#.........")
        let prey = SIMD3(0.5, 0, 1.0)
        XCTAssertFalse(ringFits(round: prey, over: room), "the fixture's wall does not stand in the way")
        let place = Coil.room(around: prey, floor: 0, radius: radius, reach: coil.shoveReach, over: room)
        XCTAssertGreaterThan(level(place, prey), 0.1, "the bot was not shoved")
        XCTAssertLessThanOrEqual(level(place, prey), coil.shoveReach + 1e-9, "shoved further than the reach")
        XCTAssertTrue(ringFits(round: place, over: room), "the ring does not fit where the bot was shoved")
        XCTAssertGreaterThan(place.x, prey.x, "shoved into the wall rather than away from it")
    }

    func testWhereNoRingFitsWithinReachTheBotStaysWhereItIs() throws {
        let cramped = try surfaces("..", "..")
        let prey = SIMD3(0.25, 0, 0.25)
        let place = Coil.room(around: prey, floor: 0, radius: radius, reach: coil.shoveReach, over: cramped)
        XCTAssertEqual(level(place, prey), 0, accuracy: 1e-9)
    }

    // MARK: going round

    func testTheHeadGoesOnceRoundTheBotAndTheBodyLiesRoundIt() throws {
        let open = try surfaces("..........", "..........", "..........", "..........", "..........")
        var prey = SIMD3(2.5, 0, 1.0)
        let head = prey + SIMD3(-0.5, 0, 0)
        var snake = Snake(head: head, floor: 0, segments: shipped.configurations.snake.startingSegmentCount,
                          segmentSpacing: tuning.bodyRadius * 2)
        var current = Coil(prey: 1, at: prey, head: head, radius: radius, room: prey, configuration: coil)
        var turned = 0.0
        var last = atan2(snake.head.z - prey.z, snake.head.x - prey.x)
        var frames = 0
        while !current.isDone && frames < 600 {
            Coil.step(&current, snake: &snake, prey: &prey, seconds: frame, shoveSpeed: coil.shoveSpeed, over: open)
            let now = atan2(snake.head.z - prey.z, snake.head.x - prey.x)
            turned += atan2(sin(now - last), cos(now - last))
            last = now
            frames += 1
            if frames > 3 {
                XCTAssertEqual(level(snake.head, prey), radius, accuracy: 0.1, "the head strayed off the ring")
            }
        }
        XCTAssertTrue(current.isDone)
        XCTAssertEqual(Double(frames) * frame, coil.seconds, accuracy: frame * 1.5)
        XCTAssertEqual(abs(turned), 2 * .pi, accuracy: 0.3, "the head did not go once round")
        // The body followed the head round: the stretch of it behind the head lies on the ring.
        let behind = snake.tail.prefix(4)
        XCTAssertFalse(behind.isEmpty)
        for point in behind {
            XCTAssertEqual(level(point, prey), radius, accuracy: 0.15, "the body does not lie round the bot")
        }
    }

    func testTheBotIsShovedNoFasterThanTheShoveSpeedAndNoFurtherThanTheRoom() throws {
        let room = try surfaces("#.........", "#.........", "#.........", "#.........", "#.........")
        var prey = SIMD3(0.5, 0, 1.0)
        let place = Coil.room(around: prey, floor: 0, radius: radius, reach: coil.shoveReach, over: room)
        let head = prey + SIMD3(0.5, 0, 0)
        var snake = Snake(head: head, floor: 0, segments: 4, segmentSpacing: tuning.bodyRadius * 2)
        var current = Coil(prey: 1, at: prey, head: head, radius: radius, room: place, configuration: coil)
        while !current.isDone {
            let before = prey
            Coil.step(&current, snake: &snake, prey: &prey, seconds: frame, shoveSpeed: coil.shoveSpeed, over: room)
            XCTAssertLessThanOrEqual(level(prey, before), coil.shoveSpeed * frame + 1e-9, "shoved in a jump")
            XCTAssertLessThanOrEqual(level(place, prey), level(place, before) + 1e-9, "shoved away from the room")
        }
        XCTAssertLessThan(level(prey, SIMD3(0.5, 0, 1.0)), level(place, SIMD3(0.5, 0, 1.0)) + 1e-9)
        XCTAssertGreaterThan(level(prey, SIMD3(0.5, 0, 1.0)), 0, "the bot was never shoved")
    }

    // MARK: off a ledge (FR-SNAKE-285)

    func testACoilThatGoesOffAFlightTakesTheBotDownAndEndsWhereTheHeadLands() throws {
        // Found on the phone on 2026-09-30: a bot on a stair could not be eaten. A flight
        // one cell wide with the ground either side of it, the bot halfway up: the head
        // goes round it off the flight's side, and falls.
        let text = "kit blockout\nsetting greenholm\nfloor 0\n.............\n....>>>>>>>>.\n.............\n"
            + "floor 1\n             \n            .\n             \n"
        let map = try MapParser.parse(text, kit: shipped.kit)
        let over = Surfaces(graph: NavigationGraph.derive(from: map, stepHeight: tuning.stepHeight),
                            kit: shipped.kit, tuning: tuning, map: map)
        let cell = tuning.navigationGraphCellSize
        func onFlight(_ x: Int) -> SIMD3<Double> {
            let node = over.cell(of: SIMD3(Double(x) * cell, 0, cell), floor: 0)
            return SIMD3(Double(x) * cell, over.height(of: node), cell)
        }
        let stairTop = onFlight(9)
        XCTAssertGreaterThan(stairTop.y, 0.5, "the bot is not up the flight, so this proves nothing")
        var prey = try XCTUnwrap(Bot(id: 1, squad: .red, archetype: .assault, at: stairTop, floor: 0,
                                     configuration: shipped.configurations.bot))
        var snake = Snake(head: onFlight(7), floor: 0, segments: 4, segmentSpacing: radius)
        var current = Coil(prey: prey.id, at: prey.position, head: snake.head, radius: radius,
                           room: Coil.room(around: prey.position, floor: 0, radius: radius, reach: coil.shoveReach,
                                           over: over),
                           configuration: coil)
        var fell = false, done = false
        for _ in 0..<600 {
            done = Game.coil(&current, snake: &snake, prey: &prey, seconds: frame,
                              configuration: shipped.configurations.snake, over: over)
            fell = fell || snake.drop != nil
            if snake.drop != nil {
                XCTAssertEqual(Perception.metres(prey.position, snake.head), 0, accuracy: 1e-9,
                               "the bot was left behind as the head fell")
            }
            if done { break }
        }
        XCTAssertTrue(fell, "the head did not go off the flight, so this proves nothing")
        XCTAssertGreaterThan(snake.drops, 0, "a drop was not counted")
        XCTAssertTrue(done, "the coil never ended")
        XCTAssertNil(snake.drop, "the coil ended in the air, where no meal begins")
        XCTAssertEqual(Perception.metres(prey.position, snake.head), 0, accuracy: 1e-9, "the bot is not where the head landed")
        XCTAssertEqual(prey.floor, snake.floor)
        XCTAssertLessThan(snake.head.y, stairTop.y - 0.25, "the head did not come down")
    }
}
