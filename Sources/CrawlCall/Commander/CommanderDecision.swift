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

    /// What the squad does next (FR-CMD-040). Four words, and each of them is about a
    /// part of the arena: hold it, press into it, come round into it, pull back to it.
    ///
    /// `press` and `flank` say where the enemy is and the other two where to be, which
    /// is the whole of the difference the deliberation reads (ADR-0085); between those
    /// two the difference is what the squad shouts, and that is reason enough to keep
    /// both — a commander that can only say "press" describes half the fights it sees.
    enum Order: String, CaseIterable, Equatable {
        case hold, press, flank, withdraw

        /// Whether the part the order names is where the enemy is, rather than where
        /// the squad is to be: what a bot with no sighting of its own may believe
        /// (FR-BOT-360).
        var namesTheEnemy: Bool {
            switch self {
            case .press, .flank: return true
            case .hold, .withdraw: return false
            }
        }
    }

    /// Whether to offer the other crew a truce, take one, or turn one down (FR-CMD-090).
    enum Truce: String, CaseIterable, Equatable { case none, propose, accept, reject }

    /// One shout, by one named soldier (FR-CMD-140). Nil where the call was not asked
    /// for a line.
    struct Line: Equatable {
        let speaker: String
        let line: String
    }

    let threat: Threat
    let order: Order
    /// The part of the arena the order names, or nil where the commander named none.
    let place: Places.Part?
    let truce: Truce
    let line: Line?
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
