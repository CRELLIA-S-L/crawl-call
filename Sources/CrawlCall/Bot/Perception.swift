// What a bot knows about the snake. One question at a time: is any part of it close
// enough, and is there anything in the way (FR-BOT-050).
//
// "In view" is three things: within the detection range, within the field of view —
// a cone round the way the bot faces (FR-BOT-280), as wide as the configuration's
// angle — and with nothing in the way. A bot does not see with the back of its head.
//
// implements: FR-BOT-050
import Foundation

enum Perception {
    /// Marks the snake known to every bot that can see any part of it.
    ///
    /// Any segment counts, which is the point of the requirement: a snake whose head
    /// is behind a crate and whose tail is not has been seen.
    static func notice(_ bots: inout [Bot], snake: [SIMD3<Double>],
                       plan: ScenePlan, configuration: BotConfiguration) {
        for index in bots.indices {
            guard !bots[index].knowsSnake else { continue }
            guard let range = configuration.archetypes[bots[index].archetype.rawValue]?.detectionRange
            else { continue }
            // How far is measured where the bot stands; what is in the way is measured
            // from its eyes, over whatever stands lower than the line (ADR-0022).
            let standing = bots[index].position
            for point in snake where metres(standing, point) <= range
                && isInFieldOfView(point, of: bots[index], degrees: configuration.fieldOfView) {
                if Sight.isClear(from: bots[index].eye, to: point, through: plan) {
                    bots[index].knowsSnake = true
                    break
                }
            }
        }
    }

    /// Whether a point lies within a bot's field of view: no farther round from the way
    /// it faces than half the field's angle. A point straight above or below it has no
    /// way round, and is in view.
    static func isInFieldOfView(_ point: SIMD3<Double>, of bot: Bot, degrees: Double) -> Bool {
        guard let towards = Turning.angle(from: bot.position, to: point) else { return true }
        let off = abs(atan2(sin(towards - bot.facing), cos(towards - bot.facing)))
        return off <= degrees * Geometry.half * .pi / Geometry.halfTurnDegrees
    }

    static func metres(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = b - a
        return (d * d).sum().squareRoot()
    }
}
