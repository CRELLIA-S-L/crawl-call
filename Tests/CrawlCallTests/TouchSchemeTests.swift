// Touch to intent (FR-VIEW-050).
//
// verifies: FR-VIEW-050, IF-VIEW-010
import XCTest
@testable import CrawlCall

final class TouchSchemeTests: XCTestCase {
    func testDraggingRightSteersAlongPositiveX() {
        let d = TouchScheme.direction(of: CGSize(width: 100, height: 0))
        XCTAssertEqual(d.x, 1, accuracy: 1e-9)
        XCTAssertEqual(d.y, 0, accuracy: 1e-9)
    }

    func testDraggingTowardsThePlayerSteersAlongPositiveZ() {
        // Down the screen is towards the camera, which looks along −z.
        let d = TouchScheme.direction(of: CGSize(width: 0, height: 100))
        XCTAssertEqual(d.x, 0, accuracy: 1e-9)
        XCTAssertEqual(d.y, 1, accuracy: 1e-9)
    }

    func testTheDirectionIsAUnitVectorWhateverTheDragLength() {
        for length in [13.0, 50.0, 500.0] {
            let d = TouchScheme.direction(of: CGSize(width: length, height: length))
            XCTAssertEqual((d.x * d.x + d.y * d.y).squareRoot(), 1, accuracy: 1e-9)
        }
    }

    func testAFingerRestingOnTheGlassIsNoCommand() {
        XCTAssertEqual(TouchScheme.direction(of: CGSize(width: 3, height: 4)), .zero)
        XCTAssertEqual(TouchScheme.direction(of: .zero), .zero)
    }

    func testTheDeadZoneIsWhereItIsSetAndNotElsewhere() {
        let justInside = CGSize(width: 11, height: 0)
        let justOutside = CGSize(width: 13, height: 0)
        XCTAssertEqual(TouchScheme.direction(of: justInside, deadZone: 12), .zero)
        XCTAssertNotEqual(TouchScheme.direction(of: justOutside, deadZone: 12), .zero)
    }

    func testTheSnakeActuallyStopsWhenTheThumbLifts() throws {
        // The scheme and the logic, wired: push the stick, move, lift off, stay.
        let world = try Launch.world().get()
        var game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        game.apply(.move(direction: TouchScheme.stick(CGSize(width: 100, height: 0)).direction))
        game.advance(seconds: 0.1)
        let moved = game.snake.head
        XCTAssertGreaterThan(moved.x, 0)
        game.apply(TouchScheme.release)
        game.advance(seconds: 0.5)
        XCTAssertEqual(game.snake.head.x, moved.x, accuracy: 1e-12)
    }
}
