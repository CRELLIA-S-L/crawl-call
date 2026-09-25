// How a bot's walk looks (FR-VIEW-290): a step that comes on as the bot moves and
// dies away as it stops, its beat set by the ground covered, not by the clock, so
// that the feet neither skate nor paddle. Only the drawing's: the model walks the
// bot (`Execution`), and this only says what its figure does meanwhile.
//
// implements: FR-VIEW-290
import Foundation

struct Gait: Equatable {
    /// Where in its stride the walk is, in radians: one turn is a stride, a step with
    /// each foot.
    private(set) var phase: Double = .zero
    /// How much of the walk shows, 0 standing to 1 walking.
    private(set) var amount: Double = .zero

    /// One frame in which the bot moved `moved` metres over the ground in `seconds`.
    mutating func step(moved: Double, seconds: Double) {
        guard seconds > .zero else { return }
        phase = (phase + max(moved, .zero) / BotGait.stride * .pi * Geometry.bothSides)
            .truncatingRemainder(dividingBy: .pi * Geometry.bothSides)
        let walking = moved / seconds > BotGait.movingSpeed
        let ease = min(BotGait.easing * seconds, Fraction.whole)
        amount += ((walking ? Fraction.whole : Fraction.none) - amount) * ease
    }

    /// The figure's pose at this point of the walk: how high it is lifted, how far it
    /// rocks to one side and leans forward, and how far its left leg swings forward —
    /// the right swings as far back. Nothing at all while it stands.
    var pose: (lift: Double, rock: Double, lean: Double, swing: Double) {
        let beat = sin(phase)
        return (lift: amount * BotGait.lift * abs(beat),
                rock: amount * BotGait.rock * beat,
                lean: amount * BotGait.lean,
                swing: amount * BotGait.swing * beat)
    }
}
