// The lunge: how the snake gets its mouth to what it would eat (FR-SNAKE-270). A bot
// runs faster than the snake crawls (INV-SNAKE-020), so a meal that waited for the
// head to touch its prey would be a meal only of the slow and the dead.
//
// It has two parts. The wind-up holds the head where it is, which is what makes the
// lunge read as one and gives the prey its moment to run. Then the head goes for the
// prey at the lunge speed, by the snake's own movement rules, for as long as crossing
// the lunge reach at that speed takes, and no longer: a prey that got away in that
// time, or got something between itself and the head, is missed (ADR-0052). Only a
// bot ahead of the head is lunged at, and one that gets out from ahead of it is
// missed: a head sent round behind itself folds the snake in two (ADR-0065).
//
// implements: FR-SNAKE-270, FR-SNAKE-055
import Foundation

struct Lunge: Equatable {
    /// Which bot the snake lunges at, by its id.
    let prey: Int
    /// Seconds of the wind-up still to spend.
    private(set) var windUpLeft: Double
    /// Seconds of travel still left after it.
    private(set) var travelLeft: Double
    /// Seconds the travel takes in all: the reach at the lunge's speed.
    let travel: Double
    /// Metres the travel covers where nothing stops it.
    let reach: Double
    /// Degrees to either side of the way the head is going that the prey must keep to.
    let angle: Double

    init(prey: Int, configuration: SnakeConfiguration.Lunge) {
        self.prey = prey
        self.windUpLeft = max(configuration.windUp, .zero)
        self.reach = max(configuration.reach, .zero)
        self.travel = configuration.speed > .zero ? reach / configuration.speed : .zero
        self.travelLeft = travel
        self.angle = configuration.angle
    }

    /// One frame of it: the wind-up is spent first, and what of `seconds` is left after
    /// it is the head's travel this frame — how long, and how many metres. The travel
    /// is fastest as it sets off and slows to nothing as its time runs out, easing out
    /// at `LungeEase`'s curve, and covers the reach in the time the lunge's speed would
    /// take at a steady pace: the speed is its average (ADR-0052).
    mutating func advance(seconds: Double) -> (seconds: Double, metres: Double) {
        var left = max(seconds, .zero)
        let waited = min(left, windUpLeft)
        windUpLeft -= waited
        left -= waited
        let travelled = min(left, travelLeft)
        guard travelled > .zero, travel > .zero else { return (.zero, .zero) }
        let from = (travel - travelLeft) / travel
        travelLeft -= travelled
        let to = (travel - travelLeft) / travel
        return (travelled, reach * (LungeEase.covered(to) - LungeEase.covered(from)))
    }

    /// Whether the head is still being held back.
    var isWindingUp: Bool { windUpLeft > .zero }

    /// Whether the lunge has had all its time: the wind-up and the travel both spent.
    var isSpent: Bool { windUpLeft == .zero && travelLeft == .zero }

    /// How a frame of a lunge left it.
    enum Result: Equatable {
        /// Still under way.
        case going
        /// The head reached the prey: the meal begins.
        case reached
        /// It is over and the head did not reach the prey: its time ran out, or the
        /// head went off a ledge, where nothing is eaten (FR-SNAKE-220).
        case missed
    }

    /// One frame of a lunge at a prey standing at `prey`: the head held through the
    /// wind-up, then sent at the prey where it is now, easing out as `advance` says, by
    /// the snake's own movement rules, its body past `neck` segments crawled over
    /// (FR-SNAKE-055). It has reached the prey within `bite` metres of it.
    static func step(_ lunge: inout Lunge, snake: inout Snake, prey: SIMD3<Double>, seconds: Double,
                     bite: Double, over surfaces: Surfaces, neck: Int? = nil) -> Result {
        // Within the bite already, wherever it is round the head, it is reached; out of
        // the angle ahead and not there, it is missed: the head turning after it would
        // fold the snake in two (FR-SNAKE-270).
        if !lunge.isWindingUp, snake.drop == nil, Perception.metres(snake.head, prey) <= bite { return .reached }
        guard isAhead(prey, of: snake, within: lunge.angle) else { return .missed }
        let moving = lunge.advance(seconds: seconds)
        if moving.seconds > .zero {
            snake.advance(direction: direction(from: snake.head, to: prey), speed: moving.metres / moving.seconds,
                          seconds: moving.seconds, over: surfaces, neck: neck)
        }
        guard !lunge.isWindingUp else { return .going }
        if snake.drop != nil { return .missed }
        if Perception.metres(snake.head, prey) <= bite { return .reached }
        return lunge.isSpent ? .missed : .going
    }

    /// Whether a point lies within `degrees` to either side of the way the head is
    /// going: the way it last moved, or, before it has moved, the way from its neck to
    /// it. With neither — no move and no tail — every way is ahead.
    static func isAhead(_ point: SIMD3<Double>, of snake: Snake, within degrees: Double) -> Bool {
        let going = snake.heading ?? snake.tail.first.map { direction(from: $0, to: snake.head) }
        guard let going, going != .zero else { return true }
        let towards = direction(from: snake.head, to: point)
        guard towards != .zero else { return true }
        let cosine = min(Fraction.whole, max(-Fraction.whole, (going * towards).sum()))
        return acos(cosine) <= degrees * .pi / Geometry.halfTurnDegrees + Geometry.samePosition
    }

    /// The way from the head to the prey, level and of unit length; none where the
    /// prey stands right over the head.
    static func direction(from head: SIMD3<Double>, to prey: SIMD3<Double>) -> SIMD2<Double> {
        let way = SIMD2(prey.x - head.x, prey.z - head.z)
        let length = (way * way).sum().squareRoot()
        return length > Geometry.samePosition ? way / length : .zero
    }
}
