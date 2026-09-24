// Numbers of how a bot's scores are shaped, which the formulas fix rather than the
// tuning (ART-070); the weight of each term against the others is tuning, and is in
// the bot configuration (IF-BOT-010).
//
// implements: FR-BOT-080, FR-BOT-090, FR-BOT-210, FR-BOT-150, FR-BOT-160, FR-BOT-060
import Foundation

enum Utility {
    /// The share of its remaining health that takes from a bot's wish for cover: a
    /// whole bot still wants cover half as much as a bot on its last legs.
    static let coverHealthShare = 0.5
}

/// Numbers of who deliberates when (FR-BOT-150, FR-BOT-160).
enum Scheduling {
    /// A bot that has seen the snake, or stands within the interrupt distance of it,
    /// has this many times the claim of one that has not — the "at least three times"
    /// FR-BOT-160 asks for, taken at its word.
    static let urgentImportance = 3
    static let ordinaryImportance = 1
    /// A bot's wait is counted in steps: one for the step it is in, and one more for
    /// every step it goes without a slot.
    static let firstWait = 1
    static let waitStep = 1
}

/// Numbers of a bot walking its route.
enum Walking {
    /// Metres of a step left below which a bot has walked it all.
    static let arrived = 1e-9
}

/// Numbers of firing (FR-BOT-060).
enum Firing {
    /// A shot spends one round of the magazine.
    static let roundsPerShot = 1
}
