// A thrown grenade flies the arc of a thrown thing (FR-BOT-580), comes back off what it
// meets keeping a share of its speed (FR-BOT-590), is drawn where it is while its fuse
// burns (FR-VIEW-350), and leaves a blast on screen for a moment after it (FR-VIEW-360).
//
// file verifies: FR-BOT-580, FR-BOT-590, FR-VIEW-350, FR-VIEW-360
import RealityKit
import XCTest
@testable import CrawlCall

final class FlightOfAGrenadeTests: XCTestCase {
    private var shipped: World!
    private var world: World!
    private let frame = 1.0 / 60

    override func setUpWithError() throws {
        try super.setUpWithError()
        shipped = try Launch.world().get()
        world = try arena(Array(repeating: String(repeating: ".", count: 40), count: 5))
    }

    private func arena(_ rows: [String]) throws -> World {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        let cell = shipped.configurations.tuning.navigationGraphCellSize
        return World(configurations: shipped.configurations, kit: shipped.kit, map: map, setting: shipped.setting,
                     graph: NavigationGraph.derive(from: map, stepHeight: shipped.configurations.tuning.stepHeight),
                     plan: ScenePlan.make(map: map, kit: shipped.kit, cellSize: cell))
    }

    private var configuration: BotConfiguration { world.configurations.bot }
    private var gravity: Double { world.configurations.tuning.dropGravity }
    private var numbers: BotConfiguration.Grenade {
        get throws { try XCTUnwrap(configuration.weapons.grenades.values.first) }
    }

    private func thrown(from hand: SIMD3<Double>, at aim: SIMD3<Double>) throws -> Thrown {
        let grenade = try numbers
        return Thrown(thrower: 0, squad: .red, position: hand,
                      velocity: Blast.throwing(from: hand, at: aim, range: grenade.throwRange, gravity: gravity),
                      numbers: grenade, fuse: grenade.fuseTime)
    }

    /// The grenade flown frame by frame for `seconds`, and where it got to.
    private func fly(_ grenade: Thrown, for seconds: Double) -> [SIMD3<Double>] {
        var going = grenade
        var way: [SIMD3<Double>] = [going.position]
        for _ in Int.zero..<Int((seconds / frame).rounded()) {
            Blast.fly(&going, seconds: frame, gravity: gravity, plan: world.plan)
            way.append(going.position)
        }
        return way
    }

    // MARK: the arc (FR-BOT-580)

    func testAThrowLeavesTheHandAtHalfARightAngleAndTheSpeedThatLandsItThere() throws {
        // √(g·d) at forty-five degrees, which is the one place a sign error is invisible.
        let hand = SIMD3(1.0, 0.875, 1.0)
        let metres = 4.0
        let velocity = Blast.throwing(from: hand, at: hand + SIMD3(metres, .zero, .zero),
                                      range: try numbers.throwRange, gravity: gravity)
        let speed = (velocity * velocity).sum().squareRoot()
        XCTAssertEqual(speed, (gravity * metres).squareRoot(), accuracy: 1e-9)
        XCTAssertEqual(velocity.x, velocity.y, accuracy: 1e-9, "the throw is not at half a right angle")
        XCTAssertEqual(velocity.z, .zero, accuracy: 1e-12, "a throw straight down the x axis went sideways")
    }

    func testAGrenadeAimedBeyondItsRangeFallsShort() throws {
        let hand = SIMD3(1.0, 0.875, 1.0)
        let range = try numbers.throwRange
        let near = Blast.throwing(from: hand, at: hand + SIMD3(range, .zero, .zero), range: range, gravity: gravity)
        let far = Blast.throwing(from: hand, at: hand + SIMD3(range * 3, .zero, .zero), range: range, gravity: gravity)
        XCTAssertEqual((far * far).sum().squareRoot(), (near * near).sum().squareRoot(), accuracy: 1e-9,
                       "a throw aimed three times its range left the hand faster than one at its range")
    }

    func testAGrenadeRisesThenFallsAndEndsLowerThanItBegan() throws {
        let hand = SIMD3(2.0, 0.875, 1.0)
        let way = fly(try thrown(from: hand, at: SIMD3(6.0, .zero, 1.0)), for: try numbers.fuseTime)
        let highest = try XCTUnwrap(way.map(\.y).max())
        XCTAssertGreaterThan(highest, hand.y, "it never rose at all")
        let last = try XCTUnwrap(way.last)
        XCTAssertLessThan(last.y, hand.y, "it was no lower at the end of its fuse than in the hand")
        XCTAssertGreaterThan(last.x, hand.x, "it went nowhere along the ground")
    }

    func testAGrenadeComesDownNearWhatItWasThrownAt() throws {
        let hand = SIMD3(2.0, 0.875, 1.0)
        let aim = SIMD3(8.0, .zero, 1.0)
        let way = fly(try thrown(from: hand, at: aim), for: try numbers.fuseTime)
        let last = try XCTUnwrap(way.last)
        XCTAssertLessThan(Perception.metres(last, aim), try numbers.blastRadius,
                          "it went off further from where it was aimed than the blast is wide")
    }

    func testAGrenadeComesToRestAndStaysThere() throws {
        let hand = SIMD3(2.0, 0.875, 1.0)
        var going = try thrown(from: hand, at: SIMD3(5.0, .zero, 1.0))
        for _ in Int.zero..<Int((try numbers.fuseTime / frame).rounded()) {
            Blast.fly(&going, seconds: frame, gravity: gravity, plan: world.plan)
        }
        let settled = going.position
        for _ in Int.zero..<30 { Blast.fly(&going, seconds: frame, gravity: gravity, plan: world.plan) }
        XCTAssertEqual(Perception.metres(going.position, settled), .zero, accuracy: 1e-12,
                       "a grenade at rest went on moving")
        XCTAssertEqual(going.velocity, .zero)
    }

    // MARK: the bounce (FR-BOT-590)

    func testAGrenadeThrownAtAWallComesBackTowardsTheThrower() throws {
        // A wall of crates two metres east of the thrower, and the grenade thrown flat
        // into it: what comes back is what the bounce is.
        world = try arena([String(repeating: ".", count: 12),
                           "........oooo",
                           String(repeating: ".", count: 12)])
        let hand = SIMD3(1.0, 0.875, 0.5)
        var going = try thrown(from: hand, at: SIMD3(2.0, 0.875, 0.5))
        going.velocity = SIMD3(6.0, .zero, .zero)
        var furthest = hand.x
        for _ in Int.zero..<60 {
            Blast.fly(&going, seconds: frame, gravity: gravity, plan: world.plan)
            furthest = max(furthest, going.position.x)
        }
        XCTAssertGreaterThan(furthest, hand.x, "it never went east at all")
        XCTAssertLessThan(going.position.x, furthest, "it stopped dead at the wall instead of coming back")
    }

    func testTheBounceKeepsTheShareOfItsSpeedTheRestitutionSets() throws {
        // Straight down onto the floor, where the face is the one axis and the arithmetic
        // is readable: what comes back up is the restitution's share of what went down.
        var going = try thrown(from: SIMD3(2.0, 1.0, 1.0), at: SIMD3(3.0, .zero, 1.0))
        going.velocity = SIMD3(.zero, -4.0, .zero)
        var falling = going.velocity.y
        var bounced = false
        for _ in Int.zero..<30 where !bounced {
            let before = going.velocity.y
            Blast.fly(&going, seconds: frame, gravity: gravity, plan: world.plan)
            if going.velocity.y > .zero {
                bounced = true
                // What it was going at when it met the floor: the frame's fall is taken
                // before the step that meets it.
                falling = before - gravity * frame
            }
        }
        XCTAssertTrue(bounced, "it never came back off the floor")
        let keeps = try numbers.restitution
        XCTAssertEqual(going.velocity.y, -falling * keeps, accuracy: 1e-9,
                       "it came back at something other than the share of its speed it keeps")
        XCTAssertLessThan(going.velocity.y, -falling, "it came back faster than it fell")
    }

    func testAGrenadeThatMeetsNothingKeepsItsWay() throws {
        var going = try thrown(from: SIMD3(2.0, 3.0, 1.0), at: SIMD3(6.0, 3.0, 1.0))
        let before = going.velocity
        Blast.fly(&going, seconds: frame, gravity: gravity, plan: world.plan)
        XCTAssertEqual(going.velocity.x, before.x, accuracy: 1e-12, "it was turned by nothing at all")
        XCTAssertLessThan(going.velocity.y, before.y, "it did not fall")
    }

    // MARK: drawn where it is (FR-VIEW-350) and where it went off (FR-VIEW-360)

    @MainActor
    func testAGrenadeInTheAirIsDrawnWhereItIs() throws {
        let game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        let entity = BlastEntity.make(for: game.bots, configuration: configuration)
        let where_ = SIMD3(3.0, 1.25, 2.0)
        let grenade = try thrown(from: where_, at: SIMD3(6.0, .zero, 2.0))
        BlastEntity.update(entity, grenades: [grenade], blasts: [])
        let drawn = entity.children.filter { $0.isEnabled }
        XCTAssertEqual(drawn.count, 1, "one grenade in the air was drawn \(drawn.count) times")
        let ball = try XCTUnwrap(drawn.first)
        XCTAssertEqual(Double(ball.position.x), where_.x, accuracy: 1e-5)
        XCTAssertEqual(Double(ball.position.y), where_.y, accuracy: 1e-5)
        XCTAssertEqual(Double(ball.position.z), where_.z, accuracy: 1e-5)

        BlastEntity.update(entity, grenades: [], blasts: [])
        XCTAssertTrue(entity.children.allSatisfy { !$0.isEnabled }, "a grenade that is gone is still drawn")
    }

    @MainActor
    func testABlastIsDrawnWhereItWentOffAndGrowsToTheBlastRadius() throws {
        let game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        let entity = BlastEntity.make(for: game.bots, configuration: configuration)
        let radius = try numbers.blastRadius
        let life = world.configurations.view.blastFlashSeconds
        let where_ = SIMD3(4.0, 0.5, 2.0)
        var flash = Flash(position: where_, radius: radius, life: life, left: life)
        BlastEntity.update(entity, grenades: [], blasts: [flash])
        let young = try XCTUnwrap(entity.children.first { $0.isEnabled })
        XCTAssertEqual(Double(young.position.x), where_.x, accuracy: 1e-5)
        XCTAssertLessThan(Double(young.scale.x), radius, "it was its whole size the moment it went off")

        flash.left = .zero
        BlastEntity.update(entity, grenades: [], blasts: [flash])
        let old = try XCTUnwrap(entity.children.first { $0.isEnabled })
        XCTAssertEqual(Double(old.scale.x), radius, accuracy: 1e-5, "it never grew to the blast radius")
    }

    /// The whole chain in a session of the shipped arena, with nothing posed: the match
    /// throws a grenade of its own accord and the scene has a ball on it (FR-VIEW-350).
    @MainActor
    func testAMatchThatThrowsAGrenadeHasOneOnTheScreen() throws {
        let shipped = try Launch.world().get()
        let game = Game(world: shipped, start: try XCTUnwrap(Game.firstStart(in: shipped)))
        let built = SceneBuilder.scene(for: shipped.plan, view: shipped.configurations.view)
        let camera = try XCTUnwrap(built.root.children.first { $0.name == EntityName.camera })
        let balls = BlastEntity.make(for: game.bots, configuration: shipped.configurations.bot)
        let session = GameSession(game: game,
                                  snakeEntity: SnakeEntity.make(radius: shipped.configurations.tuning.bodyRadius,
                                                                segments: game.snake.segments),
                                  botEntities: BotEntity.make(for: game.bots,
                                                              height: shipped.configurations.bot.figureHeight),
                                  shotEntities: ShotEntity.make(for: game.bots),
                                  blastEntities: balls,
                                  camera: camera, seeThrough: built.seeThrough, distance: 12, fieldOfView: 50)
        var thrown: Thrown?
        for _ in Int.zero..<Int((60 / frame).rounded()) where thrown == nil {
            session.step(seconds: frame)
            thrown = session.game.grenades.first
        }
        let grenade = try XCTUnwrap(thrown, "no grenade was thrown in a minute of the shipped arena")
        let drawn = balls.children.filter { $0.isEnabled && $0.name.hasPrefix(EntityName.grenade) }
        XCTAssertFalse(drawn.isEmpty, "a grenade is in the air and nothing is drawn")
        XCTAssertTrue(drawn.contains { ball in
            Perception.metres(SIMD3(Double(ball.position.x), Double(ball.position.y), Double(ball.position.z)),
                              grenade.position) < 1e-5
        }, "no ball is where the grenade is")
    }

    func testABlastLivesForTheMomentTheViewGivesItAndThenLeavesTheMatch() throws {
        var game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        let life = world.configurations.view.blastFlashSeconds
        XCTAssertGreaterThan(life, frame, "a blast is drawn for less than a frame, so this proves nothing")
        var flying = [try thrown(from: SIMD3(3.0, 0.875, 1.0), at: SIMD3(5.0, .zero, 1.0))]
        flying[try checkedIndex(0, of: flying)].fuse = frame / 2
        var bots: [Bot] = []
        let going = Blast.burn(&flying, seconds: frame, bots: &bots, snake: [], plan: world.plan,
                               gravity: gravity, flashFor: life)
        let flash = try element(0, of: going.flashes)
        XCTAssertEqual(flash.left, life, "the blast was born already spent")
        XCTAssertEqual(flash.radius, try numbers.blastRadius)

        // And in the match it is counted down and gone (FR-VIEW-360).
        game.advance(seconds: frame)
        XCTAssertTrue(game.blasts.isEmpty, "a match with no grenade thrown has a blast in it")
    }
}
