// What a commander answers with (IF-CMD-020), as the game holds it — no model here.
//
// This type is the game's, and the generated one that comes back from the model is the
// adapter's (`SystemModelCommander.swift`). The crossing between them is the one place
// a response is accepted or rejected, which is what "rejecting any response that does
// not parse into this shape" means: an unparseable answer is a missed cycle, which the
// squad survives, where a repaired one is an order nobody gave.
//
// file implements: IF-CMD-020
import Foundation

/// One commander's answer for one interval.
struct CommanderDecision: Equatable {
    /// What the squad should worry about most (FR-CMD-030).
    enum Threat: String, CaseIterable, Equatable { case enemy, snake, withdraw }

    /// What the squad does next (FR-CMD-040). `destroyCover` is the fifth the
    /// requirement names; nothing acts on it until bots can wreck a wall (FR-BOT-070).
    enum Order: String, CaseIterable, Equatable {
        case hold, flank, withdrawToZone, disperse, destroyCover
    }

    /// Whether to offer the other crew a truce, take one, or turn one down (FR-CMD-090).
    enum Truce: String, CaseIterable, Equatable { case none, propose, accept, reject }

    /// What one soldier is told to be and to do. The weights are clamped to the
    /// archetype's allowed range when they are applied, not here (FR-CMD-060): this
    /// type holds what the commander said, and the squad decides what it may do.
    struct Lean: Equatable {
        /// The figure's name, as the state gave it (`SquadView.names`).
        let name: String
        /// Holding a stair, covering, distracting — or nil for none (FR-CMD-050).
        let role: String?
        let panic: Double
        let courage: Double
        let discipline: Double
        let aggression: Double
        let selfSacrifice: Double
    }

    /// One shout, by one named soldier (FR-CMD-140). Nil where the call was not asked
    /// for a line.
    struct Line: Equatable {
        let speaker: String
        let line: String
    }

    let threat: Threat
    let order: Order
    let crew: [Lean]
    let truce: Truce
    let line: Line?

    /// A soldier's lean by name, or nil where the commander said nothing about it.
    func lean(for name: String) -> Lean? { crew.first { $0.name == name } }
}

/// Why a call produced no decision. Every one of these is survivable and none is an
/// error the game reports to the player: the squad keeps the order it had and the
/// speech falls back to a written line (CON-CMD-020, FR-CMD-165).
///
/// It conforms to `Error` because `Result` asks that of a failure, and to nothing else:
/// nothing here is thrown, caught or shown to a player.
enum CommanderFailure: Error, Equatable {
    /// The model declined to answer.
    case refused
    /// The answer did not parse into the shape of IF-CMD-020.
    case malformed(String)
    /// The model was not there to ask — no Apple Intelligence on this device, or it
    /// is still being prepared.
    case unavailable(String)
    /// It took longer than the caller was willing to wait.
    case timedOut
    /// Anything else the surface reported.
    case other(String)
}
