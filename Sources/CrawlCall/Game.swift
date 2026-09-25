// The match as the game logic sees it: a world read at start, a snake in it, and a
// held direction that comes from an intent and from nothing else.
//
// FR-VIEW-030 is the reason this type takes `Intent` rather than a gesture, a touch
// or a key: the schemes produce intents (FR-VIEW-050), the logic consumes them, and
// neither knows about the other.
//
// implements: FR-VIEW-030, FR-VIEW-170, FR-VIEW-190, FR-SNAKE-010, FR-SNAKE-030, FR-BOT-020, FR-BOT-150, FR-SNAKE-060, FR-SNAKE-070, FR-SNAKE-090, FR-SCORE-140, FR-SCORE-150, INV-BOT-010, FR-VIEW-230, FR-TOOL-230, FR-MAP-150, FR-MAP-180, FR-MAP-170
import Foundation

struct Game {
    /// The two ways a match can be over, and the only two there are: no timer and no
    /// score threshold ends one (FR-SCORE-140, FR-SCORE-150).
    enum Outcome: Equatable {
        /// The snake was shot with nothing left to lose (FR-SNAKE-210).
        case snakeDied
        /// Nothing is left alive to hunt.
        case arenaEmpty
    }

    let world: World
    /// Where this match began, kept so that another one can begin in the same place
    /// (FR-VIEW-190).
    let start: NavigationGraph.Node
    private(set) var snake: Snake
    /// Both squads, spawned where the match begins (FR-BOT-020).
    private(set) var bots: [Bot]
    /// What the player is holding now, on the map plane. Zero when nothing is held.
    private(set) var held: SIMD2<Double> = .zero
    private(set) var isPaused = false
    /// Whether the player has steered this match yet: a match nobody has steered has
    /// nothing to lose to a change of the window, and is not paused by one (FR-VIEW-230).
    private(set) var hasBeenSteered = false
    private let surfaces: Surfaces

    /// The height of the ground the head is on: its cell's surface, which on a flight
    /// is its step's (FR-MAP-150) — not the head's own height, which a climb leaves
    /// short of it for a moment.
    var snakeSurface: Double {
        surfaces.height(of: surfaces.cell(of: snake.head, floor: snake.floor))
    }
    /// The bots' own clock, which the frame rate does not set (FR-BOT-150).
    private var slots = Slots()
    /// The meal under way, if there is one (FR-SNAKE-090).
    private(set) var eating: Eating?
    /// The shots still being drawn, each with what is left of its time (FR-VIEW-170).
    private(set) var shots: [Shot] = []

    /// How the match ended, or nil while it is still being played.
    private(set) var outcome: Outcome?

    init(world: World, start: NavigationGraph.Node) {
        self.world = world
        self.start = start
        self.surfaces = Surfaces(graph: world.graph, kit: world.kit, tuning: world.configurations.tuning, map: world.map)
        let cell = world.configurations.tuning.navigationGraphCellSize
        // The start cell's centre, moved out of any wall the body would overlap there:
        // the body is wider than a cell, and a head set down in the corner of the
        // arena would begin the match inside two walls (FR-SNAKE-010, ADR-0021).
        let centre = world.graph.centre(of: start, cellSize: cell, floorHeight: world.kit.floorHeight)
        self.snake = Snake(head: surfaces.clear(centre, feet: centre.y),
                           floor: start.floor,
                           segments: world.configurations.snake.startingSegmentCount,
                           segmentSpacing: world.configurations.tuning.bodyRadius * Motion.widthInRadii)
        self.bots = Squads.spawn(in: world, snakeStart: start)
    }

    /// Everything the player can ask for arrives here, and only here.
    mutating func apply(_ intent: Intent) {
        switch intent {
        case .move(let direction):
            held = direction
            if direction != .zero { hasBeenSteered = true }
        case .pause:
            isPaused.toggle()
        case .useAbility:
            // Abilities hang on segments and arrive with the eating layer; the intent
            // exists because IF-VIEW-010 says the input layer delivers it, and the
            // logic ignoring it today is honest about that.
            break
        case .point:
            // Used by the debug viewer's teleport (FR-TOOL-100), not by a match.
            break
        case .eat:
            beginEatingWhatTheHeadHasReached()
        }
    }

    /// Begins a meal on the bot named, if it is there and nothing else is already
    /// being eaten. Whether the snake may begin — reach, intent — is settled by the
    /// caller; this is the act itself.
    mutating func begin(eating id: Int) {
        guard eating == nil, let prey = bots.first(where: { $0.id == id }) else { return }
        eating = Eating(prey: id, alive: prey.health > .zero, archetype: prey.archetype,
                        configuration: world.configurations.snake)
    }

    /// What the eat intent means: the nearest bot the head has actually reached.
    ///
    /// Reach is the head's own body plus half a cell — touching, give or take the
    /// grid. No requirement gives a number for it; this one is said out loud rather
    /// than passed off as a rule, and it moves into the tuning configuration the day
    /// somebody wants to feel it out.
    static func preyWithinReach(of head: SIMD3<Double>, among bots: [Bot],
                                tuning: TuningConfiguration) -> Int? {
        let reach = tuning.bodyRadius + tuning.navigationGraphCellSize * Geometry.half
        var nearest: Int?
        var best = Double.infinity
        for bot in bots {
            let metres = Perception.metres(head, bot.position)
            guard metres <= reach else { continue }
            // Ties go to the lower id, so that a match is the same twice over.
            if metres < best || (metres == best && bot.id < (nearest ?? .max)) {
                best = metres
                nearest = bot.id
            }
        }
        return nearest
    }

    private mutating func beginEatingWhatTheHeadHasReached() {
        guard let prey = Game.preyWithinReach(of: snake.head, among: bots,
                                              tuning: world.configurations.tuning) else { return }
        begin(eating: prey)
    }

    /// What one step did that the frame record counts (FR-TOOL-230): how many bots
    /// deliberated and how long that took, and how many volleys hit the snake.
    struct StepReport: Equatable {
        var deliberations = Int.zero
        var deliberationTime = Duration.zero
        var hits = Int.zero
    }

    /// One frame: a meal under way is chewed and nothing else of the snake moves, or
    /// the snake moves where it is steered; either way the bots see what there is to
    /// see, whoever holds a slot decides, and every bot walks whatever it decided.
    @discardableResult
    mutating func advance(seconds: Double) -> StepReport {
        var report = StepReport()
        // A match that is over stays where it stopped: the arena is still drawn, and
        // nothing in it moves again until a new one is started (FR-VIEW-190).
        guard !isPaused, outcome == nil else { return report }
        if eating != nil {
            // FR-SNAKE-090: the head stays where it is until the meal is over, which
            // is what makes eating a choice with a price. Live prey is chewed through
            // rather than waited out, and it shoots back while it has anything left
            // (FR-SNAKE-100).
            let bite = eating!.advance(seconds: seconds)
            if bite > .zero, let index = bots.firstIndex(where: { $0.id == eating!.prey }) {
                bots[index].health = max(.zero, bots[index].health - bite)
                if bots[index].health == .zero { finishEating() }
            } else if eating?.isFinished == true || !bots.contains(where: { $0.id == eating!.prey }) {
                finishEating()
            }
        } else {
            snake.advance(direction: held,
                          speed: world.configurations.snake.baseSpeed,
                          seconds: seconds,
                          over: surfaces)
        }

        let body = [snake.head] + snake.tail
        Perception.notice(&bots, snake: body, plan: world.plan,
                          configuration: world.configurations.bot)
        // Aged before this frame's shots are added, so that a shot fired now is drawn
        // for its whole period and not for that period less one frame.
        shots = shots.compactMap { shot in
            var aged = shot
            aged.left -= seconds
            return aged.left > .zero ? aged : nil
        }
        let steps = slots.steps(after: seconds, period: world.configurations.bot.deliberationPeriod)
        let clock = ContinuousClock()
        for _ in Int.zero..<steps {
            let holders = slots.next(among: bots, snake: body, configuration: world.configurations.bot)
            let deciding = clock.now
            let volley = Execution.deliberate(&bots, slots: holders, snake: body, world: world)
            report.deliberationTime += clock.now - deciding
            report.deliberations += holders.count
            shots += volley.shots
            if volley.damage > .zero {
                report.hits += volley.shots.count
                snake.take(damage: volley.damage, perSegment: world.configurations.snake.damagePerSegment)
                // FR-SCORE-140. Checked inside the loop rather than after it: the
                // remaining deliberation steps of a long frame belong to a match that
                // is already over.
                if !snake.isAlive {
                    outcome = .snakeDied
                    return report
                }
            }
        }
        // Whatever is being eaten stays where it is: it resists by shooting, not by
        // walking out of the snake's mouth.
        Execution.walk(&bots, seconds: seconds, world: world,
                       routeOrder: slots.order(among: bots, snake: body,
                                               configuration: world.configurations.bot),
                       holding: eating?.prey)

        // FR-SCORE-150: prey is finite and there are no reinforcements, so the arena
        // running out of living bots is an end of its own. Living, not present: a bot
        // is only removed when the snake has finished eating it, and the day bodies
        // stay behind (INV-SCORE-020) the match must still end when the last one that
        // could shoot back is gone.
        if !bots.contains(where: { $0.health > .zero }) { outcome = .arenaEmpty }
        return report
    }

    /// The meal is over: the bot is gone from the map — squads do not remove bodies,
    /// the snake does (concept §6.2) — and the tail is longer by what its archetype
    /// is worth (FR-SNAKE-060).
    private mutating func finishEating() {
        guard let meal = eating else { return }
        eating = nil
        bots.removeAll { $0.id == meal.prey }
        snake.grow(by: world.configurations.snake.segmentsPerArchetype[meal.archetype.rawValue] ?? .zero)
    }

    /// Another match in the same arena, from the same starting cell: the world is
    /// read once at start-up (IF-SNAKE-010 and its neighbours) and nothing in it is
    /// spent by a match, so a new one is a new `Game` over the same value
    /// (FR-VIEW-190).
    /// Another match in the same world, from a start chosen again (FR-MAP-180).
    func restarted() -> Game { Game(world: world, start: Self.start(in: world) ?? start) }

    /// Where a match starts: one of the spawn points the map names, chosen at random
    /// (FR-MAP-180). A map with none — one read for a test rather than played, since
    /// the launch refuses such a map (FR-MAP-190) — starts in floor 0's first walkable
    /// cell, or the lowest floor's where it has no floor 0.
    static func start<Chooser: RandomNumberGenerator>(in world: World, using chooser: inout Chooser) -> NavigationGraph.Node? {
        let spawns = world.map.spawns.map { NavigationGraph.Node(floor: $0.floor, x: $0.x, z: $0.z) }
            .filter(world.graph.isWalkable)
        if let chosen = spawns.randomElement(using: &chooser) { return chosen }
        let levels = world.map.floors.map(\.level)
        let ground = levels.contains(.zero) ? .zero : levels.min()
        return world.graph.nodes.filter { $0.floor == ground }.min { a, b in (a.z, a.x) < (b.z, b.x) }
    }

    static func start(in world: World) -> NavigationGraph.Node? {
        var chooser = SystemRandomNumberGenerator()
        return start(in: world, using: &chooser)
    }
}
