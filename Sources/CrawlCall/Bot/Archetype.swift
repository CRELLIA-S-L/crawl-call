// The six kinds of bot. The set is the obligation, not the individual entries
// (FR-BOT-010), and it is shared by both squads (INV-BOT-030): the sides differ by
// colour and commander, never by composition.
//
// The name is also the key into the bot configuration's archetype table
// (IF-BOT-010), so a kind with no entry there is a configuration error and not a
// silent default.
//
// implements: FR-BOT-010, INV-BOT-030
import Foundation

enum Archetype: String, CaseIterable, Equatable {
    case assault
    case heavy
    case sapper
    case scout
    case sniper
    case medic
}
