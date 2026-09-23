// A shot, as the player has to be able to see it (FR-VIEW-170).
//
// The model has no projectile to follow: a shot lands in the deliberation step that
// fires it (FR-BOT-060), so what is left to draw is the line it took and how long
// that line stays. Both ends are where the model has them — on the floor — and how
// high off it the line is drawn is the view's business, not this one's.
//
// implements: FR-VIEW-170
import Foundation

struct Shot: Equatable {
    /// Where the shooter stood.
    let from: SIMD3<Double>
    /// The point it was aimed at.
    let to: SIMD3<Double>
    /// Whose shot it was, so that the line can be drawn in that squad's colour
    /// (FR-VIEW-060).
    let squad: Squad
    /// Seconds the line still has to live.
    var left: Double
}
