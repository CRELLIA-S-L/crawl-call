// One bot: which squad it fights for, what kind it is, where it stands, and the
// personality its archetype gave it. No RealityKit here — this is the part a test
// can read, the same split as `Snake`.
//
// implements: FR-BOT-030, FR-BOT-050
import Foundation

/// The two sides. Which one the player is nearer to is never a property of a squad:
/// both are prey.
enum Squad: Int, CaseIterable, Equatable {
    case red = 0
    case blue = 1

    var enemy: Squad { self == .red ? .blue : .red }
}

struct Bot: Equatable {
    /// Stable within a match, so that a slot queue and a target can name a bot
    /// without holding it.
    let id: Int
    let squad: Squad
    let archetype: Archetype
    /// How this bot weighs what it might do (FR-BOT-030); the commander moves these
    /// later (FR-CMD-060), the archetype is where they start.
    var weights: BotConfiguration.Weights
    var position: SIMD3<Double>
    var floor: Int
    /// What is left of it and what it can fire before reloading — both are utility
    /// inputs (FR-BOT-080), and both start from the archetype's entry (IF-BOT-010).
    var health: Double
    var ammunition: Int
    /// Whether this bot has seen the snake (FR-BOT-050). What un-marks it is not
    /// specified anywhere, so nothing here does.
    var knowsSnake = false
    /// What it decided to do at its last slot, and what is left of the way there.
    var action: Action?
    var path: [NavigationGraph.Node] = []

    /// A bot as its archetype starts it. Nil where the configuration carries no entry
    /// for that archetype — the caller says what that means, because at start-up it is
    /// a configuration error and mid-match it cannot happen.
    init?(id: Int, squad: Squad, archetype: Archetype,
          at position: SIMD3<Double>, floor: Int, configuration: BotConfiguration) {
        guard let entry = configuration.archetypes[archetype.rawValue] else { return nil }
        self.id = id
        self.squad = squad
        self.archetype = archetype
        self.weights = entry.basePersonalityWeights
        self.health = entry.health
        self.ammunition = entry.magazine
        self.position = position
        self.floor = floor
    }
}
