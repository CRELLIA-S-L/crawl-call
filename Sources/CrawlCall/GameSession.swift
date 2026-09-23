// What runs while a match is on: the logic advanced once per frame, the entities moved
// to where it says, and the camera kept on the head.
//
// The frame's own delta is what advances the world. It is not what the frame rate is
// measured with — `specs/50-verification.md` says why, and the two are different
// questions asked of the same number.
//
// implements: FR-VIEW-020, FR-VIEW-030, FR-VIEW-060, FR-VIEW-100, FR-VIEW-140, FR-VIEW-150, FR-VIEW-160
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
    private let camera: Entity
    private var seeThrough: SeeThrough
    private var focus: SIMD3<Double>
    private let distance: Double
    private let fieldOfView: Double

    init(game: Game, snakeEntity: Entity, botEntities: Entity, camera: Entity, seeThrough: SeeThrough,
         distance: Double, fieldOfView: Double) {
        self.game = game
        self.snakeEntity = snakeEntity
        self.botEntities = botEntities
        self.camera = camera
        self.seeThrough = seeThrough
        self.distance = distance
        self.fieldOfView = fieldOfView
        self.focus = game.snake.head
        place()
    }

    func apply(_ intent: Intent) { game.apply(intent) }

    /// One frame: the world moves, then what is drawn catches up with it.
    func step(seconds: Double) {
        // A frame long enough to be a stall is not a frame the snake should cross the
        // room in; the model refuses to pass through walls whatever it is given, and
        // this keeps the picture from lurching as well.
        game.advance(seconds: min(seconds, 1.0 / 20))
        place()
    }

    private func place() {
        canEat = Game.preyWithinReach(of: game.snake.head, among: game.bots,
                                      tuning: game.world.configurations.tuning) != nil
        SnakeEntity.update(snakeEntity, from: game.snake)
        BotEntity.update(botEntities, from: game.bots)
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
                                within: game.world.plan.bounds)
        SceneView.place(camera, lookingAt: focus, pitchDegrees: game.world.configurations.view.cameraPitch,
                        distance: distance)
        // After the camera has moved, not before: what hides the snake is judged from
        // where the camera is now (FR-VIEW-150), and the floor above the head is a lid
        // wherever the camera stands (FR-VIEW-140).
        let eye = SIMD3(Double(camera.position.x), Double(camera.position.y), Double(camera.position.z))
        // The body's own radius, because a sphere half behind a wall is behind it,
        // plus what the configuration adds so that the fade starts a little early.
        seeThrough.show(headOn: game.snake.floor,
                        snake: [game.snake.head] + game.snake.tail,
                        from: eye,
                        margin: game.world.configurations.tuning.bodyRadius
                            + game.world.configurations.view.seeThroughMargin)
    }

    /// How much of the prey is still outside the snake: one at the first bite, zero
    /// at the last. A body has no health to count down — it is eaten in a duration —
    /// so counting its health would draw the whole meal as already swallowed.
    private func remaining(of meal: Eating) -> Double? {
        guard meal.alive else {
            let whole = game.world.configurations.snake.bodyEatingDuration
            return whole > 0 ? (meal.left ?? 0) / whole : 0
        }
        guard let prey = game.bots.first(where: { $0.id == meal.prey }),
              let entry = game.world.configurations.bot.archetypes[prey.archetype.rawValue],
              entry.health > 0 else { return nil }
        return prey.health / entry.health
    }
}
