// What a commander's answer leaves behind. One call comes back, and four things in the
// match change: what the squad worries about (FR-CMD-030), what it is doing
// (FR-CMD-040), what each soldier has been given to do (FR-CMD-050) and how each one
// weighs what it might do (FR-CMD-060).
//
// This is the one place a decision becomes the game's state. Everything above it is a
// call and an answer; everything below it reads the state and knows nothing of any
// model. A squad with no command standing behaves exactly as it did before there were
// commanders, which is what makes the commander optional rather than load-bearing.
//
// file implements: FR-CMD-030, FR-CMD-040, FR-CMD-050, FR-CMD-060, FR-CMD-120, FR-CMD-125, FR-CMD-130
import Foundation

/// What one squad stands under until its commander says otherwise.
struct SquadCommand: Equatable {
    /// What the squad is to worry about most (FR-CMD-030).
    let threat: CommanderDecision.Threat
    /// What the squad is to do (FR-CMD-040).
    let order: CommanderDecision.Order
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

    /// Applies one answer to one squad: the threat and the order to the squad, the role
    /// and the weights to each soldier the answer names.
    ///
    /// A soldier the answer passes over keeps the role and the weights it had. The
    /// alternative — clearing what the answer does not mention — would make a crew
    /// member the model forgot into a soldier whose orders were taken away, which is
    /// the "repaired response" IF-CMD-020 refuses in its other half: an order nobody
    /// gave.
    mutating func apply(_ decision: CommanderDecision, to squad: Squad, among bots: inout [Bot],
                        configuration: BotConfiguration) {
        standing[squad] = SquadCommand(threat: decision.threat, order: decision.order)
        for index in bots.indices where bots[index].squad == squad {
            guard let lean = decision.lean(for: SquadView.name(of: bots[index].archetype)) else { continue }
            bots[index].role = lean.role
            bots[index].weights = Self.weights(from: lean, for: bots[index].archetype,
                                               configuration: configuration)
        }
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
    /// stood under and every role it was given are void (FR-CMD-125), and what is left
    /// of it keeps the weights it had with more panic in them (FR-CMD-130).
    ///
    /// Done once, the first frame that finds the role-holder gone. The weights are the
    /// commander's last mood and it outlives him, which is why eating a commander
    /// mid-retreat is a different thing from eating one mid-assault (concept §9.4).
    mutating func collapse(_ squad: Squad, among bots: inout [Bot], configuration: BotConfiguration) {
        guard fallen.insert(squad).inserted else { return }
        standing[squad] = nil
        for index in bots.indices where bots[index].squad == squad {
            bots[index].role = nil
            guard bots[index].isAlive else { continue }
            bots[index].weights = Self.panicking(bots[index], by: configuration.collapsePanicIncrement,
                                                 configuration: configuration)
        }
    }

    /// One bot's weights with its panic raised by the collapse increment, up to what
    /// its archetype allows (FR-CMD-130). The bound is the one the commander's own
    /// weights are held to (FR-CMD-060), because it is the only bound the
    /// configuration carries; where the archetype names none, the panic is raised
    /// unheld.
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

    /// The commander's five numbers, each held to what the archetype allows
    /// (FR-CMD-060).
    ///
    /// Clamping and not rejecting: a weight out of range is the model overshooting a
    /// field whose range it was given, and the nearest allowed value is what it meant.
    /// Where the configuration names no range for a weight there is nothing to hold it
    /// to, and the number is taken as it came: a bound invented here would be a tuning
    /// number no interface carries (IF-BOT-010).
    static func weights(from lean: CommanderDecision.Lean, for archetype: Archetype,
                        configuration: BotConfiguration) -> BotConfiguration.Weights {
        let ranges = configuration.archetypes[archetype.rawValue]?.allowedRanges ?? [:]
        func held(_ value: Double, _ name: String) -> Double {
            guard let range = ranges[name] else { return value }
            return min(range.highest, max(range.lowest, value))
        }
        return BotConfiguration.Weights(panic: held(lean.panic, "panic"),
                                        discipline: held(lean.discipline, "discipline"),
                                        aggression: held(lean.aggression, "aggression"),
                                        selfSacrifice: held(lean.selfSacrifice, "selfSacrifice"),
                                        courage: held(lean.courage, "courage"))
    }
}
