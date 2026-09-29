// The stick's arithmetic (FR-VIEW-050): what a thumb's offset from the centre asks
// for, and where the knob is drawn while it asks. And what the eat button knows
// about itself (FR-VIEW-160).
//
// verifies: FR-VIEW-050, FR-VIEW-160
import XCTest
@testable import CrawlCall

final class StickTests: XCTestCase {
    func testAThumbOnTheCentreAsksForNothing() {
        let still = TouchScheme.stick(CGSize(width: 0, height: 0))
        XCTAssertEqual(still.direction, .zero)
        XCTAssertEqual(still.knob, .zero)
        // And a thumb that has barely moved is a thumb resting, not a command.
        let resting = TouchScheme.stick(CGSize(width: Stick.deadZone * 0.5, height: 0))
        XCTAssertEqual(resting.direction, .zero)
        XCTAssertEqual(resting.knob, .zero)
    }

    func testTheDirectionIsTheWayTheThumbPushedAndOfUnitLength() {
        let right = TouchScheme.stick(CGSize(width: 40, height: 0))
        XCTAssertEqual(right.direction.x, 1, accuracy: 1e-9)
        XCTAssertEqual(right.direction.y, 0, accuracy: 1e-9)

        // Down the screen is +z: the camera looks along −z from above and behind.
        let towards = TouchScheme.stick(CGSize(width: 0, height: 40))
        XCTAssertEqual(towards.direction.y, 1, accuracy: 1e-9)

        let corner = TouchScheme.stick(CGSize(width: 30, height: 30))
        let length = (corner.direction.x * corner.direction.x
                      + corner.direction.y * corner.direction.y).squareRoot()
        XCTAssertEqual(length, 1, accuracy: 1e-9, "a diagonal push is not faster than a straight one")
    }

    func testHowFarTheThumbPushesDoesNotChangeHowFastTheSnakeGoes() {
        // The stick says where, the configuration says how fast (FR-SNAKE-030).
        let near = TouchScheme.stick(CGSize(width: 20, height: 0)).direction
        let far = TouchScheme.stick(CGSize(width: 500, height: 0)).direction
        XCTAssertEqual(near, far)
    }

    func testTheKnobStaysOnItsBaseHoweverFarTheThumbSlides() {
        let outside = TouchScheme.stick(CGSize(width: 400, height: 300))
        let travelled = (Double(outside.knob.width) * Double(outside.knob.width)
                         + Double(outside.knob.height) * Double(outside.knob.height)).squareRoot()
        XCTAssertEqual(travelled, Stick.radius, accuracy: 1e-9)
        // And it still steers that way: a thumb sliding off the plate keeps its
        // direction rather than dropping it.
        XCTAssertGreaterThan(outside.direction.x, 0)
        XCTAssertGreaterThan(outside.direction.y, 0)
    }

    func testTheStickStandsWhereTheThumbLands() {
        // Anywhere on the left half with room round it, the plate is centred under the
        // thumb (FR-VIEW-050, ADR-0051).
        let half = CGSize(width: 440, height: 400)
        for touch in [CGPoint(x: 200, y: 200), CGPoint(x: 90, y: 310), CGPoint(x: 380, y: 70)] {
            let centre = TouchScheme.stickCentre(at: touch, in: half)
            XCTAssertEqual(Double(centre.x), Double(touch.x), accuracy: 1e-9)
            XCTAssertEqual(Double(centre.y), Double(touch.y), accuracy: 1e-9)
        }
    }

    func testAThumbLandingByAnEdgeHasTheWholePlateOnTheHalf() {
        let half = CGSize(width: 440, height: 400)
        let plate = Stick.radius * Stick.plateInRadii / 2
        for touch in [CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 399), CGPoint(x: 439, y: 200), CGPoint(x: 200, y: -30)] {
            let centre = TouchScheme.stickCentre(at: touch, in: half)
            XCTAssertGreaterThanOrEqual(Double(centre.x) - plate, -1e-9, "\(touch)")
            XCTAssertLessThanOrEqual(Double(centre.x) + plate, Double(half.width) + 1e-9, "\(touch)")
            XCTAssertGreaterThanOrEqual(Double(centre.y) - plate, -1e-9, "\(touch)")
            XCTAssertLessThanOrEqual(Double(centre.y) + plate, Double(half.height) + 1e-9, "\(touch)")
        }
        // Moved in only as far as it takes: along the edge it stays under the thumb.
        let alongTheLeft = TouchScheme.stickCentre(at: CGPoint(x: 0, y: 200), in: half)
        XCTAssertEqual(Double(alongTheLeft.x), plate, accuracy: 1e-9)
        XCTAssertEqual(Double(alongTheLeft.y), 200, accuracy: 1e-9)
        // A half smaller than the plate has it in its middle.
        let small = TouchScheme.stickCentre(at: CGPoint(x: 3, y: 3), in: CGSize(width: 50, height: 80))
        XCTAssertEqual(Double(small.x), 25, accuracy: 1e-9)
        XCTAssertEqual(Double(small.y), 40, accuracy: 1e-9)
    }

    func testThumbsOnBothHalvesAreTheControlsAndNotACameraGesture() {
        // A thumb on the stick and one asking for a meal lie on the two halves; two or
        // three fingers of one hand on one half are the free camera's (FR-TOOL-070).
        XCTAssertTrue(TouchScheme.spanBothHalves([120, 700], width: 800))
        XCTAssertTrue(TouchScheme.spanBothHalves([399.9, 400], width: 800))
        XCTAssertFalse(TouchScheme.spanBothHalves([100, 250], width: 800))
        XCTAssertFalse(TouchScheme.spanBothHalves([450, 600, 790], width: 800))
        XCTAssertFalse(TouchScheme.spanBothHalves([300], width: 800))
        XCTAssertFalse(TouchScheme.spanBothHalves([], width: 800))
    }

    func testInsideTheBaseTheKnobFollowsTheThumbExactly() {
        let pushed = CGSize(width: 20, height: -15)
        let reading = TouchScheme.stick(pushed)
        XCTAssertEqual(Double(reading.knob.width), Double(pushed.width), accuracy: 1e-9)
        XCTAssertEqual(Double(reading.knob.height), Double(pushed.height), accuracy: 1e-9)
    }
}

@MainActor
final class EatButtonTests: XCTestCase {
    /// A session over the shipped map, with the scene it needs to exist.
    private func session() throws -> GameSession {
        let world = try Launch.world(map: "room").get()
        let built = SceneBuilder.scene(for: world.plan, view: world.configurations.view)
        let start = try XCTUnwrap(Game.firstStart(in: world))
        let game = Game(world: world, start: start)
        let snake = SnakeEntity.make(radius: world.configurations.tuning.bodyRadius,
                                     segments: game.snake.segments)
        let camera = try XCTUnwrap(built.root.children.first { $0.name == "camera" })
        return GameSession(game: game, snakeEntity: snake,
                           botEntities: BotEntity.make(for: game.bots, height: world.configurations.bot.figureHeight),
                           shotEntities: ShotEntity.make(for: game.bots),
                           camera: camera, seeThrough: built.seeThrough,
                           distance: 12, fieldOfView: 50)
    }

    func testTheButtonIsDarkWhereAMatchBegins() throws {
        // The squads spawn away from the snake, so at the whistle there is nothing to
        // eat and the button says so — which is the whole point of FR-VIEW-160: a
        // control that would do nothing does not pretend otherwise.
        let session = try session()
        XCTAssertFalse(session.canEat)
    }

    func testTheButtonLightsUpWhenTheHeadHasReachedSomebody() throws {
        // Driven to a bot rather than asserted about: the same walk a player makes,
        // read off the session the button reads, so that a `canEat` wired to nothing
        // fails here rather than passing on the dark half alone.
        let world = try Launch.world(map: "room").get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        let cell = world.configurations.tuning.navigationGraphCellSize
        let session = try session()
        let prey = try XCTUnwrap(session.game.bots.filter { $0.floor == 0 }.first)
        var route = Route.between(start,
                                  NavigationGraph.Node(floor: 0,
                                                       x: Int((prey.position.x / cell).rounded()),
                                                       z: Int((prey.position.z / cell).rounded())),
                                  in: world.graph)
        for _ in 0..<1800 where !session.canEat {
            if let next = route.first {
                let there = SIMD3(Double(next.x) * cell, 0, Double(next.z) * cell)
                let head = session.game.snake.head
                let toward = SIMD2(there.x - head.x, there.z - head.z)
                let length = (toward.x * toward.x + toward.y * toward.y).squareRoot()
                if length < 0.1 { route.removeFirst() }
                session.apply(.move(direction: length > 0 ? SIMD2(toward.x / length, toward.y / length) : .zero))
            }
            session.step(seconds: 1.0 / 60)
        }
        XCTAssertTrue(session.canEat, "the snake walked onto a bot and the button stayed dark")
    }
}
