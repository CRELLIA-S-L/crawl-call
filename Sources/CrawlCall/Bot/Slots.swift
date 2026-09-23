// Who thinks, and how often. Deliberation runs on a clock of its own — a fixed step
// the frame rate cannot speed up or slow down (FR-BOT-150) — and the slots that step
// hands out go to whoever has waited longest with the most at stake (FR-BOT-160).
//
// implements: FR-BOT-150, FR-BOT-160
import Foundation

struct Slots {
    /// Time that has passed without being spent on a step yet.
    private(set) var carried = 0.0
    /// How many steps each bot has gone without a slot, by bot id.
    private(set) var waited: [Int: Int] = [:]

    /// How many deliberation steps the given time is worth, at the configured
    /// period. Time left over is carried, so that a run of short frames and a run of
    /// long ones deliberate the same number of times per second.
    mutating func steps(after seconds: Double, period: Double) -> Int {
        guard period > 0, seconds > 0 else { return 0 }
        carried += seconds
        let steps = Int(carried / period)
        carried -= Double(steps) * period
        return steps
    }

    /// The bots in the order they have a claim on thinking, most starved first.
    /// Nothing is spent by asking: FR-BOT-165 uses the same order to decide whose
    /// route is computed in a frame.
    func order(among bots: [Bot], snake: [SIMD3<Double>],
               configuration: BotConfiguration) -> [Int] {
        bots.map { bot -> (id: Int, claim: Int) in
            let near = snake.contains { Perception.metres(bot.position, $0) <= configuration.interruptDistance }
            let importance = (bot.knowsSnake || near) ? 3 : 1
            return (bot.id, (waited[bot.id] ?? 1) * importance)
        }
        .sorted { $0.claim != $1.claim ? $0.claim > $1.claim : $0.id < $1.id }
        .map(\.id)
    }

    /// The bots to deliberate in one step, most starved first, at most the
    /// configuration's per-frame maximum.
    ///
    /// Importance is three for a bot that has seen the snake or stands within the
    /// interrupt distance of it, one for the rest — the "at least three times" the
    /// requirement asks for, taken at its word rather than stretched.
    mutating func next(among bots: [Bot], snake: [SIMD3<Double>],
                       configuration: BotConfiguration) -> [Int] {
        for bot in bots where waited[bot.id] == nil { waited[bot.id] = 1 }
        let chosen = order(among: bots, snake: snake, configuration: configuration)
            .prefix(max(0, configuration.perFrameSlotMaximum))
        for bot in bots {
            waited[bot.id] = chosen.contains(bot.id) ? 1 : (waited[bot.id] ?? 1) + 1
        }
        return Array(chosen)
    }
}
