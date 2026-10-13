// What runs while a match is on: the logic advanced once per frame, the entities moved
// to where it says, and the camera kept on the head.
//
// The frame's own delta is what advances the world. It is not what the frame rate is
// measured with — `specs/50-verification.md` says why, and the two are different
// questions asked of the same number.
//
// file implements: FR-VIEW-350, FR-VIEW-360, FR-TOOL-070, FR-VIEW-020, FR-VIEW-030, FR-VIEW-060, FR-VIEW-100, FR-VIEW-140, FR-VIEW-150, FR-VIEW-155, FR-VIEW-160, FR-VIEW-170, FR-VIEW-250, FR-VIEW-190, FR-VIEW-230, FR-VIEW-210, FR-TOOL-230, FR-TOOL-240, FR-GREENHOLM-030, FR-TOOL-260, FR-TOOL-270, FR-SNAKE-220, FR-VIEW-280, FR-VIEW-290, FR-VIEW-310, FR-VIEW-320, FR-VIEW-330
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
    private let blastEntities: Entity
    private let camera: Entity
    private var seeThrough: SeeThrough
    /// Where the match camera looks (FR-VIEW-020); read by the scenery, whose birds
    /// cross where the player is looking (FR-GREENHOLM-030).
    private(set) var focus: SIMD3<Double>
    /// How fast the focus is moving across the ground, in metres a second: the camera's
    /// spring carries it from frame to frame (FR-VIEW-020).
    private var focusVelocity = SIMD2<Double>.zero
    /// How far the head is reared over a living bot it swallows (FR-VIEW-320).
    private var swallowPose = SwallowPose()
    private let distance: Double
    private let fieldOfView: Double
    /// The camera the user has taken off the snake in debug mode (FR-TOOL-070), or nil
    /// while it follows the head (FR-VIEW-020).
    private(set) var freeCamera: FreeCamera?
    /// Debug mode's see-through switches (FR-TOOL-260, FR-TOOL-270). A match starts
    /// with the cut along the line of sight and without the window around the head,
    /// which is off until it has been compared on the phone (Q-260), and with no tint.
    var seeThroughSwitches = SeeThrough.Switches(line: SeeThroughAtStart.line, window: SeeThroughAtStart.headWindow)

    init(game: Game, snakeEntity: Entity, botEntities: Entity, shotEntities: Entity,
         blastEntities: Entity, camera: Entity, seeThrough: SeeThrough, distance: Double,
         fieldOfView: Double) {
        self.game = game
        self.snakeEntity = snakeEntity
        self.botEntities = botEntities
        self.shotEntities = shotEntities
        self.blastEntities = blastEntities
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
        recorder?.note(.matchBegan)
        eatingAtLastFrame = false
        digestion = Digestion()
        gaits = [:]
        botsAt = [:]
        swallowPose = SwallowPose()
        focus = game.snake.head
        place()
    }

    /// Where the frame record goes when the launch switched it on (FR-TOOL-230); nil
    /// otherwise, and then nothing is timed. A recorder given to a session begins its
    /// match in the record.
    var recorder: FrameRecorder? {
        didSet { recorder?.note(.matchBegan) }
    }
    /// Whether a meal was under way when the last frame was recorded: a meal is asked
    /// for between frames, so its beginning is seen by comparing frames.
    private var eatingAtLastFrame = false
    /// The meals passing along the snake's body, as the screen shows them (FR-VIEW-280).
    private var digestion = Digestion()
    /// Each bot's walk as the screen shows it, and where it stood a frame ago
    /// (FR-VIEW-290).
    private var gaits: [Int: Gait] = [:]
    private var botsAt: [Int: SIMD3<Double>] = [:]

    /// One frame: the world moves, then what is drawn catches up with it. `seconds` is
    /// the interval since the last frame, as the renderer measured it.
    func step(seconds: Double) {
        let clock = ContinuousClock()
        let wasOver = game.outcome != nil
        let stepping = clock.now
        // A frame long enough to be a stall is not a frame the snake should cross the
        // room in; the model refuses to pass through walls whatever it is given, and
        // this keeps the picture from lurching as well.
        let report = game.advance(seconds: min(seconds, Frame.longest))
        // A meal passes along the body on the match's clock: not while it is paused or
        // over (FR-VIEW-280).
        if !game.isPaused, game.outcome == nil {
            digestion.step(seconds: min(seconds, Frame.longest),
                           swallowed: game.eating.flatMap(remaining(of:)).map { Fraction.whole - $0 },
                           length: Double(game.snake.tail.count) * game.snake.segmentSpacing)
            for bot in game.bots {
                let was = botsAt[bot.id] ?? bot.position
                let across = bot.position.x - was.x, along = bot.position.z - was.z
                let moved = (across * across + along * along).squareRoot()
                gaits[bot.id, default: Gait()].step(moved: moved, seconds: min(seconds, Frame.longest))
                botsAt[bot.id] = bot.position
            }
        }
        let stepTime = clock.now - stepping
        let placed = place(seconds: min(seconds, Frame.longest))
        guard let recorder else { return }

        var frame = FrameRecord.Frame()
        frame[.step] = FrameRecorder.milliseconds(stepTime)
        frame[.deliberation] = FrameRecorder.milliseconds(report.deliberationTime)
        frame[.seeThrough] = FrameRecorder.milliseconds(placed.seeThroughTime)
        frame[.draw] = FrameRecorder.milliseconds(placed.drawTime)
        frame.add(.deliberation, times: report.deliberations)
        frame.add(.hit, times: report.hits)
        frame.add(.firstHole, times: placed.look.firstHoles)
        frame.add(.lookChanged, times: placed.look.lookChanges)
        let eating = game.eating != nil
        let traffic = game.takeCommanderTraffic()
        if traffic.calls > .zero { frame.add(.commanderCalled, times: traffic.calls) }
        if traffic.answers > .zero { frame.add(.commanderAnswered, times: traffic.answers) }
        if traffic.misses > .zero { frame.add(.commanderFailed, times: traffic.misses) }
        if eating && !eatingAtLastFrame { frame.add(.mealBegan) }
        if !eating && eatingAtLastFrame { frame.add(.mealEnded) }
        eatingAtLastFrame = eating
        let ended = !wasOver && game.outcome != nil
        if ended { frame.add(.matchEnded) }
        recorder.add(interval: seconds, frame)
        // FR-TOOL-240: the end of a match is one of the moments the record is written.
        if ended { recorder.writeInBackground() }
    }

    /// What drawing a frame cost: the see-through check apart from the rest, and what
    /// the check changed (FR-TOOL-230).
    struct Placed {
        var seeThroughTime = Duration.zero
        var drawTime = Duration.zero
        var look = SeeThrough.Report()
    }

    @discardableResult
    /// What is drawn brought up to the match. `seconds` is the frame's, for what eases
    /// in over time; nil puts the camera where it should be at once — a match begun,
    /// resumed or restarted.
    private func place(seconds: Double? = nil) -> Placed {
        let clock = ContinuousClock()
        let drawing = clock.now
        // Lit exactly when a touch would lunge (FR-VIEW-160, FR-SNAKE-270): nothing
        // under way, not in the air off a ledge (FR-SNAKE-220), a bot within reach.
        canEat = game.canLunge
        // Reared over a living bot being eaten, and down again after it (FR-VIEW-320).
        let figureHeight = game.world.configurations.bot.figureHeight
        let alive = game.eating.flatMap { meal in
            meal.alive ? game.bots.first { $0.id == meal.prey }?.position : nil
        }
        // Moved on only by a frame's time: the free camera's gestures place the scene too,
        // and a meal's head stays as it is under them.
        if let seconds {
            let gone = game.eating.flatMap { remaining(of: $0) }.map { Fraction.whole - $0 } ?? .zero
            swallowPose.step(seconds: seconds, eatingAlive: alive, height: figureHeight, gone: gone)
        }
        // The pose is worked out from plain values rather than from the match: a drawing
        // reads what it is given and never reaches back into the game (FR-VIEW-030, ADR-0073).
        let prey = game.lunge.flatMap { lunge in game.bots.first { $0.id == lunge.prey }?.position }
        let lungePose = LungePose.of(lunge: game.lunge,
                                     windUp: game.world.configurations.snake.lunge.windUp, prey: prey,
                                     sinceLanding: game.landedAt.map { game.elapsed - $0 })
        SnakeEntity.update(snakeEntity, from: game.snake,
                           radius: game.world.configurations.tuning.bodyRadius, lumps: digestion.lumps,
                           lunge: lungePose, swallow: swallowPose,
                           sway: SnakeBody.Sway(amplitude: game.world.configurations.view.slither.amplitude,
                                                wavelength: game.world.configurations.view.slither.wavelength,
                                                crawled: game.snake.crawled))
        BotEntity.update(botEntities, from: game.bots, gaits: gaits, eaten: game.eating?.prey,
                         height: game.world.configurations.bot.figureHeight)
        // Every round in flight is drawn where it is (FR-VIEW-170), every grenade where
        // it is while its fuse burns (FR-VIEW-350), and every blast where it went off
        // for the moment it is drawn for (FR-VIEW-360).
        ShotEntity.update(shotEntities, from: game.rounds)
        BlastEntity.update(blastEntities, grenades: game.grenades, blasts: game.blasts)
        // A meal under way is drawn going in (FR-VIEW-100). What is left of the prey
        // is measured by whatever ends that meal: live prey by the health it has
        // left, a body by the time it has left. Live prey is cut away at the mouth of the
        // head coming down over it (FR-VIEW-320); a body is pulled in along the ground.
        if let meal = game.eating, let left = remaining(of: meal) {
            if meal.alive, let feet = alive {
                BotEntity.slurp(botEntities, prey: meal.prey, feet: feet, height: figureHeight, left: left)
            } else {
                BotEntity.swallow(botEntities, prey: meal.prey, head: game.snake.head, left: left)
            }
        }
        // Where the region would have the camera, caught up with over the follow lag
        // rather than at once: a lunge moves the head faster than the eye follows a
        // jump of the whole frame (FR-VIEW-020).
        let target = SceneView.focus(keeping: game.snake.head,
                                     inside: game.world.configurations.view.centralRegion,
                                     from: focus,
                                     distance: distance,
                                     fieldOfViewDegrees: fieldOfView,
                                     aspect: aspect,
                                     within: game.world.plan.bounds)
        if let seconds {
            focus = SceneView.followed(from: focus, velocity: &focusVelocity, to: target, seconds: seconds,
                                       lag: game.world.configurations.view.cameraFollowLag)
        } else {
            focus = target
            focusVelocity = .zero
        }
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
        let seeing = clock.now
        var placed = Placed()
        placed.look = seeThrough.show(headOn: game.snake.floor, head: game.snake.head,
                        surface: game.snakeSurface,
                        snake: [game.snake.head] + game.snake.tail,
                        from: eye,
                        // The body's own radius, because a sphere half behind a wall
                        // is behind it, plus what the configuration adds so that the
                        // fade starts a little early.
                        margin: game.world.configurations.tuning.bodyRadius
                            + game.world.configurations.view.seeThroughMargin,
                        visibilityRadius: game.world.configurations.view.visibilityRadius,
                        switches: seeThroughSwitches)
        let seen = clock.now
        placed.seeThroughTime = seen - seeing
        placed.drawTime = seeing - drawing
        return placed
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
