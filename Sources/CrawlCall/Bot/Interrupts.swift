// What happened to a bot in a frame that will not wait for its turn to think
// (FR-BOT-170): it was hit, the snake came into view within the interrupt distance, an
// ally died where it could see, its magazine ran dry, or it saw a meal. Each is found by
// comparing the bots as the frame found them with the bots as it left them.
//
// Three of the requirement's events have nothing to be found in yet: the cover a bot
// occupies being destroyed (FR-MAP-030), a snake-marked body (FR-SCORE-120) and an order
// (FR-CMD-040). They join here when those are built.
//
// file implements: FR-BOT-170
import Foundation

/// Why a bot was given a slot ahead of the queue.
enum Interrupt: Equatable {
    case hit
    case snakeClose
    case allyDied
    case magazineEmpty
    case sawEating
}

struct Interrupts {
    /// What a frame is compared on, of each bot as it began: taken instead of the bots
    /// themselves, whose knowledge the frame rewrites and a copy would duplicate.
    struct Glance: Equatable {
        let id: Int
        let squad: Squad
        let health: Double
        let ammunition: Int
        let position: SIMD3<Double>
        let eye: SIMD3<Double>
        var isAlive: Bool { health > .zero }

        init(_ bot: Bot) {
            id = bot.id
            squad = bot.squad
            health = bot.health
            ammunition = bot.ammunition
            position = bot.position
            eye = bot.eye
        }
    }

    static func glance(_ bots: [Bot]) -> [Glance] { bots.map(Glance.init) }

    /// The bots that saw the snake within the interrupt distance at the end of the last
    /// frame: coming into it is the event, not being in it, or a bot beside the snake
    /// would hold a slot every frame and starve its squad.
    private(set) var close: Set<Int> = []
    /// The bot being coiled round or eaten, and who has seen it happen: a meal is seen
    /// once by each bot, however long it lasts.
    private(set) var meal: Int?
    private(set) var witnesses: Set<Int> = []

    /// The bots interrupted in a frame and why, the first reason found for each.
    ///
    /// `before` is the bots as the frame found them, `after` as it left them; a bot
    /// eaten in the frame is in the first and not the second. `meal` is the bot the
    /// snake is coiled round or eating, if any.
    mutating func find(before: [Glance], after: [Bot], meal prey: Int?, plan: ScenePlan,
                       configuration: BotConfiguration, now: Double) -> [Int: Interrupt] {
        var found: [Int: Interrupt] = [:]
        let was = Dictionary(before.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let left = Dictionary(after.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Allies alive when the frame began and dead or gone when it ended.
        let died = before.filter { $0.isAlive && !(left[$0.id]?.isAlive ?? false) }

        if prey != meal {
            meal = prey
            witnesses = []
        }
        let eaten = prey.flatMap { id in left[id].map(Glance.init) ?? was[id] }

        var closeNow: Set<Int> = []
        for bot in after where bot.isAlive {
            func note(_ reason: Interrupt) { if found[bot.id] == nil { found[bot.id] = reason } }
            let range = configuration.archetypes[bot.archetype.rawValue]?.detectionRange ?? .zero
            if let earlier = was[bot.id] {
                if bot.health < earlier.health { note(.hit) }
                if earlier.ammunition > .zero && bot.ammunition == .zero { note(.magazineEmpty) }
            }
            if bot.knowledge.snake(seenAt: now).contains(where: {
                Perception.metres(bot.position, $0) <= configuration.interruptDistance
            }) {
                closeNow.insert(bot.id)
                if !close.contains(bot.id) { note(.snakeClose) }
            }
            if died.contains(where: { ally in
                ally.squad == bot.squad && ally.id != bot.id
                    && Perception.sees(ally.position + SIMD3(0, Looking.offGround, 0), from: bot, within: range,
                                       plan: plan, configuration: configuration)
            }) {
                note(.allyDied)
            }
            if let eaten, eaten.id != bot.id, !witnesses.contains(bot.id),
               Perception.sees(eaten.eye, from: bot, within: range, plan: plan, configuration: configuration) {
                witnesses.insert(bot.id)
                note(.sawEating)
            }
        }
        close = closeNow
        return found
    }
}
