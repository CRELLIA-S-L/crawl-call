// The match as the game logic sees it: a world read at start, a snake in it, and a
// held direction that comes from an intent and from nothing else.
//
// FR-VIEW-030 is the reason this type takes `Intent` rather than a gesture, a touch
// or a key: the schemes produce intents (FR-VIEW-050), the logic consumes them, and
// neither knows about the other.
//
// implements: FR-VIEW-030, FR-SNAKE-030, FR-BOT-020, FR-SNAKE-070, INV-BOT-010
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

    init(world: World, start: NavigationGraph.Node) {
        self.world = world
        self.surfaces = Surfaces(graph: world.graph, kit: world.kit, tuning: world.configurations.tuning)
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
        }
    }

    /// One frame: the snake moves where it is steered, the bots see what there is to
    /// see, whoever holds a slot decides, and every bot walks whatever it decided.
    mutating func advance(seconds: Double) {
        guard !isPaused else { return }
        snake.advance(direction: held,
                      speed: world.configurations.snake.baseSpeed,
                      seconds: seconds,
                      over: surfaces)

        let body = [snake.head] + snake.tail
        Perception.notice(&bots, snake: body, plan: world.plan,
                          configuration: world.configurations.bot)
        let steps = slots.steps(after: seconds, period: world.configurations.bot.deliberationPeriod)
        for _ in 0..<steps {
            let holders = slots.next(among: bots, snake: body, configuration: world.configurations.bot)
            let damage = Execution.deliberate(&bots, slots: holders, snake: body, world: world)
            if damage > 0 {
                snake.take(damage: damage, perSegment: world.configurations.snake.damagePerSegment)
            }
        }
        Execution.walk(&bots, seconds: seconds, world: world,
                       routeOrder: slots.order(among: bots, snake: body,
                                               configuration: world.configurations.bot))
    }

    /// Where a match starts: the lowest floor's first walkable cell, so that a map
    /// without a declared spawn still runs. Where the snake *should* start is a map
    /// property nobody has specified yet.
    static func start(in world: World) -> NavigationGraph.Node? {
        world.graph.nodes.filter { $0.floor == world.map.floors.map(\.level).min() }
            .min { a, b in (a.z, a.x) < (b.z, b.x) }
    }
}
