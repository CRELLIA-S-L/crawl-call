// A grenade thrown, flying, waiting out its fuse, and the blast it makes (FR-BOT-470,
// FR-BOT-480, FR-BOT-490, FR-BOT-580, FR-BOT-590).
//
// It is not a round and does not fly like one: a round is answered by what it meets on
// the way (FR-BOT-405), and a grenade is answered by what it covers when it goes off.
// So it is thrown no further than its range, falls along an arc, comes back off what it
// meets, and goes off where it has got to when the fuse runs out — which is what makes
// it answerable, since the bots and the snake move in the seconds between.
//
// file implements: FR-VIEW-360, FR-BOT-080, FR-BOT-470, FR-BOT-480, FR-BOT-490, FR-BOT-580, FR-BOT-590
import Foundation

/// A grenade in the air or on the ground: where it is, where it is going, and how long
/// before it goes off.
struct Thrown: Equatable {
    /// Who threw it. Kept because a blast is somebody's, not because it is spared
    /// anybody: it takes the thrower with everyone else (FR-BOT-480).
    let thrower: Int
    let squad: Squad
    /// Where it is now — thrown no further from the bot that threw it than the
    /// grenade's throw range (FR-BOT-470).
    var position: SIMD3<Double>
    /// How fast and which way it is going, in metres a second (FR-BOT-580). Nothing
    /// once it has come to rest, and a grenade at rest only burns its fuse.
    var velocity: SIMD3<Double> = .zero
    let numbers: BotConfiguration.Grenade
    /// Seconds left before it goes off.
    var fuse: Double
}

/// A blast that has gone off, kept for as long as there is anything to draw of it
/// (FR-VIEW-360). It is a value in the match and not a thing the view keeps of its own,
/// so that what is on screen stays a function of the match.
struct Flash: Equatable {
    let position: SIMD3<Double>
    let radius: Double
    /// Seconds it is drawn for, and seconds of that left.
    let life: Double
    var left: Double
    /// How far it has come, from nothing at the moment it went off to the whole of it
    /// at the end of its life.
    var grown: Double { life > .zero ? min(Fraction.whole, Fraction.whole - left / life) : Fraction.whole }
}

enum Blast {
    /// Metres a second below which a grenade is at rest and only burns its fuse: short
    /// of this it would shiver in a corner for the whole of it.
    static let atRest = 0.1
    /// The share of a step a grenade is held back from what it met, so that the next
    /// frame starts outside the surface rather than on it.
    static let clearance = 0.001
    /// Metres a grenade is felt ahead with, to tell which face it met.
    static let probe = 0.05

    /// What a frame of the grenades comes to: what the blasts did to the snake, and the
    /// blasts there are to draw. The damage to the snake is returned rather than dealt,
    /// as a round's is: the snake is not the bots' to change.
    struct Going {
        var struck = Flight.Struck()
        var flashes: [Flash] = []
    }

    /// Every grenade flies its frame and its fuse burns down with it, and each one whose
    /// fuse has run out goes off where it has got to (FR-BOT-580, FR-BOT-470).
    static func burn(_ thrown: inout [Thrown], seconds: Double, bots: inout [Bot], snake: [SIMD3<Double>],
                     plan: ScenePlan, gravity: Double, flashFor life: Double = .zero) -> Going {
        var going = Going()
        var waiting: [Thrown] = []
        for var grenade in thrown {
            fly(&grenade, seconds: seconds, gravity: gravity, plan: plan)
            grenade.fuse -= max(seconds, .zero)
            guard grenade.fuse <= .zero else { waiting.append(grenade); continue }
            let blast = detonate(grenade, bots: &bots, snake: snake)
            going.struck.damage += blast.damage
            going.struck.hits += blast.hits
            going.flashes.append(Flash(position: grenade.position, radius: grenade.numbers.blastRadius,
                                       life: life, left: life))
        }
        thrown = waiting
        return going
    }

    /// One frame of a grenade's flight: it falls under the tuning's gravity along the
    /// way it is going (FR-BOT-580), and turns back off the first surface it meets,
    /// keeping the share of its speed its restitution sets (FR-BOT-590).
    ///
    /// Where the surface cannot be told — a corner, or two faces met in one step — the
    /// grenade stops where it is rather than guessing which way to go. That is a lie
    /// about a bounce and never a grenade inside a wall.
    static func fly(_ grenade: inout Thrown, seconds: Double, gravity: Double, plan: ScenePlan) {
        guard seconds > .zero, (grenade.velocity * grenade.velocity).sum() > .zero else { return }
        grenade.velocity.y -= gravity * seconds
        let step = grenade.position + grenade.velocity * seconds
        guard let share = Sight.firstStop(from: grenade.position, to: step, through: plan) else {
            grenade.position = step
            return
        }
        grenade.position += (step - grenade.position) * max(.zero, share - clearance)
        guard let axis = face(at: grenade.position, going: grenade.velocity, through: plan) else {
            grenade.velocity = .zero
            return
        }
        // The component across the face turns round and the whole is scaled by what the
        // grenade keeps of its speed: scaling only the reflected component would leave a
        // grenade sliding along the ground at its throwing speed for the whole fuse, and
        // going off six metres past what it was thrown at.
        grenade.velocity[axis] = -grenade.velocity[axis]
        grenade.velocity *= grenade.numbers.restitution
        if (grenade.velocity * grenade.velocity).sum().squareRoot() < atRest { grenade.velocity = .zero }
    }

    /// Which face a grenade at `point` going `velocity` has met: the one axis it cannot
    /// go on along. Nil where none or more than one is in the way, which is a corner.
    ///
    /// The arena is a grid of modules square with the axes, so a face is an axis: the
    /// grenade is felt ahead along each of the three, and the one that is blocked is the
    /// face it bounces off.
    static func face(at point: SIMD3<Double>, going velocity: SIMD3<Double>, through plan: ScenePlan) -> Int? {
        var met: [Int] = []
        for axis in Int.zero..<SIMD3<Double>.scalarCount where velocity[axis] != .zero {
            var ahead = SIMD3<Double>.zero
            ahead[axis] = velocity[axis] > .zero ? probe : -probe
            if !Sight.isClear(from: point, to: point + ahead, through: plan) { met.append(axis) }
        }
        return met.count == 1 ? met.first : nil
    }

    /// How a throw leaves the hand (FR-BOT-580): at the angle below and at the speed
    /// that lands it at the aim point under `gravity`, which for a flat distance `d` and
    /// a launch angle θ is √(g·d ÷ sin 2θ) — at 45°, √(g·d). A throw aimed further than
    /// the grenade's range leaves at the speed its range allows and falls short.
    static func throwing(from hand: SIMD3<Double>, at aim: SIMD3<Double>, range: Double,
                         gravity: Double) -> SIMD3<Double> {
        let flat = SIMD3(aim.x - hand.x, .zero, aim.z - hand.z)
        let metres = (flat * flat).sum().squareRoot()
        guard metres > Turning.noWay, gravity > .zero else { return .zero }
        let speed = (gravity * min(metres, max(range, .zero))).squareRoot()
        return flat / metres * speed * Geometry.halfRight + SIMD3(.zero, speed * Geometry.halfRight, .zero)
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
