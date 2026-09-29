// Who thinks, and how often. Deliberation runs on a clock of its own — a fixed step
// the frame rate cannot speed up or slow down (FR-BOT-150) — and the slots that step
// hands out go to whoever has waited longest with the most at stake (FR-BOT-160),
// after any bot something has just happened to (FR-BOT-170).
//
// implements: FR-BOT-150, FR-BOT-160, FR-BOT-170
import Foundation

struct Slots {
    /// Time that has passed without being spent on a step yet.
    private(set) var carried: Double = .zero
    /// How many steps each bot has gone without a slot, by bot id.
    private(set) var waited: [Int: Int] = [:]

    /// How many deliberation steps the given time is worth, at the configured
    /// period. Time left over is carried, so that a run of short frames and a run of
    /// long ones deliberate the same number of times per second.
    mutating func steps(after seconds: Double, period: Double) -> Int {
        guard period > .zero, seconds > .zero else { return .zero }
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
            let importance = (bot.knowsSnake || near) ? Scheduling.urgentImportance : Scheduling.ordinaryImportance
            return (bot.id, (waited[bot.id] ?? Scheduling.firstWait) * importance)
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
    ///
    /// The bots named `ahead` — interrupted (FR-BOT-170) — come before the queue, by
    /// id, and the rest follow in its order.
    mutating func next(among bots: [Bot], snake: [SIMD3<Double>],
                       configuration: BotConfiguration, ahead: Set<Int> = []) -> [Int] {
        for bot in bots where waited[bot.id] == nil { waited[bot.id] = Scheduling.firstWait }
        let queue = order(among: bots, snake: snake, configuration: configuration)
        let first = queue.filter { ahead.contains($0) }.sorted()
        let chosen = (first + queue.filter { !ahead.contains($0) })
            .prefix(max(.zero, configuration.perFrameSlotMaximum))
        for bot in bots {
            waited[bot.id] = chosen.contains(bot.id)
                ? Scheduling.firstWait
                : (waited[bot.id] ?? Scheduling.firstWait) + Scheduling.waitStep
        }
        return Array(chosen)
    }
}
