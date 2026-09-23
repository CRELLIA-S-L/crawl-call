// The snake as the game reasons about it: where the head is, where it has been, and
// where the tail therefore lies. No RealityKit here — this is the part a test can read.
//
// implements: FR-SNAKE-010, FR-SNAKE-020, FR-SNAKE-030, FR-SNAKE-070, FR-SNAKE-220
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
    /// Damage taken that has not yet cost a whole segment (FR-SNAKE-070).
    private var unpaid = 0.0
    /// The height a climb is still working its way up to, while one is under way.
    /// A stair is walked up at the configured speed like any other ground
    /// (FR-SNAKE-030), so it takes the time it takes.
    private var climbingTo: Double?

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
        guard speed > 0, seconds > 0 else { return }
        var budget = speed * seconds

        // A climb already under way is paid for first, and paid for whether or not
        // the player is still holding a direction: a snake halfway up a stair is on
        // the stair. Each step goes into the trail, so the tail climbs behind the
        // head rather than hanging through the floor.
        if let target = climbingTo {
            let gap = target - head.y
            let step = min(budget, abs(gap)) * (gap < 0 ? -1 : 1)
            moveTo(SIMD3(head.x, head.y + step, head.z))
            budget -= abs(step)
            if abs(target - head.y) < 1e-9 { climbingTo = nil }
            guard budget > 1e-12 else { return }
        }

        let length = (direction.x * direction.x + direction.y * direction.y).squareRoot()
        guard length > 0 else { return }
        let unit = SIMD2(direction.x / length, direction.y / length)

        // The frame's distance is walked in pieces no longer than half a cell. A whole
        // step would only ever ask about where it lands: at three metres a second a
        // half-second frame is a metre and a half, and a wall in between would go
        // unnoticed. Frames do get long — a pause, a stall, the app coming back — and
        // the snake must not pass through geometry because of it.
        let longest = max(surfaces.cellSize / 2, 1e-6)
        while budget > 1e-12 {
            let step = min(budget, longest)
            guard let spent = stepOnce(unit: unit, distance: step, over: surfaces) else { return }
            budget -= spent
        }
    }

    /// One piece of a frame's movement, and what it cost. Nil where the way is
    /// blocked, which ends the frame: the head rests against what stopped it.
    ///
    /// A climb costs the height it climbed on top of the ground it covered, because
    /// going up a stair is walking and walking takes the speed the configuration
    /// gives (FR-SNAKE-030). A drop costs nothing: falling is not walking.
    private mutating func stepOnce(unit: SIMD2<Double>, distance: Double, over surfaces: Surfaces) -> Double? {
        let wanted = SIMD3(head.x + unit.x * distance, head.y, head.z + unit.y * distance)

        if surfaces.isWalkable(wanted, floor: floor) {
            let leaving = surfaces.cell(of: head, floor: floor)
            let entering = surfaces.cell(of: wanted, floor: floor)
            moveTo(SIMD3(wanted.x, surfaces.elevation(of: floor), wanted.z))
            // Stairs, the other half of FR-SNAKE-010: a cell a transition links
            // upward carries the head up as it enters it, and the trail keeps both
            // heights so the tail climbs behind it rather than cutting the corner —
            // the mirror of a drop (FR-SNAKE-220).
            //
            // Entering is what does it, not standing: a head that has just dropped
            // onto the same cell would otherwise be sent straight back up.
            // A transition is walked in whichever direction the head came at it from:
            // up it from below, down it from above. The floor changes at the cell —
            // it is walkable on both, which is what a transition means — and the
            // height between them is then walked over the frames that follow.
            if entering != leaving,
               let other = surfaces.rise(at: wanted, from: floor) ?? surfaces.descent(at: wanted, from: floor) {
                floor = other
                climbingTo = surfaces.elevation(of: other)
                return distance
            }
            return distance
        }
        if let below = surfaces.landing(below: wanted, from: floor) {
            // The drop is part of the path: the corner it leaves and the ground it
            // lands on both go into the trail, so the tail lies down the drop rather
            // than cutting the corner (FR-SNAKE-220).
            moveTo(SIMD3(wanted.x, surfaces.elevation(of: floor), wanted.z))
            floor = below
            moveTo(SIMD3(wanted.x, surfaces.elevation(of: below), wanted.z))
            return distance
        }
        return nil
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

    /// Damage taken, in segments lost from the end (FR-SNAKE-070).
    ///
    /// What a hit does not pay for in full stays on the snake: the shipped weapons
    /// deal less than a segment a shot, and damage that was forgotten between shots
    /// would make them harmless however long they fired.
    @discardableResult
    mutating func take(damage: Double, perSegment: Double) -> Int {
        guard damage > 0, perSegment > 0 else { return 0 }
        unpaid += damage
        let lost = min(segments, Int(unpaid / perSegment))
        unpaid -= Double(lost) * perSegment
        segments -= lost
        trim()
        return lost
    }

    private func distance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = b - a
        return (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot()
    }
}
