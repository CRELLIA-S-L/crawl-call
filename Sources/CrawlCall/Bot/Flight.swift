// Rounds in flight, moved a frame at a time. A round strikes the first body in its
// way, whoever's it is, and stops at the first wall (FR-BOT-400, FR-BOT-405): what it
// was fired at is only where it was sent.
//
// A bot's body is its figure's height and the body radius round the ground it stands
// on, rounded at both ends; the snake's is the body radius round the line through its
// head and tail points, raised off the ground by the radius, as it is drawn (ADR-0063).
//
// implements: FR-BOT-400, FR-BOT-405
import Foundation

enum Flight {
    /// What the rounds did to the snake in one frame: the snake is not the bots' to
    /// change, so its damage is returned; a bot struck is changed here (FR-BOT-320).
    struct Struck: Equatable {
        var damage: Double = .zero
        /// How many rounds struck the snake.
        var hits = Int.zero
    }

    /// Every round flies the frame's share of the round speed, and no further than the
    /// round range in all (FR-BOT-405); one that meets a body or a wall on the way is
    /// spent there, the nearer of the two taken.
    static func fly(_ rounds: inout [Round], seconds: Double, bots: inout [Bot], snake: [SIMD3<Double>],
                    plan: ScenePlan, configuration: BotConfiguration, bodyRadius: Double) -> Struck {
        var struck = Struck()
        var flying: [Round] = []
        let raise = SIMD3(.zero, bodyRadius, .zero)
        let snakeLine = snake.map { $0 + raise }
        for var round in rounds {
            let length = min(configuration.roundSpeed * max(seconds, .zero), configuration.roundRange - round.flown)
            guard length > .zero else { continue }
            let end = round.position + round.direction * length
            enum Hit { case wall, bot(Int), snake }
            var first: (share: Double, hit: Hit)?
            if let share = Sight.firstStop(from: round.position, to: end, through: plan) { first = (share, .wall) }
            for index in bots.indices where bots[index].isAlive && bots[index].id != round.shooter {
                let feet = bots[index].position
                let top = max(bodyRadius, configuration.figureHeight - bodyRadius)
                guard let share = contact(from: round.position, to: end,
                                          axis: feet + raise, feet + SIMD3(.zero, top, .zero), radius: bodyRadius),
                      share < (first?.share ?? .infinity) else { continue }
                first = (share, .bot(index))
            }
            let pieces = snakeLine.count > 1 ? Array(zip(snakeLine, snakeLine.dropFirst())) : snakeLine.map { ($0, $0) }
            for (a, b) in pieces {
                guard let share = contact(from: round.position, to: end, axis: a, b, radius: bodyRadius),
                      share < (first?.share ?? .infinity) else { continue }
                first = (share, .snake)
            }
            switch first?.hit {
            case .wall?:
                continue
            case .bot(let index)?:
                // A bot with no health left is a body (FR-BOT-320).
                bots[index].health = max(.zero, bots[index].health - round.damage)
                if !bots[index].isAlive { Execution.fall(&bots[index]) }
            case .snake?:
                struck.damage += round.damage
                struck.hits += 1
            case nil:
                round.position = end
                round.flown += length
                if round.flown < configuration.roundRange { flying.append(round) }
            }
        }
        rounds = flying
        return struck
    }

    /// How far along the segment from `start` to `end`, as a share of it, a point
    /// moving along it first comes within `radius` of the segment from `a` to `b`; nil
    /// where it never does.
    ///
    /// The distance from a point moving in a straight line to a segment is convex in
    /// how far it has moved, so it falls to its least and rises after: the least is
    /// found by narrowing thirds, and the first touch before it by halving.
    static func contact(from start: SIMD3<Double>, to end: SIMD3<Double>,
                        axis a: SIMD3<Double>, _ b: SIMD3<Double>, radius: Double) -> Double? {
        // Nothing within reach of the two boxes' overlap: rejected before any search.
        let low = SIMD3(min(start.x, end.x), min(start.y, end.y), min(start.z, end.z)) - radius
        let high = SIMD3(max(start.x, end.x), max(start.y, end.y), max(start.z, end.z)) + radius
        let lowest = SIMD3(min(a.x, b.x), min(a.y, b.y), min(a.z, b.z))
        let highest = SIMD3(max(a.x, b.x), max(a.y, b.y), max(a.z, b.z))
        if any(low .> highest) || any(high .< lowest) { return nil }
        func distance(_ share: Double) -> Double {
            nearest(start + (end - start) * share, a, b)
        }
        if distance(.zero) <= radius { return .zero }
        var from = Geometry.segmentStart, to = Geometry.segmentEnd
        for _ in Int.zero..<Flying.searchSteps {
            let left = from + (to - from) * Flying.lowerThird
            let right = from + (to - from) * Flying.upperThird
            if distance(left) <= distance(right) { to = right } else { from = left }
        }
        var closest = (from + to) * Geometry.half
        if distance(Geometry.segmentEnd) < distance(closest) { closest = Geometry.segmentEnd }
        guard distance(closest) <= radius else { return nil }
        var outside = Geometry.segmentStart, inside = closest
        for _ in Int.zero..<Flying.searchSteps {
            let middle = (outside + inside) * Geometry.half
            if distance(middle) <= radius { inside = middle } else { outside = middle }
        }
        return inside
    }

    /// The distance from a point to the segment from `a` to `b`.
    static func nearest(_ point: SIMD3<Double>, _ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let along = b - a
        let squared = (along * along).sum()
        let share = squared > .zero ? min(Geometry.segmentEnd, max(Geometry.segmentStart, ((point - a) * along).sum() / squared)) : .zero
        let gap = point - (a + along * share)
        return (gap * gap).sum().squareRoot()
    }
}
