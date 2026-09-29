// The coil: what the snake does to a living bot its lunge has reached, before the meal
// (FR-SNAKE-280). The head goes once round the bot, and the body, which follows the
// head's path (FR-SNAKE-020), lies round it in a ring. The coil is the head's own
// movement, by the snake's own rules; where the bot stands too near a wall for a ring
// to fit, the snake shoves it out to where one does, over time and not in a frame
// (ADR-0053).
//
// implements: FR-SNAKE-280
import Foundation

struct Coil: Equatable {
    /// Which bot is coiled round, by its id.
    let prey: Int
    /// Metres from the bot's middle to the head's as it goes round: the two bodies side
    /// by side.
    let radius: Double
    /// Where the bot is shoved to, so that the ring fits round it.
    let room: SIMD3<Double>
    /// Seconds the head takes to go round once.
    let duration: Double
    /// Seconds of it still to go.
    private(set) var left: Double
    /// The angle round the bot the head starts at, from +x towards +z.
    let start: Double

    init(prey: Int, at position: SIMD3<Double>, head: SIMD3<Double>, radius: Double, room: SIMD3<Double>,
         configuration: SnakeConfiguration.Coil) {
        self.prey = prey
        self.radius = radius
        self.room = room
        self.duration = max(configuration.seconds, .zero)
        self.left = duration
        self.start = atan2(head.z - position.z, head.x - position.x)
    }

    /// Whether the head has been all the way round.
    var isDone: Bool { left <= .zero }

    /// Where round the bot the head should be once `left` seconds remain: a whole turn
    /// over the duration, at an even pace.
    private func angle(_ remaining: Double) -> Double {
        let share = duration > .zero ? Fraction.whole - remaining / duration : Fraction.whole
        return start + share * .pi * Geometry.bothSides
    }

    /// One frame of it: the bot shoved towards the room at no more than `shoveSpeed`,
    /// and the head sent to where round the bot it should be by the frame's end, by the
    /// snake's own movement rules.
    static func step(_ coil: inout Coil, snake: inout Snake, prey: inout SIMD3<Double>, seconds: Double,
                     shoveSpeed: Double, over surfaces: Surfaces) {
        let time = min(max(seconds, .zero), coil.left)
        guard time > .zero else { return }
        let way = SIMD2(coil.room.x - prey.x, coil.room.z - prey.z)
        let apart = (way * way).sum().squareRoot()
        if apart > Geometry.samePosition {
            let shove = min(apart, max(shoveSpeed, .zero) * time)
            prey += SIMD3(way.x, .zero, way.y) / apart * shove
        }
        coil.left -= time
        let angle = coil.angle(coil.left)
        let target = SIMD2(prey.x + cos(angle) * coil.radius, prey.z + sin(angle) * coil.radius)
        let toward = target - SIMD2(snake.head.x, snake.head.z)
        let metres = (toward * toward).sum().squareRoot()
        guard metres > Geometry.samePosition else { return }
        snake.advance(direction: toward / metres, speed: metres / time, seconds: time, over: surfaces)
    }

    /// Where near `prey` a ring of `radius` fits round it on its floor: the nearest
    /// place within `reach` metres where the body fits at every point of the ring, on
    /// ground it can crawl on; `prey` itself where nowhere within reach does.
    static func room(around prey: SIMD3<Double>, floor: Int, radius: Double, reach: Double,
                     over surfaces: Surfaces) -> SIMD3<Double> {
        func fits(_ centre: SIMD3<Double>) -> Bool {
            (Int.zero..<CoilRoom.ringPoints).allSatisfy { k in
                let angle = Double(k) / Double(CoilRoom.ringPoints) * .pi * Geometry.bothSides
                let point = centre + SIMD3(cos(angle), .zero, sin(angle)) * radius
                return surfaces.graph.isWalkable(surfaces.cell(of: point, floor: floor))
                    && surfaces.fits(point, floor: floor)
            }
        }
        if fits(prey) { return prey }
        var metres = CoilRoom.searchStep
        while metres <= reach + Geometry.samePosition {
            for k in Int.zero..<CoilRoom.searchWays {
                let angle = Double(k) / Double(CoilRoom.searchWays) * .pi * Geometry.bothSides
                let centre = prey + SIMD3(cos(angle), .zero, sin(angle)) * metres
                if fits(centre) { return centre }
            }
            metres += CoilRoom.searchStep
        }
        return prey
    }
}
