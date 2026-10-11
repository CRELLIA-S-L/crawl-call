// What the snake is digesting, as the screen shows it (FR-VIEW-280): a swelling on the
// body for each meal, growing behind the head while the prey goes in, then travelling
// down the body to the end of the tail and gone. Only the drawing's: the model knows a
// meal while it lasts (`Eating`) and nothing after it.
//
// file implements: FR-VIEW-280
import Foundation

struct Digestion: Equatable {
    /// One swelling: metres along the body from the head where its middle is, and its
    /// size, 0 to 1.
    struct Lump: Equatable {
        var along: Double
        var size: Double
    }

    private(set) var lumps: [Lump] = []
    /// Whether the newest lump is the meal under way, still growing behind the head.
    private var swallowing = false

    /// One frame of `seconds`. `swallowed` is how much of the prey has gone in, 0 to 1,
    /// while a meal is under way, and nil when none is; `length` is the body's, in
    /// metres from the head to the end of the tail.
    mutating func step(seconds: Double, swallowed: Double?, length: Double) {
        // A meal that is over lets its swelling go, whole, in the frame it ends, so
        // that it travels from that frame on with the rest.
        if swallowed == nil, swallowing {
            if !lumps.isEmpty { lumps[lumps.count - 1].size = Fraction.whole }
            swallowing = false
        }
        // Every lump that is not the meal under way travels on down the body.
        let travelled = max(seconds, .zero) * SnakeLump.speed
        for index in lumps.indices where !(swallowing && index == lumps.count - 1) {
            lumps[index].along += travelled
        }
        if let swallowed {
            let size = min(max(swallowed, .zero), Fraction.whole)
            if swallowing, !lumps.isEmpty {
                lumps[lumps.count - 1].size = size
            } else {
                lumps.append(Lump(along: SnakeLump.behindHead, size: size))
                swallowing = true
            }
        }
        // Gone once the whole bell is past the end of the tail.
        lumps.removeAll { $0.along - SnakeLump.width * Geometry.bothSides > length }
    }
}
