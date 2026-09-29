// One bot: which squad it fights for, what kind it is, where it stands, and the
// personality its archetype gave it. No RealityKit here — this is the part a test
// can read, the same split as `Snake`.
//
// implements: FR-BOT-030, FR-BOT-050, FR-BOT-060, FR-BOT-280, FR-BOT-290, FR-BOT-320, FR-BOT-340, FR-BOT-380
import Foundation

/// The two sides. Which one the player is nearer to is never a property of a squad:
/// both are prey.
enum Squad: Int, CaseIterable, Equatable {
    case red = 0
    case blue = 1

    var enemy: Squad { self == .red ? .blue : .red }
    /// Its name as the configuration writes it.
    var name: String { self == .red ? "red" : "blue" }
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

    /// How far above the ground it stands on its eyes are, in metres: where it looks
    /// from and where it fires from (FR-BOT-050, FR-BOT-060). From the bot
    /// configuration (IF-BOT-010, ADR-0022), and the same for every bot.
    let eyeHeight: Double

    /// Where the bot looks from.
    var eye: SIMD3<Double> { SIMD3(position.x, position.y + eyeHeight, position.z) }

    /// What is left of it and what it can fire before reloading — both are utility
    /// inputs (FR-BOT-080), and both start from the archetype's entry (IF-BOT-010).
    var health: Double
    var ammunition: Int
    /// What this bot knows: what it has seen and been told (ADR-0032). It acts on
    /// this and on nothing else (FR-BOT-220).
    var knowledge = Knowledge()
    /// When it last looked over the map round it, in seconds of the match (FR-BOT-230).
    var lastLook = -Double.infinity
    /// When it last fired, in seconds of the match: a slot given ahead of the queue
    /// (FR-BOT-170) lets it decide, not fire faster than once a deliberation period.
    var lastShot = -Double.infinity
    /// Whether any part of the snake is in what it knows (FR-BOT-050).
    var knowsSnake: Bool { knowledge.knowsSnake }
    /// What it decided to do at its last slot, and what is left of the way there.
    var action: Action?
    var path: [NavigationGraph.Node] = []
    /// Which way the bot faces, as an angle round the vertical from +z towards +x, in
    /// radians (FR-BOT-280): where it looks from, and where its figure faces.
    var facing: Double = .zero
    /// How fast it is going, in metres a second: up to its run speed as it sets off,
    /// down to nothing as it arrives (FR-BOT-290).
    var speed: Double = .zero
    /// Which way it looks while it stands, once it has chosen: away from the wall in
    /// front of it (FR-BOT-340). Nil while it walks, and until it stops.
    var lookout: Double?
    /// When it last turned to look round, standing with nothing to do (FR-BOT-380), in
    /// seconds of the match.
    var lastLookRound = -Double.infinity

    /// Whether it is alive: a bot with no health left is a body, which does nothing
    /// (FR-BOT-320).
    var isAlive: Bool { health > .zero }

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
        self.eyeHeight = configuration.eyeHeight
    }
}
