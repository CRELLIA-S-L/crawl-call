// The match as the game logic sees it: a world read at start, a snake in it, and a
// held direction that comes from an intent and from nothing else.
//
// FR-VIEW-030 is the reason this type takes `Intent` rather than a gesture, a touch
// or a key: the schemes produce intents (FR-VIEW-050), the logic consumes them, and
// neither knows about the other.
//
// implements: FR-VIEW-030, FR-SNAKE-030
import Foundation

struct Game {
    let world: World
    private(set) var snake: Snake
    /// What the player is holding now, on the map plane. Zero when nothing is held.
    private(set) var held: SIMD2<Double> = .zero
    private(set) var isPaused = false
    private let surfaces: Surfaces

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

    /// One frame.
    mutating func advance(seconds: Double) {
        guard !isPaused else { return }
        snake.advance(direction: held,
                      speed: world.configurations.snake.baseSpeed,
                      seconds: seconds,
                      over: surfaces)
    }

    /// Where a match starts: the lowest floor's first walkable cell, so that a map
    /// without a declared spawn still runs. Where the snake *should* start is a map
    /// property nobody has specified yet.
    static func start(in world: World) -> NavigationGraph.Node? {
        world.graph.nodes.filter { $0.floor == world.map.floors.map(\.level).min() }
            .min { a, b in (a.z, a.x) < (b.z, b.x) }
    }
}
