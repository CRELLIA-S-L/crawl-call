// What has happened to a squad since its commander was last called: the second half of
// IF-CMD-010, which obliges the state to carry "the events since the previous call" and
// which `Game.dueCalls` built as an empty list from the day the commander was wired up
// (Q-610).
//
// Nothing here is perceived afresh. Every event is one the frame already found for its
// own reasons — the interrupts of FR-BOT-170, and a bot that went down — so the state
// gains a line and the match gains no work. What the commander is told is therefore
// exactly what its own soldiers reacted to, which is the same rule the rest of the
// state is built under: never the arena, only what the squad met.
//
// The words are the measured ones (ADR-0017, ADR-0077): a soldier is `gone missing` and
// never dead, a pouch `runs out`, and the snake `takes` people. Not `somebody` either,
// which carries a word the guardrail was measured blocking. A squad that nothing
// happened to produces no line at all, so the quiet call stays the call the bench
// measured (FR-TOOL-170).
//
// file implements: IF-CMD-010
import Foundation

/// The events each squad has met since its commander was last called (IF-CMD-010).
///
/// Kept by archetype rather than by bot id: the commander is told names, both squads
/// field the same six, and a soldier that appears twice in one line is a soldier the
/// model has to make sense of twice.
struct SquadHappenings: Equatable {
    private var down: [Squad: [Archetype]] = [:]
    private var hit: [Squad: [Archetype]] = [:]
    private var dry: [Squad: [Archetype]] = [:]
    private var witnesses: [Squad: [Archetype]] = [:]
    private var snakeNear: Set<Squad> = []

    /// An interrupt the frame found, read as something to tell the squad's commander
    /// (FR-BOT-170). An ally's death is left out here and noted by `lost`, so that one
    /// body is one event however many of its squad saw it fall.
    mutating func note(_ reason: Interrupt, of bot: Bot) {
        switch reason {
        case .hit: add(bot.archetype, to: &hit, of: bot.squad)
        case .magazineEmpty: add(bot.archetype, to: &dry, of: bot.squad)
        case .sawEating: add(bot.archetype, to: &witnesses, of: bot.squad)
        case .snakeClose: snakeNear.insert(bot.squad)
        case .allyDied: break
        }
    }

    /// A soldier that went down or was taken, named once however it happened: its
    /// squad's commander is told that it is gone, not what killed it. Taken by
    /// archetype and squad rather than by the bot, because a bot the snake has finished
    /// eating is no longer among them to be asked.
    mutating func lost(_ archetype: Archetype, of squad: Squad) { add(archetype, to: &down, of: squad) }

    /// Everything that is to be said to one squad's commander, in the order the lines
    /// are always given in, so that two quiet calls cost the same tokens.
    func lines(of squad: Squad) -> [String] {
        var said: [String] = []
        if let gone = down[squad], !gone.isEmpty {
            said.append(CommanderInput.list(gone.map(SquadView.name(of:))) + " gone missing")
        }
        if let wounded = hit[squad], !wounded.isEmpty {
            said.append(CommanderInput.list(wounded.map(SquadView.name(of:)))
                        + (wounded.count > 1 ? " took hits" : " took a hit"))
        }
        if let empty = dry[squad], !empty.isEmpty {
            said.append(CommanderInput.list(empty.map(SquadView.name(of:))) + " ran out")
        }
        if snakeNear.contains(squad) { said.append("the snake came near") }
        if let saw = witnesses[squad], !saw.isEmpty {
            said.append(CommanderInput.list(saw.map(SquadView.name(of:))) + " saw the snake take one of ours")
        }
        return said
    }

    /// Said and done with: the call that carries these events empties them, so the next
    /// one speaks of the interval since this one and not of the whole match.
    mutating func clear(_ squad: Squad) {
        down[squad] = nil
        hit[squad] = nil
        dry[squad] = nil
        witnesses[squad] = nil
        snakeNear.remove(squad)
    }

    /// In the order they happened, each archetype once: a soldier hit five times
    /// between two calls is one soldier who took a hit.
    private func add(_ archetype: Archetype, to list: inout [Squad: [Archetype]], of squad: Squad) {
        var held = list[squad] ?? []
        guard !held.contains(archetype) else { return }
        held.append(archetype)
        list[squad] = held
    }
}
