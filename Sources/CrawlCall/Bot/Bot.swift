// One bot: which squad it fights for, what kind it is, where it stands, and the
// personality its archetype gave it. No RealityKit here — this is the part a test
// can read, the same split as `Snake`.
//
// file implements: FR-BOT-550, FR-BOT-167, FR-BOT-440, FR-BOT-030, FR-BOT-040, FR-BOT-050, FR-BOT-060, FR-BOT-280, FR-BOT-290, FR-BOT-320, FR-BOT-340, FR-BOT-380, FR-BOT-420, FR-BOT-425, FR-BOT-430
import Foundation

/// A reload under way: the firearm being filled and when the filling is due
/// (FR-BOT-550).
struct Reload: Equatable {
    let slot: Arms.Slot
    let due: Double
}

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

    /// What is left of it: a utility input (FR-BOT-080), from the archetype's entry
    /// (IF-BOT-010).
    var health: Double
    /// What it carries and what is left of each weapon (FR-BOT-440): its archetype's
    /// arms, taken out of the catalogue when it was spawned.
    var arms: Arms

    /// Whether this bot speaks for its squad (FR-BOT-040). Nothing draws it: the
    /// role-holder is found by listening to who gives the orders, not by looking
    /// (ADR-0011), and `Figure.parts` is handed an archetype and never a bot.
    /// A body keeps the flag — losing the holder is what collapses a squad
    /// (FR-CMD-120), so the game asks whether a living bot still carries it.
    var isCommander = false

    /// What this bot knows: what it has seen and been told (ADR-0032). It acts on
    /// this and on nothing else (FR-BOT-220).
    var knowledge = Knowledge()
    /// When it last looked over the map round it, in seconds of the match (FR-BOT-230).
    var lastLook = -Double.infinity
    /// When it last acted with a weapon, in seconds of the match: a slot given ahead
    /// of the queue (FR-BOT-170) lets it decide, not act faster than once a
    /// deliberation period. How often one weapon may be used is not this but the
    /// weapon's own clock, which the arms keep a use at a time (FR-BOT-610).
    var lastShot = -Double.infinity
    /// Whether any part of the snake is in what it knows (FR-BOT-050).
    var knowsSnake: Bool { knowledge.knowsSnake }
    /// What it decided to do at its last slot, and what is left of the way there.
    var action: Action?
    var path: [NavigationGraph.Node] = []
    /// An action the graph held no route to the goal of, left out of the scoring at the
    /// bot's next slot and cleared by it (FR-BOT-167): being cut off is an ordinary
    /// event, and a bot that keeps asking for the route it cannot have is the standing
    /// still concept §9.2 calls the signature stupidity.
    var unreachable: Action?
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
    /// The reload it is in the middle of, if it is in the middle of one: which firearm
    /// is being filled, and the second of the match the filling is due (FR-BOT-550).
    /// Set when the reload is first chosen and cleared by any other action, so that a
    /// bot which ducks out, fires and ducks back starts again from the beginning.
    var reloading: Reload?

    /// Where it fires from beside cover, and the hidden cell next to it it reloads in
    /// (FR-BOT-420, FR-BOT-425). Nil while it fires with none, and once it does
    /// anything but fire and reload.
    var post: NavigationGraph.Node?
    var refuge: NavigationGraph.Node?
    /// What it fires at from there: what it comes out again to fire at once it has
    /// reloaded behind the cover (ADR-0063).
    var postTarget: Target?
    /// When it last looked for somewhere to fire from beside cover, in seconds of the
    /// match: one that found none is not asked again until the strafing interval has
    /// passed (FR-BOT-430).
    var lastPostSearch = -Double.infinity
    /// Which way across its line of fire it moves while it fires with no cell beside
    /// cover, as a sign, and since when, in seconds of the match (FR-BOT-430).
    var strafe = Skirmish.rightward
    var strafeSince = -Double.infinity

    /// Whether it is alive: a bot with no health left is a body, which does nothing
    /// (FR-BOT-320).
    var isAlive: Bool { health > .zero }

    /// A bot as its archetype starts it, armed with what that archetype carries
    /// (FR-BOT-440). Nil where the configuration carries no entry for that archetype,
    /// or where the arms it names are not in the catalogue — the caller says what that
    /// means, because at start-up it is a configuration error and mid-match it cannot
    /// happen.
    init?(id: Int, squad: Squad, archetype: Archetype,
          at position: SIMD3<Double>, floor: Int, configuration: BotConfiguration) {
        guard let entry = configuration.archetypes[archetype.rawValue],
              let arms = Arms(entry.arms, from: configuration.weapons) else { return nil }
        self.id = id
        self.squad = squad
        self.archetype = archetype
        self.weights = entry.basePersonalityWeights
        self.health = entry.health
        self.arms = arms
        self.position = position
        self.floor = floor
        self.eyeHeight = configuration.eyeHeight
    }
}
