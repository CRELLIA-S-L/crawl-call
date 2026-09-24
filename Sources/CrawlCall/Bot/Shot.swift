// A shot, as the player has to be able to see it (FR-VIEW-170).
//
// The model has no projectile to follow: a shot lands in the deliberation step that
// fires it (FR-BOT-060), so what is left to draw is the line it took and how long
// that line stays. Both ends are where the model has them: the shooter's eyes, which
// is where a bot fires from (ADR-0022), and the point it aimed at, on the ground under
// a part of the snake. The view draws the line between them and adds nothing.
//
// implements: FR-VIEW-170
import Foundation

struct Shot: Equatable {
    /// Where the shot left from: the shooter's eyes.
    let from: SIMD3<Double>
    /// The point it was aimed at.
    let to: SIMD3<Double>
    /// Whose shot it was, so that the line can be drawn in that squad's colour
    /// (FR-VIEW-060).
    let squad: Squad
    /// Seconds the line still has to live.
    var left: Double
}
