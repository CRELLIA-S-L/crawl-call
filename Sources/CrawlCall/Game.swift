// The match as the game logic sees it: a world read at start, a snake in it, and a
// held direction that comes from an intent and from nothing else.
//
// FR-VIEW-030 is the reason this type takes `Intent` rather than a gesture, a touch
// or a key: the schemes produce intents (FR-VIEW-050), the logic consumes them, and
// neither knows about the other.
//
// implements: FR-VIEW-030, FR-VIEW-170, FR-SNAKE-030, FR-BOT-020, FR-BOT-150, FR-SNAKE-060, FR-SNAKE-070, FR-SNAKE-090, INV-BOT-010
import Foundation

struct Game {
    let world: World
    private(set) var snake: Snake
    /// Both squads, spawned where the match begins (FR-BOT-020).
    private(set) var bots: [Bot]
    /// What the player is holding now, on the map plane. Zero when nothing is held.
    private(set) var held: SIMD2<Double> = .zero
    private(set) var isPaused = false
    private let surfaces: Surfaces
    /// The bots' own clock, which the frame rate does not set (FR-BOT-150).
    private var slots = Slots()
    /// The meal under way, if there is one (FR-SNAKE-090).
    private(set) var eating: Eating?
    /// The shots still being drawn, each with what is left of its time (FR-VIEW-170).
    private(set) var shots: [Shot] = []

    init(world: World, start: NavigationGraph.Node) {
        self.world = world
        self.surfaces = Surfaces(graph: world.graph, kit: world.kit, tuning: world.configurations.tuning, map: world.map)
        let cell = world.configurations.tuning.navigationGraphCellSize
        self.snake = Snake(head: SIMD3(Double(start.x) * cell,
                                       Double(start.floor) * world.kit.floorHeight,
                                       Double(start.z) * cell),
                           floor: start.floor,
                           segments: world.configurations.snake.startingSegmentCount,
                           segmentSpacing: world.configurations.tuning.bodyRadius * 2)
        self.bots = Squads.spawn(in: world, snakeStart: start)
    }

    /// Everything the player can ask for arrives here, and only here.
    mutating func apply(_ intent: Intent) {
        switch intent {
        case .move(let direction):
            held = direction
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
        eating = Eating(prey: id, alive: prey.health > 0, archetype: prey.archetype,
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
        let reach = tuning.bodyRadius + tuning.navigationGraphCellSize / 2
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

    /// One frame: a meal under way is chewed and nothing else of the snake moves, or
    /// the snake moves where it is steered; either way the bots see what there is to
    /// see, whoever holds a slot decides, and every bot walks whatever it decided.
    mutating func advance(seconds: Double) {
        guard !isPaused else { return }
        if eating != nil {
            // FR-SNAKE-090: the head stays where it is until the meal is over, which
            // is what makes eating a choice with a price. Live prey is chewed through
            // rather than waited out, and it shoots back while it has anything left
            // (FR-SNAKE-100).
            let bite = eating!.advance(seconds: seconds)
            if bite > 0, let index = bots.firstIndex(where: { $0.id == eating!.prey }) {
                bots[index].health = max(0, bots[index].health - bite)
                if bots[index].health == 0 { finishEating() }
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
            return aged.left > 0 ? aged : nil
        }
        let steps = slots.steps(after: seconds, period: world.configurations.bot.deliberationPeriod)
        for _ in 0..<steps {
            let holders = slots.next(among: bots, snake: body, configuration: world.configurations.bot)
            let volley = Execution.deliberate(&bots, slots: holders, snake: body, world: world)
            shots += volley.shots
            if volley.damage > 0 {
                snake.take(damage: volley.damage, perSegment: world.configurations.snake.damagePerSegment)
            }
        }
        // Whatever is being eaten stays where it is: it resists by shooting, not by
        // walking out of the snake's mouth.
        Execution.walk(&bots, seconds: seconds, world: world,
                       routeOrder: slots.order(among: bots, snake: body,
                                               configuration: world.configurations.bot),
                       holding: eating?.prey)
    }

    /// The meal is over: the bot is gone from the map — squads do not remove bodies,
    /// the snake does (concept §6.2) — and the tail is longer by what its archetype
    /// is worth (FR-SNAKE-060).
    private mutating func finishEating() {
        guard let meal = eating else { return }
        eating = nil
        bots.removeAll { $0.id == meal.prey }
        snake.grow(by: world.configurations.snake.segmentsPerArchetype[meal.archetype.rawValue] ?? 0)
    }

    /// Where a match starts: the lowest floor's first walkable cell, so that a map
    /// without a declared spawn still runs. Where the snake *should* start is a map
    /// property nobody has specified yet.
    static func start(in world: World) -> NavigationGraph.Node? {
        world.graph.nodes.filter { $0.floor == world.map.floors.map(\.level).min() }
            .min { a, b in (a.z, a.x) < (b.z, b.x) }
    }
}
