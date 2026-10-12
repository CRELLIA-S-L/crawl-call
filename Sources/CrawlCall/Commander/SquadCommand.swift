// What a commander's answer leaves behind. One call comes back, and two things in the
// match change: what the squad worries about (FR-CMD-030) and what it is doing, in
// which part of the arena (FR-CMD-040).
//
// Two and no longer four. A commander that handed out roles and rewrote each soldier's
// character was taking the bots' decisions for them, which is the rule of ADR-0085: it
// says what matters and where, and the squad works out how.
//
// This is the one place a decision becomes the game's state. Everything above it is a
// call and an answer; everything below it reads the state and knows nothing of any
// model. A squad with no command standing behaves exactly as it did before there were
// commanders, which is what makes the commander optional rather than load-bearing.
//
// file implements: FR-CMD-030, FR-CMD-040, FR-CMD-120, FR-CMD-125, FR-CMD-130
import Foundation

/// What one squad stands under until its commander says otherwise.
struct SquadCommand: Equatable {
    /// What the squad is to worry about most (FR-CMD-030).
    let threat: CommanderDecision.Threat
    /// What the squad is to do (FR-CMD-040).
    let order: CommanderDecision.Order
    /// The part of the arena the order names, or nil where it names none: what the
    /// deliberation turns into a place every position is scored against (FR-BOT-116).
    let place: Places.Part?
}

/// Both squads' standing commands.
///
/// Held by the match rather than by the desk: an answer is taken from the desk once
/// and applied, and what it left behind outlives the call that brought it — a squad
/// keeps its order until a later answer replaces it or its role-holder is lost
/// (FR-CMD-125).
struct SquadCommands: Equatable {
    private var standing: [Squad: SquadCommand] = [:]
    /// The squads whose role-holder is gone. A squad enters this set once and never
    /// leaves it: the role does not pass to anybody (FR-BOT-040), so a collapse is
    /// for the rest of the match (FR-CMD-120).
    private var fallen: Set<Squad> = []

    /// What a squad stands under, or nil where no commander has spoken to it yet.
    func of(_ squad: Squad) -> SquadCommand? { standing[squad] }

    /// Whether a squad has lost its role-holder.
    func hasCollapsed(_ squad: Squad) -> Bool { fallen.contains(squad) }

    /// Applies one answer to one squad: the threat, the order and the part it names.
    ///
    /// Nothing is written on a soldier. What a bot is — its character, its job, where
    /// it stands — stays the bot's, and the only thing an answer changes about it is
    /// what its squad is now trying to do (ADR-0085).
    mutating func apply(_ decision: CommanderDecision, to squad: Squad) {
        standing[squad] = SquadCommand(threat: decision.threat, order: decision.order,
                                       place: decision.place)
    }

    /// Whether a squad has just lost its role-holder: somebody of it is still alive
    /// and none of the living holds the role.
    ///
    /// A squad with nobody left alive is not collapsing — there is nothing to take an
    /// order away from, and a squad wiped out is not what concept §9.4 describes. The
    /// holder's own body keeps the flag (FR-BOT-040), so what is asked is whether
    /// anybody *living* carries it.
    static func collapses(_ squad: Squad, among bots: [Bot]) -> Bool {
        bots.contains { $0.squad == squad && $0.isAlive }
            && !bots.contains { $0.squad == squad && $0.isAlive && $0.isCommander }
    }

    /// The squad's commander is gone: it is called no more (FR-CMD-120), the order it
    /// stood under is void (FR-CMD-125), and what is left of it keeps the weights it
    /// had with more panic in them (FR-CMD-130).
    ///
    /// Done once, the first frame that finds the role-holder gone. The weights are the
    /// squad's own and always were; what the collapse adds is the panic.
    mutating func collapse(_ squad: Squad, among bots: inout [Bot], configuration: BotConfiguration) {
        guard fallen.insert(squad).inserted else { return }
        standing[squad] = nil
        for index in bots.indices where bots[index].squad == squad && bots[index].isAlive {
            bots[index].weights = Self.panicking(bots[index], by: configuration.collapsePanicIncrement,
                                                 configuration: configuration)
        }
    }

    /// One bot's weights with its panic raised by the collapse increment, up to what
    /// its archetype allows (FR-CMD-130). Where the archetype names no range, the panic
    /// is raised unheld.
    static func panicking(_ bot: Bot, by increment: Double,
                          configuration: BotConfiguration) -> BotConfiguration.Weights {
        let was = bot.weights
        let raised = was.panic + increment
        let highest = configuration.archetypes[bot.archetype.rawValue]?.allowedRanges["panic"]?.highest
        return BotConfiguration.Weights(panic: highest.map { min($0, raised) } ?? raised,
                                        discipline: was.discipline,
                                        aggression: was.aggression,
                                        selfSacrifice: was.selfSacrifice,
                                        courage: was.courage)
    }
}
