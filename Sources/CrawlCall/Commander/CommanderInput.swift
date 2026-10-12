// What one squad's commander is told, and the words it is told in (IF-CMD-010).
//
// Two things decide this file, and both are measurements rather than taste.
//
// The state is read by the same input guardrail as the instructions: the same
// situation written as wounds and bodies was blocked in 10 of 10 calls and in the
// game's own words in 0 of 10 (ADR-0017). So a soldier is `up`, `up but wobbly` or
// `flat on his back`, never wounded; one that is gone has `gone missing`, never died;
// and the snake takes people rather than killing them. The words here are the ones the
// prompt bench measured, not new ones (`Sources/PromptBench/PromptBench.swift`).
//
// And the whole state is counted against the state token budget of the match
// configuration, because a call that overflows is a call that never happens
// (CON-CMD-010).
//
// Nothing here reads the truth. Every field comes from what the squad has perceived,
// which is the whole of "from its own point of view" — and the same rule the bots
// themselves act under (FR-BOT-220).
//
// file implements: IF-CMD-010
import Foundation

/// What a squad's commander knows when it is asked to decide (IF-CMD-010).
struct CommanderInput: Equatable, Sendable {
    /// One of the squad's own, in the words the commander hears.
    struct Soldier: Equatable, Sendable {
        /// The figure's name. Both squads field the same archetypes, so both squads
        /// use the same six names — no commander is ever told the other crew's, so
        /// the two never meet in one call.
        let name: String
        /// `up`, `up but wobbly`, `flat on his back`.
        let standing: String
        /// `running low`, `empty`; nil when there is nothing worth the tokens.
        let pouch: String?
        /// Which part of the arena, in the coarse words the bench measured.
        let place: String
    }

    let crew: [Soldier]
    /// Named, and said to be missing rather than dead.
    let gone: [String]
    /// The other crew as this one knows it: `5 up, north`, `not seen`.
    let rivals: String
    /// `not seen` when the squad is calm, which is FR-CMD-070's doing and not this
    /// type's: the omission is decided before the state is built.
    let snake: String
    let awareness: String
    /// The commander's own previous decision: `none` on the first call.
    let lastCall: String
    /// A truce the other crew has offered and this one has not answered (FR-CMD-090).
    let truce: String?
    /// What happened since the previous call.
    let events: [String]

    /// The state as the model reads it.
    ///
    /// The five lines a calm squad with no truce and no events produces are
    /// the shape the bench measured, line for line; everything beyond them is written
    /// only when there is something to write, so that the common call stays the call
    /// that was measured. Any change to this rendering is a change to one of the four
    /// things a bench measurement covers, and voids the reading (FR-TOOL-170).
    var prompt: String {
        var lines: [String] = []
        lines.append("crew: " + (crewLine.isEmpty ? "nobody left" : crewLine))
        lines.append("rival crew: " + rivals)
        lines.append("snake: " + snake)
        lines.append("awareness: " + awareness)
        lines.append("your last call: " + lastCall)
        if let truce { lines.append("truce: " + truce) }
        if !events.isEmpty { lines.append("just happened: " + events.joined(separator: "; ")) }
        return lines.joined(separator: "\n")
    }

    /// `Davis and Pike up, west side; Marsh up but wobbly, running low, east side;
    /// Otto and Beans gone missing`
    ///
    /// Those standing the same way in the same quarter are named together, in the
    /// order they are given, as the bench's own states name them — "Davis, Pike,
    /// Marsh, Otto, Beans, Kit, all up, west side" — so four soldiers cost four names
    /// and one clause rather than four clauses. One with an emptying pouch stands on
    /// its own, after them, because that is the thing worth the tokens.
    private var crewLine: String {
        var together: [(standing: String, place: String, names: [String])] = []
        var apart: [String] = []
        for soldier in crew {
            guard let pouch = soldier.pouch else {
                if let index = together.firstIndex(where: {
                    $0.standing == soldier.standing && $0.place == soldier.place
                }) {
                    together[index].names.append(soldier.name)
                } else {
                    together.append((soldier.standing, soldier.place, [soldier.name]))
                }
                continue
            }
            apart.append("\(soldier.name) \(soldier.standing), \(pouch), \(soldier.place)")
        }
        var groups = together.map { CommanderInput.list($0.names) + " " + $0.standing + ", " + $0.place }
        groups.append(contentsOf: apart)
        if !gone.isEmpty { groups.append(CommanderInput.list(gone) + " gone missing") }
        return groups.joined(separator: "; ")
    }

    /// `Davis`, `Davis and Pike`, `Davis, Pike and Marsh`.
    static func list(_ names: [String]) -> String {
        guard let last = names.last else { return "" }
        guard names.count > 1 else { return last }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }

    /// Roughly how many tokens the state costs, for the budget of IF-CMD-010.
    ///
    /// Three characters a token, which is deliberately short of what was measured:
    /// the bench's `alarm` state is 168 characters and counted 52 input tokens on
    /// 2026-10-11, which is 3.23 characters a token, and a smaller divisor over-counts
    /// rather than under-counts. An estimate is what a budget can be checked against
    /// without a model in the room; the true count comes back in `usage.input` from
    /// every real call and is what a measurement on the device reads.
    static let charactersPerToken = 3.0

    var estimatedTokens: Int { Int((Double(prompt.count) / CommanderInput.charactersPerToken).rounded(.up)) }
}
