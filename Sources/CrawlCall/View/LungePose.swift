// A lunge drawn as a cartoon (FR-VIEW-310): the head turns to its prey and squashes as
// it winds up, stretches along the way it goes as it goes, and squashes for a moment
// where it stops — anticipation, stretch and squash, the three that make a quick
// movement read on screen (ADR-0052). Only the head's drawing: the lunge itself, and
// what the head touches, are the game's (FR-SNAKE-270).
//
// implements: FR-VIEW-310
import Foundation

struct LungePose: Equatable {
    /// How the head is scaled across the way it faces, sideways and up alike.
    var across = Fraction.whole
    /// How the head is scaled along the way it faces.
    var along = Fraction.whole
    /// What the head looks at while it lunges: its prey. Nil where it faces the way it
    /// last moved.
    var aim: SIMD3<Double>?

    /// The pose of the snake's head in a match as it stands.
    static func of(_ game: Game) -> LungePose {
        let prey = game.lunge.flatMap { lunge in game.bots.first { $0.id == lunge.prey }?.position }
        return of(lunge: game.lunge, windUp: game.world.configurations.snake.lunge.windUp, prey: prey,
                  sinceLanding: game.landedAt.map { game.elapsed - $0 })
    }

    /// The pose for a lunge under way, or for the seconds since the last one ended.
    static func of(lunge: Lunge?, windUp: Double, prey: SIMD3<Double>?, sinceLanding: Double?) -> LungePose {
        if let lunge {
            guard lunge.isWindingUp else {
                return LungePose(across: Fraction.whole - LungeLook.thin,
                                 along: Fraction.whole + LungeLook.stretch, aim: prey)
            }
            let wound = windUp > .zero ? Fraction.whole - lunge.windUpLeft / windUp : Fraction.whole
            return LungePose(across: Fraction.whole + LungeLook.windUpBulge * wound,
                             along: Fraction.whole - LungeLook.windUpSquash * wound, aim: prey)
        }
        guard let since = sinceLanding, since >= .zero, since < LungeLook.landingSeconds else { return LungePose() }
        let left = Fraction.whole - since / LungeLook.landingSeconds
        return LungePose(across: Fraction.whole + LungeLook.landingBulge * left,
                         along: Fraction.whole - LungeLook.landingSquash * left)
    }
}
