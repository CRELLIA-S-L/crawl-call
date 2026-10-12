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
// file implements: FR-CMD-030, FR-CMD-040, FR-CMD-050, FR-CMD-060
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

    /// What a squad stands under, or nil where no commander has spoken to it yet.
    func of(_ squad: Squad) -> SquadCommand? { standing[squad] }

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
