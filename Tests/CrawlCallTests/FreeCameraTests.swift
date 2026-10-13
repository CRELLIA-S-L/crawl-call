// Debug mode's free camera (FR-TOOL-070): taken off the snake by a pinch or a
// two-finger drag, moved nearer, further and across the arena within limits, and put
// back on the snake by a button (ADR-0023). The gestures themselves are UIKit's and are
// tried on the phone; what they are turned into is tested here.
//
// file verifies: FR-TOOL-070
import RealityKit
import XCTest
@testable import CrawlCall

final class FreeCameraTests: XCTestCase {
    private let arena = ScenePlan.Bounds(lowest: SIMD3(0, 0, 0), highest: SIMD3(10, 3, 6))

    private func camera(at focus: SIMD3<Double> = SIMD3(5, 0, 3), distance: Double = 10,
                        pitch: Double = 55) -> FreeCamera {
        FreeCamera(focus: focus, distance: distance, pitch: pitch, nearest: 2, farthest: 20,
                   lowestPitch: 10, highestPitch: 89, arena: arena)
    }

    // MARK: zoom

    func testPinchingApartBringsTheCameraNearerByThePinch() {
        var c = camera()
        c.zoom(by: 2)
        XCTAssertEqual(c.distance, 5, accuracy: 1e-9)
        c.zoom(by: 0.5)
        XCTAssertEqual(c.distance, 10, accuracy: 1e-9)
    }

    func testTheCameraGoesNoNearerAndNoFurtherThanTheLimits() {
        var c = camera()
        c.zoom(by: 100)
        XCTAssertEqual(c.distance, 2, accuracy: 1e-9)
        c.zoom(by: 0.001)
        XCTAssertEqual(c.distance, 20, accuracy: 1e-9)
    }

    func testAPinchThatIsNotAFactorChangesNothing() {
        var c = camera()
        for nonsense in [0.0, -1.0, .infinity, .nan] { c.zoom(by: nonsense) }
        XCTAssertEqual(c.distance, 10, accuracy: 1e-9)
    }

    // MARK: pan

    func testTheGroundGoesWithTheFingers() {
        // A drag of 100 points on a screen 1000 points tall is a tenth of the ground in
        // view. Right and down on the screen, so the focus goes left and away.
        var c = camera()
        let span = SceneView.groundSpan(distance: 10, fieldOfViewDegrees: 50)
        c.pan(by: SIMD2(100, 100), screenHeight: 1000, fieldOfViewDegrees: 50)
        XCTAssertEqual(c.focus.x, 5 - span / 10, accuracy: 1e-9)
        // Up and down the screen is the ground seen at the pitch: more ground a point.
        XCTAssertEqual(c.focus.z, 3 - span / 10 / sin(55 * .pi / 180), accuracy: 1e-9)
        XCTAssertEqual(c.focus.y, 0, accuracy: 1e-12)
    }

    func testTheNearerTheCameraTheLessGroundADragCovers() {
        var far = camera(distance: 20)
        var near = camera(distance: 2)
        far.pan(by: SIMD2(50, 0), screenHeight: 1000, fieldOfViewDegrees: 50)
        near.pan(by: SIMD2(50, 0), screenHeight: 1000, fieldOfViewDegrees: 50)
        XCTAssertEqual((5 - far.focus.x) / (5 - near.focus.x), 10, accuracy: 1e-9)
    }

    func testTheCameraLooksAtNothingBeyondTheArena() {
        var c = camera()
        c.pan(by: SIMD2(-1e6, -1e6), screenHeight: 1000, fieldOfViewDegrees: 50)
        XCTAssertEqual(c.focus.x, arena.highest.x, accuracy: 1e-9)
        XCTAssertEqual(c.focus.z, arena.highest.z, accuracy: 1e-9)
        c.pan(by: SIMD2(1e6, 1e6), screenHeight: 1000, fieldOfViewDegrees: 50)
        XCTAssertEqual(c.focus.x, arena.lowest.x, accuracy: 1e-9)
        XCTAssertEqual(c.focus.z, arena.lowest.z, accuracy: 1e-9)
    }

    func testAFreshCameraIsInsideItsLimits() {
        let c = FreeCamera(focus: SIMD3(-5, 0, 99), distance: 500, pitch: 95, nearest: 2, farthest: 20,
                           lowestPitch: 10, highestPitch: 89, arena: arena)
        XCTAssertEqual(c.distance, 20, accuracy: 1e-9)
        XCTAssertEqual(c.pitch, 89, accuracy: 1e-9)
        XCTAssertEqual(c.focus.x, 0, accuracy: 1e-9)
        XCTAssertEqual(c.focus.z, 6, accuracy: 1e-9)
    }

    // MARK: turning and tilting

    func testATwistTurnsTheCameraByAsMuchAsTheFingersTurnedWithoutALimit() {
        var c = camera()
        c.turn(by: .pi / 2)
        XCTAssertEqual(c.yaw, 90, accuracy: 1e-9)
        for _ in 0..<5 { c.turn(by: .pi / 2) }
        // Six quarter turns is one and a half rounds: a quarter past a half.
        XCTAssertEqual(c.yaw, 180, accuracy: 1e-9)
        c.turn(by: .nan)
        XCTAssertEqual(c.yaw, 180, accuracy: 1e-9)
    }

    func testTheWholeHeightOfTheScreenIsTheWholeTilt() {
        // From the lowest pitch, a drag down the whole screen reaches the steepest, and
        // up the whole screen comes back; no further either way.
        var c = camera(pitch: 10)
        c.tilt(by: 800, screenHeight: 800)
        XCTAssertEqual(c.pitch, 89, accuracy: 1e-9)
        c.tilt(by: 5000, screenHeight: 800)
        XCTAssertEqual(c.pitch, 89, accuracy: 1e-9)
        c.tilt(by: -400, screenHeight: 800)
        XCTAssertEqual(c.pitch, 89 - 79.0 / 2, accuracy: 1e-9)
        c.tilt(by: -5000, screenHeight: 800)
        XCTAssertEqual(c.pitch, 10, accuracy: 1e-9)
    }

    func testTheScreensAxesTurnWithTheCamera() {
        let none = SceneView.screenAxes(yawDegrees: 0)
        XCTAssertEqual(none.right.x, 1, accuracy: 1e-12); XCTAssertEqual(none.right.y, 0, accuracy: 1e-12)
        XCTAssertEqual(none.down.x, 0, accuracy: 1e-12); XCTAssertEqual(none.down.y, 1, accuracy: 1e-12)
        // A quarter turn anticlockwise seen from above: the camera now stands on the +x
        // side, looking towards -x, so the screen's down is +x and its right is -z.
        let quarter = SceneView.screenAxes(yawDegrees: 90)
        XCTAssertEqual(quarter.down.x, 1, accuracy: 1e-12); XCTAssertEqual(quarter.down.y, 0, accuracy: 1e-12)
        XCTAssertEqual(quarter.right.x, 0, accuracy: 1e-12); XCTAssertEqual(quarter.right.y, -1, accuracy: 1e-12)
    }

    func testAfterATurnTheGroundStillGoesWithTheFingers() {
        // A drag to the right moves the focus against the screen's right, whichever way
        // on the ground that now is.
        var c = camera()
        c.turn(by: 30 * .pi / 180)
        let span = SceneView.groundSpan(distance: 10, fieldOfViewDegrees: 50)
        c.pan(by: SIMD2(100, 0), screenHeight: 1000, fieldOfViewDegrees: 50)
        let right = SceneView.screenAxes(yawDegrees: 30).right
        XCTAssertEqual(c.focus.x, 5 - span / 10 * right.x, accuracy: 1e-9)
        XCTAssertEqual(c.focus.z, 3 - span / 10 * right.y, accuracy: 1e-9)
    }

    @MainActor
    func testTheCameraLooksAtItsFocusFromItsDistanceWhateverItsPitchAndYaw() {
        // Placed at any pitch and yaw, the camera is the distance from the focus and its
        // forward axis — -z in its own frame — points at it.
        let camera = Entity()
        let focus = SIMD3<Double>(2, 0.5, -1)
        for (pitch, yaw) in [(55.0, 0.0), (10.0, 37.0), (89.0, -120.0), (30.0, 200.0), (90.0, 64.0)] {
            SceneView.place(camera, lookingAt: focus, pitchDegrees: pitch, yawDegrees: yaw, distance: 6)
            let toFocus = SIMD3<Float>(focus) - camera.position
            XCTAssertEqual(simd_length(toFocus), 6, accuracy: 1e-4)
            let forward = camera.orientation.act(SIMD3<Float>(0, 0, -1))
            XCTAssertEqual(simd_dot(forward, simd_normalize(toFocus)), 1, accuracy: 1e-4,
                           "at pitch \(pitch) and yaw \(yaw) the camera does not look at its focus")
            // And it does not roll: its right stays level.
            XCTAssertEqual(camera.orientation.act(SIMD3<Float>(1, 0, 0)).y, 0, accuracy: 1e-5)
            // And it is turned as the yaw says: its right lies along the ground at the
            // yaw, anticlockwise seen from above for a positive one. Asked of its right
            // and not of where it stands, because looking straight down it stands
            // right over its focus and its turn is in its axes alone.
            let right = camera.orientation.act(SIMD3<Float>(1, 0, 0))
            let expected = SIMD3<Float>(Float(cos(yaw * .pi / 180)), 0, Float(-sin(yaw * .pi / 180)))
            XCTAssertEqual(simd_dot(right, expected), 1, accuracy: 1e-4,
                           "at pitch \(pitch) and yaw \(yaw) the camera is turned the wrong way")
        }
    }

    // MARK: in a match

    @MainActor
    func testAPinchTakesTheCameraOffTheSnakeAndItStaysWhereItWasPut() throws {
        let world = try Launch.world().get()
        let built = SceneBuilder.scene(for: world.plan, view: world.configurations.view)
        let game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        let camera = try XCTUnwrap(built.root.children.first { $0.name == "camera" })
        let session = GameSession(game: game,
                                  snakeEntity: SnakeEntity.make(radius: world.configurations.tuning.bodyRadius,
                                                                segments: game.snake.segments),
                                  botEntities: BotEntity.make(for: game.bots, height: world.configurations.bot.figureHeight),
                                  shotEntities: ShotEntity.make(for: game.bots),
                                  blastEntities: BlastEntity.make(for: game.bots, configuration: game.world.configurations.bot),
                                  camera: camera, seeThrough: built.seeThrough, distance: 12, fieldOfView: 50)
        XCTAssertNil(session.freeCamera, "a match begins with the camera on the snake")
        let following = camera.position

        session.zoomCamera(by: 2)
        let free = try XCTUnwrap(session.freeCamera)
        XCTAssertEqual(free.distance, 6, accuracy: 1e-9)
        XCTAssertLessThan(simd_distance(camera.position, SIMD3<Float>(free.focus)), simd_distance(following, SIMD3<Float>(free.focus)),
                          "the camera did not come nearer")
        let put = camera.position

        // The snake walks away along the top row; a free camera does not go with it.
        session.apply(.move(direction: SIMD2(1, 0)))
        for _ in 0..<120 { session.step(seconds: 1.0 / 60) }
        XCTAssertGreaterThan(session.game.snake.head.x, 2, "the snake did not move, so this proves nothing")
        XCTAssertEqual(simd_distance(camera.position, put), 0, accuracy: 1e-5, "the free camera followed the snake")
    }

    /// A session over the shipped world, or over it with the view configuration's
    /// keys replaced, with the camera it moves.
    @MainActor
    private func session(view replacing: [String: Any] = [:]) throws -> (GameSession, Entity) {
        let base = try Launch.world().get()
        var configurations = base.configurations
        if !replacing.isEmpty {
            let url = try XCTUnwrap(Bundle.main.url(forResource: "view", withExtension: "json", subdirectory: "config"))
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as? [String: Any])
            for (key, value) in replacing { json[key] = value }
            let view = try Configurations.decode(ViewConfiguration.self, named: "view", schema: ViewConfiguration.schema,
                                                 from: JSONSerialization.data(withJSONObject: json))
            configurations = Configurations(snake: configurations.snake, tuning: configurations.tuning, view: view,
                                            bot: configurations.bot, match: configurations.match,
                                            scoring: configurations.scoring,
                                            commander: configurations.commander)
        }
        let world = World(configurations: configurations, kit: base.kit, map: base.map, setting: base.setting, graph: base.graph, plan: base.plan)
        let built = SceneBuilder.scene(for: world.plan, view: world.configurations.view)
        let game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        let camera = try XCTUnwrap(built.root.children.first { $0.name == "camera" })
        let session = GameSession(game: game,
                                  snakeEntity: SnakeEntity.make(radius: world.configurations.tuning.bodyRadius,
                                                                segments: game.snake.segments),
                                  botEntities: BotEntity.make(for: game.bots, height: world.configurations.bot.figureHeight),
                                  shotEntities: ShotEntity.make(for: game.bots),
                                  blastEntities: BlastEntity.make(for: game.bots, configuration: game.world.configurations.bot),
                                  camera: camera, seeThrough: built.seeThrough, distance: 12, fieldOfView: 50)
        return (session, camera)
    }

    @MainActor
    func testZoomingAndPanningNeitherTiltNorTurnTheCamera() throws {
        // Only a twist turns the camera and only three fingers tilt it; the other two
        // gestures move it and leave its angle as it was.
        let (session, camera) = try session()
        let following = camera.orientation
        session.zoomCamera(by: 1.7)
        session.panCamera(by: SIMD2(-240, 130), screenHeight: 800)
        XCTAssertNotNil(session.freeCamera)
        XCTAssertEqual(abs(simd_dot(camera.orientation.vector, following.vector)), 1, accuracy: 1e-5,
                       "zooming or panning turned the camera")
    }

    @MainActor
    func testATwistAndAThreeFingerDragTurnAndTiltTheCameraInAMatch() throws {
        let (session, camera) = try session()
        let following = camera.orientation
        session.turnCamera(by: 0.6)
        session.tiltCamera(by: -200, screenHeight: 800)
        let free = try XCTUnwrap(session.freeCamera)
        XCTAssertEqual(free.yaw, 0.6 * 180 / .pi, accuracy: 1e-9)
        XCTAssertLessThan(free.pitch, 55, "dragging up did not lower the camera towards the horizon")
        XCTAssertLessThan(abs(simd_dot(camera.orientation.vector, following.vector)), 1 - 1e-4,
                          "the camera did not turn")
        // Still looking at the point it was left looking at.
        let forward = camera.orientation.act(SIMD3<Float>(0, 0, -1))
        let toFocus = simd_normalize(SIMD3<Float>(free.focus) - camera.position)
        XCTAssertEqual(simd_dot(forward, toFocus), 1, accuracy: 1e-4)
    }

    @MainActor
    func testATwistAloneTurnsTheCameraInTheScene() throws {
        // Turned by a quarter and nothing else, the camera stands a quarter of the way
        // round its focus from where the match had it.
        let (session, camera) = try session()
        let before = camera.position
        session.turnCamera(by: .pi / 2)
        let free = try XCTUnwrap(session.freeCamera)
        let was = SIMD2<Float>(before.x - Float(free.focus.x), before.z - Float(free.focus.z))
        let now = SIMD2<Float>(camera.position.x - Float(free.focus.x), camera.position.z - Float(free.focus.z))
        XCTAssertEqual(simd_dot(simd_normalize(was), simd_normalize(now)), 0, accuracy: 1e-4,
                       "a quarter twist did not take the camera a quarter of the way round")
    }

    @MainActor
    func testThePitchLimitsAreTheViewConfigurations() throws {
        let (session, _) = try session(view: ["freeCameraLowestPitch": 25, "freeCameraHighestPitch": 70])
        session.tiltCamera(by: -10_000, screenHeight: 800)
        XCTAssertEqual(try XCTUnwrap(session.freeCamera).pitch, 25, accuracy: 1e-9)
        session.tiltCamera(by: 10_000, screenHeight: 800)
        XCTAssertEqual(try XCTUnwrap(session.freeCamera).pitch, 70, accuracy: 1e-9)
    }

    @MainActor
    func testTheZoomLimitsAreTheViewConfigurations() throws {
        // Not the shipped numbers: limits of 3.5 and 7 m are 3.5 and 7 m, so they come
        // from the configuration and not from the code (IF-VIEW-020, ADR-0023).
        let (session, _) = try session(view: ["freeCameraNearest": 3.5, "freeCameraFarthest": 7.0])
        session.zoomCamera(by: 1000)
        XCTAssertEqual(try XCTUnwrap(session.freeCamera).distance, 3.5, accuracy: 1e-9)
        session.zoomCamera(by: 0.0001)
        XCTAssertEqual(try XCTUnwrap(session.freeCamera).distance, 7.0, accuracy: 1e-9)
    }

    @MainActor
    func testTheButtonPutsTheCameraBackWhereTheMatchWouldHaveIt() throws {
        // Two sessions driven alike, one of them with its camera taken off and put
        // back: once it is back, the two cameras stand in the same place.
        func build() throws -> (GameSession, Entity) {
            let world = try Launch.world().get()
            let built = SceneBuilder.scene(for: world.plan, view: world.configurations.view)
            let game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
            let camera = try XCTUnwrap(built.root.children.first { $0.name == "camera" })
            let s = GameSession(game: game,
                                snakeEntity: SnakeEntity.make(radius: world.configurations.tuning.bodyRadius,
                                                              segments: game.snake.segments),
                                botEntities: BotEntity.make(for: game.bots, height: world.configurations.bot.figureHeight),
                                shotEntities: ShotEntity.make(for: game.bots),
                                blastEntities: BlastEntity.make(for: game.bots, configuration: game.world.configurations.bot),
                                camera: camera, seeThrough: built.seeThrough, distance: 12, fieldOfView: 50)
            return (s, camera)
        }
        let (kept, keptCamera) = try build()
        let (moved, movedCamera) = try build()
        moved.panCamera(by: SIMD2(300, -200), screenHeight: 800)
        moved.zoomCamera(by: 3)
        moved.turnCamera(by: 1.1)
        moved.tiltCamera(by: -150, screenHeight: 800)
        for session in [kept, moved] {
            session.apply(.move(direction: SIMD2(1, 0)))
            for _ in 0..<90 { session.step(seconds: 1.0 / 60) }
        }
        XCTAssertGreaterThan(simd_distance(keptCamera.position, movedCamera.position), 1,
                             "the free camera was never away, so this proves nothing")
        moved.followSnake()
        XCTAssertNil(moved.freeCamera)
        XCTAssertEqual(simd_distance(keptCamera.position, movedCamera.position), 0, accuracy: 1e-4)
        XCTAssertEqual(abs(simd_dot(keptCamera.orientation.vector, movedCamera.orientation.vector)), 1, accuracy: 1e-5,
                       "the camera came back to the snake still turned or tilted")
    }
}
