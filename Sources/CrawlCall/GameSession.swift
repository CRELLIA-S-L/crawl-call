// What runs while a match is on: the logic advanced once per frame, the entities moved
// to where it says, and the camera kept on the head.
//
// The frame's own delta is what advances the world. It is not what the frame rate is
// measured with — `specs/50-verification.md` says why, and the two are different
// questions asked of the same number.
//
// implements: FR-VIEW-020, FR-VIEW-030, FR-VIEW-060, FR-VIEW-100, FR-VIEW-140, FR-VIEW-150, FR-VIEW-155, FR-VIEW-160, FR-VIEW-170, FR-VIEW-180, FR-VIEW-190
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
        game.advance(seconds: min(seconds, 1.0 / 20))
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
                                within: game.world.plan.bounds)
        SceneView.place(camera, lookingAt: focus, pitchDegrees: game.world.configurations.view.cameraPitch,
                        distance: distance)
        // After the camera has moved, not before: what hides the snake is judged from
        // where the camera is now (FR-VIEW-150), and the floor above the head is a lid
        // wherever the camera stands (FR-VIEW-140).
        let eye = SIMD3(Double(camera.position.x), Double(camera.position.y), Double(camera.position.z))
        // The ground around the head goes in beside the body itself: what hides where
        // the snake is going is as much in the way as what hides the snake
        // (FR-VIEW-155).
        let window = SeeThrough.window(around: game.snake.head, floor: game.snake.floor,
                                       floorHeight: game.world.plan.floorHeight,
                                       radius: game.world.configurations.view.visibilityRadius,
                                       cellSize: game.world.configurations.tuning.navigationGraphCellSize,
                                       in: game.world.graph)
        seeThrough.show(headOn: game.snake.floor,
                        snake: [game.snake.head] + game.snake.tail,
                        window: window,
                        from: eye,
                        // The body's own radius, because a sphere half behind a wall
                        // is behind it, plus what the configuration adds so that the
                        // fade starts a little early.
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
