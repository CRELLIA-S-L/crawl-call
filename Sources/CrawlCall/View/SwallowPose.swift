// A living bot swallowed from the top down (FR-VIEW-320): the snake rears its head up
// over the bot, tips it mouth-down, and brings it down over the bot, which stays where
// it stands, its boots the last of it to show — the swallowed-whole comedy the concept
// asks of eating (FR-VIEW-100). Only the
// drawing: in the match the head stays where the coil left it (FR-SNAKE-090), and the
// body drawn from the reared head down to that point is the neck.
//
// file implements: FR-VIEW-320
import Foundation

struct SwallowPose: Equatable {
    /// How far the head is reared, 0 lying where the match has it and 1 up over the bot;
    /// eased in and out over `Swallowing.rearSeconds`.
    var rear = Fraction.none
    /// The point the head rears to: over the top of the bot being eaten. Kept after the
    /// meal, while the head comes down, since the bot is gone by then.
    var over: SIMD3<Double>?

    /// One frame of it: reared further while a living bot is being eaten, `prey` standing
    /// at its feet with a figure `height` tall and `gone` the share of it already in, and
    /// lowered otherwise. The head is over what is left of the bot: over its top at the
    /// first bite, coming down over it as it goes in, down to its boots.
    mutating func step(seconds: Double, eatingAlive prey: SIMD3<Double>?, height: Double, gone: Double = .zero) {
        let pace = Swallowing.rearSeconds > .zero ? max(seconds, .zero) / Swallowing.rearSeconds : Fraction.whole
        if let prey {
            let showing = SwallowPose.prey(at: prey, height: height, gone: gone).height
            over = prey + SIMD3(.zero, height * showing - Swallowing.mouthSink, .zero)
            rear = min(rear + pace, Fraction.whole)
        } else {
            rear = max(rear - pace, Fraction.none)
            if rear == .zero { over = nil }
        }
    }

    /// The rear, eased so that the head sets off and arrives without a kink.
    var eased: Double {
        let t = min(max(rear, Fraction.none), Fraction.whole)
        return t * t * (SmoothStep.three - SmoothStep.two * t)
    }

    /// Where the head is drawn, given where the match has it.
    func head(from ground: SIMD3<Double>) -> SIMD3<Double> {
        guard let over else { return ground }
        return ground + (over - ground) * eased
    }

    /// How far the head is tipped mouth-down, in radians.
    var tip: Double { Swallowing.tipDegrees * .pi / Geometry.halfTurnDegrees * eased }

    /// How a bot being swallowed is drawn, `gone` the share of it already in, 0 at the
    /// first bite and 1 at the last: standing where it stands, as big as it is, and cut
    /// away above the share of its height still outside the head coming down over it,
    /// its boots the last of it to show. Never quite gone: it vanishes when the match
    /// removes it.
    static func prey(at feet: SIMD3<Double>, height: Double, gone: Double) -> (position: SIMD3<Double>, height: Double) {
        let share = min(max(gone, Fraction.none), Fraction.whole)
        return (feet, max(Swallowing.smallest, Fraction.whole - share))
    }
}
