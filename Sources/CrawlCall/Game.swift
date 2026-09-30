// The match as the game logic sees it: a world read at start, a snake in it, and a
// held direction that comes from an intent and from nothing else.
//
// FR-VIEW-030 is the reason this type takes `Intent` rather than a gesture, a touch
// or a key: the schemes produce intents (FR-VIEW-050), the logic consumes them, and
// neither knows about the other.
//
// implements: FR-SNAKE-270, FR-SNAKE-280, FR-VIEW-160, FR-BOT-060, FR-BOT-320, FR-BOT-050, FR-BOT-220, FR-BOT-230, FR-BOT-240, FR-BOT-260, FR-BOT-310, FR-VIEW-030, FR-VIEW-170, FR-VIEW-190, FR-SNAKE-010, FR-SNAKE-030, FR-SNAKE-290, FR-BOT-020, FR-BOT-150, FR-BOT-170, FR-BOT-380, FR-SCORE-130, FR-SCORE-070, FR-BOT-180, FR-SNAKE-060, FR-SNAKE-070, FR-SNAKE-090, FR-SCORE-140, FR-SCORE-150, INV-BOT-010, FR-VIEW-230, FR-TOOL-230, FR-MAP-150, FR-MAP-180, FR-MAP-170, FR-SNAKE-220
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
    /// What happened to the bots that will not wait for their turn (FR-BOT-170), and
    /// the bots waiting for the slot it gives them.
    private var interrupts = Interrupts()
    private(set) var interrupted: [Int: Interrupt] = [:]
    /// What each squad knows of the snake, and what is on its way to raising it
    /// (FR-SCORE-130).
    private(set) var stealth = Stealth()
    /// Seconds of the match played: when a sighting was made (ADR-0032).
    private(set) var elapsed: Double = .zero
    /// When the squads last passed on what they had seen (FR-BOT-310).
    private var lastShared = -Double.infinity
    /// Which module stands in each cell, for what the bots see of the map (FR-BOT-230).
    private let modules: [NavigationGraph.Node: String]
    /// The meal under way, if there is one (FR-SNAKE-090).
    private(set) var eating: Eating?
    /// The lunge under way, if there is one (FR-SNAKE-270).
    private(set) var lunge: Lunge?
    /// The coil round a living bot under way, if there is one (FR-SNAKE-280).
    private(set) var coil: Coil?
    /// When the last lunge ended, on its prey or not, in the match's seconds: what the
    /// drawing squashes the head by for a moment after (FR-VIEW-310).
    private(set) var landedAt: Double?
    /// The shots still being drawn, each with what is left of its time (FR-VIEW-170).
    private(set) var shots: [Shot] = []

    /// How the match ended, or nil while it is still being played.
    private(set) var outcome: Outcome?

    init(world: World, start: NavigationGraph.Node) {
        self.world = world
        self.start = start
        self.surfaces = Surfaces(graph: world.graph, kit: world.kit, tuning: world.configurations.tuning, map: world.map)
        self.modules = Perception.modules(of: world.map)
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
            lungeAtWhatIsWithinReach()
        }
    }

    /// Begins a meal on the bot named, if it is there, nothing else is already being
    /// eaten, and the snake is not in the air off a ledge: a meal holds the head where
    /// it is (FR-SNAKE-090), and one begun mid-drop would hold it there, in the air
    /// (FR-SNAKE-220). Whether the snake may begin — reach, intent — is settled by the
    /// caller; this is the act itself.
    mutating func begin(eating id: Int) {
        guard eating == nil, snake.drop == nil, let prey = bots.first(where: { $0.id == id }) else { return }
        eating = Eating(prey: id, alive: prey.health > .zero, archetype: prey.archetype,
                        configuration: world.configurations.snake)
    }

    /// How near the head has to be to a bot to have reached it, where a lunge ends in a
    /// meal (FR-SNAKE-270): the head's own body plus half a cell — touching, give or
    /// take the grid. No requirement gives a number for it; this one is said out loud
    /// rather than passed off as a rule, and it moves into the tuning configuration the
    /// day somebody wants to feel it out.
    static func biteReach(_ tuning: TuningConfiguration) -> Double {
        tuning.bodyRadius + tuning.navigationGraphCellSize * Geometry.half
    }

    /// The nearest bot within `reach` metres of the head: what the eat intent lunges
    /// at, with the lunge reach (FR-SNAKE-270).
    static func preyWithinReach(of head: SIMD3<Double>, among bots: [Bot], reach: Double) -> Int? {
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

    /// What the bots come to know this frame (ADR-0032): the snake and the enemy they
    /// see (FR-BOT-050, FR-BOT-240), the map round them once a deliberation period
    /// (FR-BOT-230), what their squad tells them after its delay (FR-BOT-310), less
    /// what they have forgotten (FR-BOT-260).
    private mutating func learn(snake body: [SIMD3<Double>]) {
        let configuration = world.configurations.bot
        Perception.notice(&bots, snake: body, plan: world.plan, configuration: configuration, now: elapsed)
        Perception.noticeEnemies(&bots, plan: world.plan, configuration: configuration, now: elapsed)
        for index in bots.indices
        where bots[index].isAlive && elapsed - bots[index].lastLook >= configuration.deliberationPeriod {
            let previous = bots[index].lastLook
            Perception.lookAtMap(&bots[index], world: world, modules: modules, now: elapsed)
            // Every bot looks in the first frame; from then on each takes its turn
            // across the period, so that the looks are spread over frames rather than
            // all falling in one (ADR-0043). A turn is kept by the bot's own schedule,
            // whole periods on from its last, and not by the frame it fell in: a long
            // frame makes several bots due at once, and counted from that frame they
            // would look together from then on.
            let period = configuration.deliberationPeriod
            bots[index].lastLook = previous == -.infinity
                ? elapsed - period * Double(index) / Double(bots.count)
                : previous + period * ((elapsed - previous) / period).rounded(.down)
        }
        // Passed on once a deliberation period rather than every frame: a record is
        // hundreds of cells, and the delay it waits out is seconds.
        if elapsed - lastShared >= configuration.deliberationPeriod {
            Execution.share(&bots, now: elapsed, configuration: configuration)
            lastShared = elapsed
        }
        for index in bots.indices {
            bots[index].knowledge.forget(at: elapsed, snakeAfter: configuration.snakeForgottenAfter,
                                         enemyAfter: configuration.enemyForgottenAfter)
        }
    }

    /// Whether the eat intent would begin a lunge now (FR-SNAKE-270): no meal and no
    /// lunge under way, the snake not in the air off a ledge (FR-SNAKE-220), and a bot
    /// within the lunge reach. What the eat button shows (FR-VIEW-160).
    var canLunge: Bool { lungePrey() != nil }

    private func lungePrey() -> Int? {
        guard eating == nil, lunge == nil, coil == nil, snake.drop == nil else { return nil }
        return Game.preyWithinReach(of: snake.head, among: bots, reach: world.configurations.snake.lunge.reach)
    }

    private mutating func lungeAtWhatIsWithinReach() {
        guard let prey = lungePrey() else { return }
        lunge = Lunge(prey: prey, configuration: world.configurations.snake.lunge)
    }

    /// One frame of a lunge (FR-SNAKE-270): the head held through the wind-up, then
    /// sent at the prey where it is now, by the snake's own movement rules. It ends in
    /// a meal where the head reaches the prey, and where it does not in its time, or
    /// goes off a ledge, or the prey is gone, it ends where the head is.
    private mutating func advanceLunge(seconds: Double) {
        guard var current = lunge, let prey = bots.first(where: { $0.id == current.prey }) else {
            endLunge()
            return
        }
        let result = Lunge.step(&current, snake: &snake, prey: prey.position, seconds: seconds,
                                bite: Game.biteReach(world.configurations.tuning), over: surfaces)
        lunge = current
        switch result {
        case .going: break
        case .reached:
            endLunge()
            // A living bot is coiled round first (FR-SNAKE-280); a body is eaten at once.
            if prey.isAlive { beginCoil(round: prey) } else { begin(eating: prey.id) }
        case .missed:
            endLunge()
        }
    }

    private mutating func beginCoil(round prey: Bot) {
        let configuration = world.configurations.snake.coil
        let radius = world.configurations.tuning.bodyRadius * Geometry.bothSides
        let room = Coil.room(around: prey.position, floor: prey.floor, radius: radius,
                             reach: configuration.shoveReach, over: surfaces)
        coil = Coil(prey: prey.id, at: prey.position, head: snake.head, radius: radius, room: room,
                    configuration: configuration)
    }

    /// One frame of a coil (FR-SNAKE-280): the bot shoved towards where the ring fits
    /// round it, and the head sent on round it. Once round, the meal begins; a bot that
    /// is gone meanwhile ends it with nothing.
    private mutating func advanceCoil(seconds: Double) {
        guard var current = coil, let index = bots.firstIndex(where: { $0.id == current.prey }) else {
            coil = nil
            return
        }
        Coil.step(&current, snake: &snake, prey: &bots[index].position, seconds: seconds,
                  shoveSpeed: world.configurations.snake.coil.shoveSpeed, over: surfaces)
        coil = current
        if current.isDone {
            coil = nil
            begin(eating: current.prey)
        }
    }

    private mutating func endLunge() {
        lunge = nil
        landedAt = elapsed
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
        let before = Interrupts.glance(bots)
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
        } else if coil != nil {
            // FR-SNAKE-280: the head goes round the bot, and the stick is not heard.
            advanceCoil(seconds: seconds)
        } else if lunge != nil {
            // FR-SNAKE-270: the head goes where the lunge sends it, and the stick is
            // not heard until it is over.
            advanceLunge(seconds: seconds)
        } else {
            // Steered: on an arc no tighter than the turning radius (FR-SNAKE-290).
            snake.advance(direction: held,
                          speed: world.configurations.snake.baseSpeed,
                          seconds: seconds,
                          over: surfaces,
                          turningRadius: world.configurations.snake.turningRadius)
        }

        elapsed += seconds
        let body = [snake.head] + snake.tail
        learn(snake: body)
        // Aged before this frame's shots are added, so that a shot fired now is drawn
        // for its whole period and not for that period less one frame.
        shots = shots.compactMap { shot in
            var aged = shot
            aged.left -= seconds
            return aged.left > .zero ? aged : nil
        }
        let steps = slots.steps(after: seconds, period: world.configurations.bot.deliberationPeriod)
        let clock = ContinuousClock()
        // A bot something happened to thinks in this frame, whether or not the clock
        // gives one a step (FR-BOT-170): a step of its own when the clock gives none,
        // the front of the queue when it does.
        let alone = steps == .zero && !interrupted.isEmpty
        for _ in Int.zero..<(alone ? 1 : steps) {
            // Only the living are given a turn to think (FR-BOT-320).
            let living = bots.filter(\.isAlive)
            let ahead = Set(interrupted.keys)
            let holders = alone
                ? slots.next(among: living.filter { ahead.contains($0.id) }, snake: body,
                             configuration: world.configurations.bot)
                : slots.next(among: living, snake: body, configuration: world.configurations.bot, ahead: ahead)
            let served = ahead.intersection(holders)
            for id in served { interrupted[id] = nil }
            let deciding = clock.now
            let known = stealth
            let volley = Execution.deliberate(&bots, slots: holders, world: world, now: elapsed, interrupted: served,
                                              awareness: { known.of($0) })
            report.deliberationTime += clock.now - deciding
            report.deliberations += holders.count
            shots += volley.shots
            if volley.damage > .zero {
                report.hits += volley.hits
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
        // Whatever is being eaten, or coiled round to be (FR-SNAKE-280), stays where it
        // is: it resists by shooting, not by walking out of the snake's mouth.
        Execution.walk(&bots, seconds: seconds, world: world,
                       routeOrder: slots.order(among: bots, snake: body,
                                               configuration: world.configurations.bot),
                       holding: eating?.prey ?? coil?.prey, now: elapsed)
        // Found after the frame's shots and meals, and served in the next frame.
        for (id, reason) in interrupts.find(before: before, after: bots, meal: eating?.prey ?? coil?.prey,
                                            plan: world.plan, configuration: world.configurations.bot, now: elapsed)
        where interrupted[id] == nil {
            interrupted[id] = reason
        }
        stealth.step(before: before, after: bots, prey: eating?.prey ?? coil?.prey, plan: world.plan,
                     bot: world.configurations.bot, scoring: world.configurations.scoring, now: elapsed)
        // A bot that died or was eaten before its slot came has nothing left to decide.
        interrupted = interrupted.filter { entry in bots.contains { $0.id == entry.key && $0.isAlive } }

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
