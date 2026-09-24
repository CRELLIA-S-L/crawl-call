// The window on an iPad (FR-VIEW-210, FR-VIEW-220, FR-VIEW-230): any orientation there
// and landscape on the phone, the lock asked for on the iPad alone, a match paused
// when the lock comes or goes and resumed by one press — and the real scene the suite
// runs in built that way, not a copy of it.
//
// verifies: FR-VIEW-210, FR-VIEW-220, FR-VIEW-230
import RealityKit
import SwiftUI
import UIKit
import XCTest
@testable import CrawlCall

@MainActor
final class WindowTests: XCTestCase {
    private func session() throws -> GameSession {
        let world = try Launch.world().get()
        let built = SceneBuilder.scene(for: world.plan, view: world.configurations.view)
        let start = try XCTUnwrap(Game.start(in: world))
        let game = Game(world: world, start: start)
        let camera = try XCTUnwrap(built.root.children.first { $0.name == "camera" })
        return GameSession(game: game,
                           snakeEntity: SnakeEntity.make(radius: world.configurations.tuning.bodyRadius,
                                                         segments: game.snake.segments),
                           botEntities: BotEntity.make(for: game.bots, height: world.configurations.bot.figureHeight),
                           shotEntities: ShotEntity.make(for: game.bots),
                           camera: camera, seeThrough: built.seeThrough,
                           distance: 12, fieldOfView: 50)
    }

    // MARK: FR-VIEW-210 — any orientation on the iPad, landscape on the phone

    func testTheIPadTakesEveryOrientationAndThePhoneOnlyLandscape() throws {
        // Read from the file: `infoDictionary` resolves `~ipad` and `~iphone` keys for
        // the device the suite runs on and hides the other.
        let url = try XCTUnwrap(Bundle.main.url(forResource: "Info", withExtension: "plist"))
        let info = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: Any])
        let pad = Set(info["UISupportedInterfaceOrientations~ipad"] as? [String] ?? [])
        let phone = Set(info["UISupportedInterfaceOrientations~iphone"] as? [String] ?? [])
        XCTAssertEqual(pad, ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
                             "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"])
        XCTAssertEqual(phone, ["UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"])
    }

    func testTheSmallestWindowHoldsTheStickAndTheButtonSideBySide() {
        // The stick's plate is 120 points across, the button 96, and there are three
        // margins of 28 between and beside them; the taller of the two, 120, has two.
        XCTAssertEqual(GameWindow.minimumSize.width, 300, accuracy: 1e-9)
        XCTAssertEqual(GameWindow.minimumSize.height, 176, accuracy: 1e-9)
    }

    func testTheSceneTheSuiteRunsInIsBuiltAsTheGameBuildsIt() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let root = try XCTUnwrap(scene.windows.first?.rootViewController)
        XCTAssertTrue(String(describing: type(of: root)).hasPrefix("GameHostingController"),
                      "the window's root is \(type(of: root))")
        if let restrictions = scene.sizeRestrictions {
            XCTAssertEqual(restrictions.minimumSize, GameWindow.minimumSize)
        } else {
            // Only a platform that resizes scenes has restrictions to set.
            XCTAssertNotEqual(scene.traitCollection.userInterfaceIdiom, .pad,
                              "an iPad scene came without size restrictions")
        }
    }

    func testTheStatusBarStaysHidden() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let root = try XCTUnwrap(scene.windows.first?.rootViewController)
        XCTAssertTrue(root.prefersStatusBarHidden)
    }

    // A frame narrower than it is tall shows less ground across than down, and the head
    // must stay inside what it shows (FR-VIEW-020 in any window, FR-VIEW-210).
    private let region = ViewConfiguration.CentralRegion(width: 0.4, height: 0.4)
    private let wide = ScenePlan.Bounds(lowest: SIMD3(-100, 0, -100), highest: SIMD3(100, 0, 100))

    func testAnUprightFrameKeepsTheHeadInsideTheNarrowerSpanAcross() {
        // At 10 m and a 90° field of view the ground span down is 20 m; a frame half as
        // wide as it is tall shows 10 m across, and 40 % of that is 4 m, so a head 3 m
        // to the side of a still focus is outside the region and pulls it 1 m along.
        let focus = SceneView.focus(keeping: SIMD3(3, 0, 0), inside: region, from: .zero,
                                    distance: 10, fieldOfViewDegrees: 90, aspect: 0.5, within: wide)
        XCTAssertEqual(focus.x, 1, accuracy: 1e-9)
    }

    func testAWideFrameFramesAsItAlwaysHas() {
        // Wider than tall, the span across is taken from the span down, as before any
        // iPad: a head 3 m aside is inside the 8 m region and the focus does not move.
        for aspect in [1.0, 16.0 / 9.0, 2.2] {
            let focus = SceneView.focus(keeping: SIMD3(3, 0, 0), inside: region, from: .zero,
                                        distance: 10, fieldOfViewDegrees: 90, aspect: aspect, within: wide)
            XCTAssertEqual(focus.x, 0, accuracy: 1e-9, "aspect \(aspect)")
        }
    }

    // MARK: FR-VIEW-220 — the lock is asked for on the iPad alone

    func testTheLockIsAskedForOnTheIPadAndNotOnThePhone() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let root = try XCTUnwrap(scene.windows.first?.rootViewController)
        XCTAssertEqual(root.prefersInterfaceOrientationLocked,
                       root.traitCollection.userInterfaceIdiom == .pad)
    }

    // MARK: FR-VIEW-230 — a change of the lock pauses, one press resumes

    /// A session the player has steered.
    private func steered() throws -> GameSession {
        let session = try session()
        session.apply(.move(direction: SIMD2(1, 0)))
        return session
    }

    func testGainingTheLockPausesTheMatch() throws {
        let host = MatchHost()
        let session = try steered()
        host.session = session
        host.orientationLock(was: false, is: true)
        XCTAssertTrue(session.isPaused)
    }

    func testLosingTheLockPausesTheMatch() throws {
        let host = MatchHost()
        let session = try steered()
        host.session = session
        host.orientationLock(was: true, is: false)
        XCTAssertTrue(session.isPaused)
    }

    func testAResizeThatLeavesTheLockAloneDoesNotPause() throws {
        let host = MatchHost()
        let session = try steered()
        host.session = session
        host.orientationLock(was: false, is: false)
        host.orientationLock(was: true, is: true)
        XCTAssertFalse(session.isPaused)
    }

    func testTheLockGrantedAsAMatchBeginsDoesNotPauseIt() throws {
        // iPadOS grants the lock as the scene becomes active full screen, before the
        // stick has been touched: that is where a match begins, not a change to it.
        let host = MatchHost()
        let session = try session()
        host.session = session
        host.orientationLock(was: false, is: true)
        XCTAssertFalse(session.isPaused)
    }

    func testLettingGoOfTheStickStillCountsAsSteered() throws {
        // Releasing the stick sends a zero direction; the match has been steered all
        // the same, and a change of the window afterwards pauses it.
        let host = MatchHost()
        let session = try steered()
        session.apply(.move(direction: .zero))
        host.session = session
        host.orientationLock(was: true, is: false)
        XCTAssertTrue(session.isPaused)
    }

    func testASecondChangeWhilePausedDoesNotResume() throws {
        // The pause intent toggles; a lock lost straight after it was gained must not
        // hand the match back to the player unasked.
        let host = MatchHost()
        let session = try steered()
        host.session = session
        host.orientationLock(was: false, is: true)
        host.orientationLock(was: true, is: false)
        XCTAssertTrue(session.isPaused)
    }

    func testThePlatesControlResumesAndOnlyOnce() throws {
        let session = try session()
        session.pause()
        session.resume()
        XCTAssertFalse(session.isPaused)
        session.resume()
        XCTAssertFalse(session.isPaused, "a second press paused the match again")
    }

    func testAPausedMatchStandsStill() throws {
        let session = try session()
        session.apply(.move(direction: SIMD2(1, 0)))
        session.pause()
        let before = session.game.snake.head
        session.step(seconds: 0.05)
        XCTAssertEqual(session.game.snake.head, before)
    }
}
