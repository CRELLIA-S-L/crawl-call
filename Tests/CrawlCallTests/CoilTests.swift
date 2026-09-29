// The coil round a living bot before the meal (FR-SNAKE-280): the head goes once round
// the bot and the body lies round it, the bot shoved out of a corner to where the ring
// fits, at no more than the shove speed. Geometry is compared within a tolerance, never
// for equality (`specs/50-verification.md`).
//
// verifies: FR-SNAKE-280
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
}
