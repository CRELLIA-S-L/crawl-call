// What a bot knows about the snake. One question at a time: is any part of it close
// enough, and is there anything in the way (FR-BOT-050).
//
// What "in view" means is settled here as line of sight and nothing else. The
// requirement says "field of view", the bot configuration carries a detection range
// and no angle, and no bot has a facing to measure an angle from — so a cone would be
// a number and a direction invented in this file. Said out loud rather than assumed:
// if the maintainer wants a cone, IF-BOT-010 gains the angle first.
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
            let eye = bots[index].position
            for point in snake where metres(eye, point) <= range {
                if Sight.isClear(from: eye, to: point, through: plan) {
                    bots[index].knowsSnake = true
                    break
                }
            }
        }
    }

    static func metres(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = b - a
        return (d * d).sum().squareRoot()
    }
}
