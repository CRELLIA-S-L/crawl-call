// What runs while a match is on: the logic advanced once per frame, the entities moved
// to where it says, and the camera kept on the head.
//
// The frame's own delta is what advances the world. It is not what the frame rate is
// measured with — `specs/50-verification.md` says why, and the two are different
// questions asked of the same number.
//
// implements: FR-TOOL-070, FR-VIEW-020, FR-VIEW-030, FR-VIEW-060, FR-VIEW-100, FR-VIEW-140, FR-VIEW-150, FR-VIEW-155, FR-VIEW-160, FR-VIEW-170, FR-VIEW-180, FR-VIEW-190, FR-VIEW-230, FR-VIEW-210
import Foundation
import Observation
import RealityKit

@MainActor
@Observable
final class GameSession {
    private(set) var game: Game
    /// Whether the eat button would do anything if it were pressed right now
    /// (FR-VIEW-160). Read by the controls, written once a frame.
    private(set) var canEat = false
    private let snakeEntity: Entity
    private let botEntities: Entity
    private let shotEntities: Entity
    private let camera: Entity
    private var seeThrough: SeeThrough
    private var focus: SIMD3<Double>
    private let distance: Double
    private let fieldOfView: Double
    /// The camera the user has taken off the snake in debug mode (FR-TOOL-070), or nil
    /// while it follows the head (FR-VIEW-020).
    private(set) var freeCamera: FreeCamera?

    init(game: Game, snakeEntity: Entity, botEntities: Entity, shotEntities: Entity,
         camera: Entity, seeThrough: SeeThrough, distance: Double, fieldOfView: Double) {
        self.game = game
        self.snakeEntity = snakeEntity
        self.botEntities = botEntities
        self.shotEntities = shotEntities
        self.camera = camera
        self.seeThrough = seeThrough
        self.distance = distance
        self.fieldOfView = fieldOfView
        self.focus = game.snake.head
        place()
    }

    func apply(_ intent: Intent) { game.apply(intent) }

    /// Whether the match is paused, and asking for it without toggling: the pause
    /// intent flips the state, and a pause that arrives while paused must not resume
    /// (FR-VIEW-230). Both go through `apply`, the one door the player's asks come by.
    var isPaused: Bool { game.isPaused }

    /// The frame's width over its height, as the view last laid it out: what the camera
    /// can show across against what it shows down (FR-VIEW-210).
    var aspect: Double = Fraction.whole
    func pause() { if !game.isPaused { apply(.pause) } }
    func resume() { if game.isPaused { apply(.pause) } }

    /// A pause for a change of the window: only a match the player has steered has
    /// anything to lose to one (FR-VIEW-230).
    func pauseIfUnderWay() { if game.hasBeenSteered { pause() } }

    // MARK: the free camera of debug mode (FR-TOOL-070, ADR-0023)

    /// Pinched: the camera comes off the snake, if it was on it, and goes nearer or
    /// further.
    func zoomCamera(by factor: Double) {
        var camera = freeCamera ?? detached()
        camera.zoom(by: factor)
        freeCamera = camera
        place()
    }

    /// Dragged with two fingers: the camera comes off the snake, if it was on it, and
    /// the ground moves with the fingers.
    func panCamera(by points: SIMD2<Double>, screenHeight: Double) {
        var camera = freeCamera ?? detached()
        camera.pan(by: points, screenHeight: screenHeight, fieldOfViewDegrees: fieldOfView)
        freeCamera = camera
        place()
    }

    /// Twisted with two fingers: the camera comes off the snake, if it was on it, and
    /// turns round what it looks at, the ground turning with the fingers.
    func turnCamera(by radians: Double) {
        var camera = freeCamera ?? detached()
        camera.turn(by: radians)
        freeCamera = camera
        place()
    }

    /// Dragged up or down with three fingers: the camera comes off the snake, if it was
    /// on it, and tilts towards the horizon or towards looking straight down.
    func tiltCamera(by points: Double, screenHeight: Double) {
        var camera = freeCamera ?? detached()
        camera.tilt(by: points, screenHeight: screenHeight)
        freeCamera = camera
        place()
    }

    /// Back on the snake, as the match has it.
    func followSnake() {
        freeCamera = nil
        place()
    }

    /// The camera where it is now, taken off the snake.
    private func detached() -> FreeCamera {
        let view = game.world.configurations.view
        return FreeCamera(focus: focus, distance: distance, pitch: view.cameraPitch,
                          nearest: view.freeCameraNearest, farthest: view.freeCameraFarthest,
                          lowestPitch: view.freeCameraLowestPitch, highestPitch: view.freeCameraHighestPitch,
                          arena: game.world.plan.bounds)
    }

    /// Another match in the same arena (FR-VIEW-190). The scene is kept and brought
    /// back into line with the new match rather than built again: every entity in it
    /// belongs to the arena, which the match does not change, and the bodies are
    /// addressed by what they draw — so a bot that was eaten stands up again and a
    /// tail grown long is drawn short.
    func restart() {
        game = game.restarted()
        focus = game.snake.head
        place()
    }

    /// One frame: the world moves, then what is drawn catches up with it.
    func step(seconds: Double) {
        // A frame long enough to be a stall is not a frame the snake should cross the
        // room in; the model refuses to pass through walls whatever it is given, and
        // this keeps the picture from lurching as well.
        game.advance(seconds: min(seconds, Frame.longest))
        place()
    }

    private func place() {
        canEat = Game.preyWithinReach(of: game.snake.head, among: game.bots,
                                      tuning: game.world.configurations.tuning) != nil
        SnakeEntity.update(snakeEntity, from: game.snake,
                           radius: game.world.configurations.tuning.bodyRadius)
        BotEntity.update(botEntities, from: game.bots)
        // Every shot still alive is drawn where it went (FR-VIEW-170).
        ShotEntity.update(shotEntities, from: game.shots)
        // A meal under way is drawn going in (FR-VIEW-100). What is left of the prey
        // is measured by whatever ends that meal: live prey by the health it has
        // left, a body by the time it has left.
        if let meal = game.eating, let left = remaining(of: meal) {
            BotEntity.swallow(botEntities, prey: meal.prey, head: game.snake.head, left: left)
        }
        focus = SceneView.focus(keeping: game.snake.head,
                                inside: game.world.configurations.view.centralRegion,
                                from: focus,
                                distance: distance,
                                fieldOfViewDegrees: fieldOfView,
                                aspect: aspect,
                                within: game.world.plan.bounds)
        // Where the camera looks: after the head, or where the user left it. The
        // following goes on underneath either way, so that the camera comes back to
        // where the match would have had it.
        SceneView.place(camera, lookingAt: freeCamera?.focus ?? focus,
                        pitchDegrees: freeCamera?.pitch ?? game.world.configurations.view.cameraPitch,
                        yawDegrees: freeCamera?.yaw ?? .zero,
                        distance: freeCamera?.distance ?? distance)
        // After the camera has moved, not before: what hides the snake is judged from
        // where the camera is now (FR-VIEW-150), and the floor above the head is a lid
        // wherever the camera stands (FR-VIEW-140).
        let eye = SIMD3(Double(camera.position.x), Double(camera.position.y), Double(camera.position.z))
        // Floors above fade whole; what stands in the way of the snake, or near the
        // head, is cut open where it matters and stands everywhere else (ADR-0020).
        seeThrough.show(headOn: game.snake.floor, head: game.snake.head,
                        surface: Double(game.snake.floor) * game.world.plan.floorHeight,
                        snake: [game.snake.head] + game.snake.tail,
                        from: eye,
                        // The body's own radius, because a sphere half behind a wall
                        // is behind it, plus what the configuration adds so that the
                        // fade starts a little early.
                        margin: game.world.configurations.tuning.bodyRadius
                            + game.world.configurations.view.seeThroughMargin,
                        visibilityRadius: game.world.configurations.view.visibilityRadius)
    }

    /// How much of the prey is still outside the snake: one at the first bite, zero
    /// at the last. A body has no health to count down — it is eaten in a duration —
    /// so counting its health would draw the whole meal as already swallowed.
    private func remaining(of meal: Eating) -> Double? {
        guard meal.alive else {
            let whole = game.world.configurations.snake.bodyEatingDuration
            return whole > .zero ? (meal.left ?? .zero) / whole : .zero
        }
        guard let prey = game.bots.first(where: { $0.id == meal.prey }),
              let entry = game.world.configurations.bot.archetypes[prey.archetype.rawValue],
              entry.health > .zero else { return nil }
        return prey.health / entry.health
    }
}
