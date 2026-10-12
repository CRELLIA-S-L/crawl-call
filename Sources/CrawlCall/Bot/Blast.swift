// A grenade thrown, waiting out its fuse, and the blast it makes (FR-BOT-470,
// FR-BOT-480, FR-BOT-490).
//
// It is not a round and does not fly like one: a round is answered by what it meets on
// the way (FR-BOT-405), and a grenade is answered by what it covers when it goes off.
// So it is thrown no further than its range, lies where it was thrown, and goes off
// when the fuse runs out — which is what makes it answerable, since the bots and the
// snake move in the seconds between.
//
// file implements: FR-BOT-470, FR-BOT-480, FR-BOT-490
import Foundation

/// A grenade on its way out of a bot's hand and on the ground: where it will go off,
/// and in how long.
struct Thrown: Equatable {
    /// Who threw it. Kept because a blast is somebody's, not because it is spared
    /// anybody: it takes the thrower with everyone else (FR-BOT-480).
    let thrower: Int
    let squad: Squad
    /// Where it lies — no further from the bot that threw it than the grenade's throw
    /// range (FR-BOT-470).
    let position: SIMD3<Double>
    let numbers: BotConfiguration.Grenade
    /// Seconds left before it goes off.
    var fuse: Double
}

enum Blast {
    /// Every fuse burns down by the frame, and each grenade whose fuse has run out goes
    /// off where it lies. What the blasts did to the snake is returned rather than
    /// dealt, as a round's damage is: the snake is not the bots' to change.
    static func burn(_ thrown: inout [Thrown], seconds: Double, bots: inout [Bot],
                     snake: [SIMD3<Double>]) -> Flight.Struck {
        var struck = Flight.Struck()
        var waiting: [Thrown] = []
        for var grenade in thrown {
            grenade.fuse -= max(seconds, .zero)
            guard grenade.fuse <= .zero else { waiting.append(grenade); continue }
            let blast = detonate(grenade, bots: &bots, snake: snake)
            struck.damage += blast.damage
            struck.hits += blast.hits
        }
        thrown = waiting
        return struck
    }

    /// One grenade going off: its damage to every bot within the blast, whichever
    /// squad it is of and the thrower among them (FR-BOT-480), and to the snake once,
    /// raised by the share every part beyond the first adds (FR-BOT-490).
    static func detonate(_ grenade: Thrown, bots: inout [Bot], snake: [SIMD3<Double>]) -> Flight.Struck {
        var struck = Flight.Struck()
        let radius = grenade.numbers.blastRadius
        for index in bots.indices where bots[index].isAlive
            && Perception.metres(bots[index].position, grenade.position) <= radius {
            // A bot with no health left is a body (FR-BOT-320).
            bots[index].health = max(.zero, bots[index].health - grenade.numbers.damage)
            if !bots[index].isAlive { Execution.fall(&bots[index]) }
        }
        let parts = snake.filter { Perception.metres($0, grenade.position) <= radius }.count
        guard parts > .zero else { return struck }
        // Once, and the more the more of it lay in the blast: five parts covered is
        // worth about one and three quarters of a blast and never five, which is what
        // keeps length the player's trade and not the grenade's prize (ADR-0075).
        struck.damage = grenade.numbers.damage
            * (Fraction.whole + Double(parts - 1) * grenade.numbers.furtherPartShare)
        struck.hits = 1
        return struck
    }
}
