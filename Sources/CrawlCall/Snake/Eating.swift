// Eating: the act the whole stage is named after. It takes time, and that time is
// the point — an instant meal makes "eat or leave" a free choice and therefore no
// choice at all (concept §6.2). While it lasts the head stays where it is
// (FR-SNAKE-090).
//
// What ends it depends on what is being eaten. A body has no health and is eaten in
// the body eating duration. Live prey resists: the snake chews through its health at
// the configured rate, and it goes on shooting for as long as that lasts
// (FR-SNAKE-100) — which is also what makes the heavy the slowest meal without a
// number of its own.
//
// Nothing here shields the snake: a stationary snake is a visible and damageable
// one, which is the exposure the concept asks for.
//
// implements: FR-SNAKE-090, FR-SNAKE-100
import Foundation

struct Eating: Equatable {
    /// Which bot is being consumed, by its id.
    let prey: Int
    /// Whether it was alive when this began — what decides how the meal ends and,
    /// later, what it is worth (FR-SCORE-020).
    let alive: Bool
    /// The archetype the tail grows by when this finishes (FR-SNAKE-060).
    let archetype: Archetype
    /// Seconds still to spend on a body. Nil for live prey, whose meal is measured
    /// in the health left rather than in time.
    private(set) var left: Double?
    /// Damage a second the snake deals to live prey.
    private let bite: Double

    init(prey: Int, alive: Bool, archetype: Archetype, configuration: SnakeConfiguration) {
        self.prey = prey
        self.alive = alive
        self.archetype = archetype
        self.left = alive ? nil : configuration.bodyEatingDuration
        self.bite = configuration.eatingDamagePerSecond
    }

    /// One frame of it, returning the damage to deal to the prey this frame.
    ///
    /// A body takes no damage — there is nothing left to hurt — and its meal is over
    /// when its time is spent, which the caller reads from `isFinished`.
    mutating func advance(seconds: Double) -> Double {
        guard seconds > 0 else { return 0 }
        guard alive else {
            left = max(0, (left ?? 0) - seconds)
            return 0
        }
        return bite * seconds
    }

    /// Whether a body's meal is over. Live prey is finished by running out of health,
    /// which is the prey's business and not this type's.
    var isFinished: Bool { alive ? false : (left ?? 0) == 0 }
}
