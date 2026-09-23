// The snake as the game reasons about it: where the head is, where it has been, and
// where the tail therefore lies. No RealityKit here — this is the part a test can read.
//
// implements: FR-SNAKE-010, FR-SNAKE-020, FR-SNAKE-030, FR-SNAKE-220
import Foundation

struct Snake {
    /// Where the head is now, in metres, on the floor it is on.
    private(set) var head: SIMD3<Double>
    private(set) var floor: Int
    /// Every place the head has been, newest first, including the vertical portions of
    /// a drop. The tail is read off this, so it is the path and not a decoration.
    private(set) var trail: [SIMD3<Double>]
    /// How many segments the tail carries.
    private(set) var segments: Int

    /// The distance between one segment and the next, taken from the body's own width
    /// rather than a number of its own: a segment is a body length along the path.
    let segmentSpacing: Double

    init(head: SIMD3<Double>, floor: Int, segments: Int, segmentSpacing: Double) {
        self.head = head
        self.floor = floor
        self.segments = segments
        self.segmentSpacing = segmentSpacing
        self.trail = [head]
    }

    /// Moves the head for one frame in the direction the player holds.
    ///
    /// The direction is on the map plane; the head keeps to walkable surfaces, takes a
    /// drop where the tuning allows one, and stays where it is when the way is a wall
    /// (FR-SNAKE-010, FR-SNAKE-220). Speed is the configuration's (FR-SNAKE-030).
    mutating func advance(direction: SIMD2<Double>, speed: Double, seconds: Double, over surfaces: Surfaces) {
        let length = (direction.x * direction.x + direction.y * direction.y).squareRoot()
        guard length > 0, speed > 0, seconds > 0 else { return }
        let unit = SIMD2(direction.x / length, direction.y / length)

        // The frame's distance is walked in pieces no longer than half a cell. A whole
        // step would only ever ask about where it lands: at three metres a second a
        // half-second frame is a metre and a half, and a wall in between would go
        // unnoticed. Frames do get long — a pause, a stall, the app coming back — and
        // the snake must not pass through geometry because of it.
        var remaining = speed * seconds
        let longest = max(surfaces.cellSize / 2, 1e-6)
        while remaining > 1e-12 {
            let step = min(remaining, longest)
            remaining -= step
            if !stepOnce(unit: unit, distance: step, over: surfaces) { return }
        }
    }

    /// One piece of a frame's movement. False where the way is blocked, which ends the
    /// frame: the head rests against what stopped it.
    private mutating func stepOnce(unit: SIMD2<Double>, distance: Double, over surfaces: Surfaces) -> Bool {
        let wanted = SIMD3(head.x + unit.x * distance, head.y, head.z + unit.y * distance)

        if surfaces.isWalkable(wanted, floor: floor) {
            moveTo(SIMD3(wanted.x, surfaces.elevation(of: floor), wanted.z))
            return true
        }
        if let below = surfaces.landing(below: wanted, from: floor) {
            // The drop is part of the path: the corner it leaves and the ground it
            // lands on both go into the trail, so the tail lies down the drop rather
            // than cutting the corner (FR-SNAKE-220).
            moveTo(SIMD3(wanted.x, surfaces.elevation(of: floor), wanted.z))
            floor = below
            moveTo(SIMD3(wanted.x, surfaces.elevation(of: below), wanted.z))
            return true
        }
        return false
    }

    private mutating func moveTo(_ position: SIMD3<Double>) {
        head = position
        trail.insert(position, at: 0)
        trim()
    }

    /// The trail is kept just long enough to carry the tail, and no longer.
    private mutating func trim() {
        let needed = Double(segments) * segmentSpacing
        var walked = 0.0
        var keep = 1
        while keep < trail.count && walked < needed {
            walked += distance(trail[keep - 1], trail[keep])
            keep += 1
        }
        if trail.count > keep { trail.removeLast(trail.count - keep) }
    }

    /// Where each segment sits: walking back along the trail, one spacing at a time,
    /// so that a segment rests on the surface the head crossed (FR-SNAKE-020).
    var tail: [SIMD3<Double>] {
        guard segments > 0, trail.count > 1 else { return [] }
        var result: [SIMD3<Double>] = []
        var index = 0
        var carried = 0.0
        for _ in 0..<segments {
            var remaining = segmentSpacing
            while index + 1 < trail.count {
                let span = distance(trail[index], trail[index + 1]) - carried
                if span >= remaining {
                    let from = trail[index]
                    let to = trail[index + 1]
                    let total = distance(from, to)
                    let travelled = carried + remaining
                    let t = total > 0 ? travelled / total : 0
                    result.append(from + (to - from) * t)
                    carried = travelled
                    remaining = 0
                    break
                }
                remaining -= span
                carried = 0
                index += 1
            }
            if remaining > 0 { return result }   // the trail is shorter than the tail
        }
        return result
    }

    mutating func grow(by count: Int) { segments += count }

    private func distance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = b - a
        return (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot()
    }
}
