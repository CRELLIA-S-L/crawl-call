// The snake as the game reasons about it: where the head is, where it has been, and
// where the tail therefore lies. No RealityKit here — this is the part a test can read.
//
// implements: FR-SNAKE-010, FR-SNAKE-015, FR-SNAKE-020, FR-SNAKE-030, FR-SNAKE-060, FR-SNAKE-070, FR-SNAKE-210, FR-SNAKE-220
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
    private var unpaid: Double = .zero
    /// False once a hit has landed on a snake with nothing left to lose (FR-SNAKE-210).
    private(set) var isAlive = true
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
    /// The direction is on the map plane; the head keeps to walkable surfaces and its
    /// body out of what stands on them, takes a drop where the tuning allows one, and
    /// slides along what it cannot pass rather than stopping against it (FR-SNAKE-010,
    /// FR-SNAKE-015, FR-SNAKE-220, ADR-0021). Speed is the configuration's
    /// (FR-SNAKE-030).
    mutating func advance(direction: SIMD2<Double>, speed: Double, seconds: Double, over surfaces: Surfaces) {
        guard speed > .zero, seconds > .zero else { return }
        var budget = speed * seconds

        // A climb already under way is paid for first, and paid for whether or not
        // the player is still holding a direction: a snake halfway up a stair is on
        // the stair. Each step goes into the trail, so the tail climbs behind the
        // head rather than hanging through the floor.
        if let target = climbingTo {
            let gap = target - head.y
            let step = min(budget, abs(gap)) * (gap < .zero ? Motion.down : Motion.up)
            moveTo(SIMD3(head.x, head.y + step, head.z))
            budget -= abs(step)
            if abs(target - head.y) < Geometry.samePosition { climbingTo = nil }
            guard budget > Motion.negligibleDistance else { return }
        }

        let length = (direction.x * direction.x + direction.y * direction.y).squareRoot()
        guard length > .zero else { return }
        let unit = SIMD2(direction.x / length, direction.y / length)

        // The frame's distance is walked in pieces no longer than half a cell. A whole
        // step would only ever ask about where it lands: at three metres a second a
        // half-second frame is a metre and a half, and a wall in between would go
        // unnoticed. Frames do get long — a pause, a stall, the app coming back — and
        // the snake must not pass through geometry because of it.
        let longest = max(surfaces.cellSize * Geometry.half, Motion.shortestPiece)
        while budget > Motion.negligibleDistance {
            let step = min(budget, longest)
            guard let spent = slide(unit: unit, distance: step, over: surfaces) else { return }
            budget -= spent
        }
    }

    /// One piece of a frame's movement, taken along the obstacle where the way the
    /// player asked for is not open (FR-SNAKE-015). Nil only where the head could
    /// not move at all.
    ///
    /// What the frame spends is the whole piece either way, and what the head covers
    /// is the part of the held direction that runs along the obstacle: a head pushed
    /// squarely into a wall covers none of it and stands still, and one pushed at a
    /// glance covers nearly all.
    ///
    /// There are two kinds of obstacle and two ways of taking what runs along them.
    /// A module the body touches has a face, and the rest of the piece is laid along
    /// that face — at the end of a wall the face turns, and the head rounds the corner
    /// rather than catching on it (ADR-0021). A cell the graph refuses — the lip of a
    /// hole — has no face but its cell's sides, and the piece is split along the two
    /// axes instead. A corner needs nothing of its own in either: it is an obstacle
    /// on each of the two ways, and both are refused.
    private mutating func slide(unit: SIMD2<Double>, distance: Double, over surfaces: Surfaces) -> Double? {
        var direction = unit
        var left = distance
        var moved = false
        // The way asked for; then along what stopped it; then along a second thing,
        // where the first led into a corner.
        for _ in Int.zero..<Motion.slideAttempts {
            guard let step = stepOnce(unit: direction, distance: left, over: surfaces) else {
                return slideAcrossCells(unit: direction, distance: left, over: surfaces) || moved ? distance : nil
            }
            guard let against = step.against else { return distance }
            moved = moved || step.covered > Motion.negligibleDistance
            let pressing = direction.x * against.x + direction.y * against.y
            let along = SIMD2(direction.x - pressing * against.x, direction.y - pressing * against.y)
            let share = (along.x * along.x + along.y * along.y).squareRoot()
            left = (left - step.covered) * share
            guard share > Motion.negligibleShare, left > Motion.negligibleDistance else { break }
            direction = along / share
        }
        return moved ? distance : nil
    }

    /// The piece split along the two axes, for an obstacle the graph refuses rather
    /// than one the body touches. True where either part moved the head.
    private mutating func slideAcrossCells(unit: SIMD2<Double>, distance: Double, over surfaces: Surfaces) -> Bool {
        // The larger part first: a head stopped by a corner goes the way the player
        // is leaning, and one stopped by a flat edge has only one part left at all.
        let parts = abs(unit.x) >= abs(unit.y)
            ? [SIMD2(unit.x, .zero), SIMD2(.zero, unit.y)]
            : [SIMD2(.zero, unit.y), SIMD2(unit.x, .zero)]
        for part in parts {
            let share = abs(part.x + part.y)
            guard share > Motion.negligibleDistance else { continue }
            let along = SIMD2(part.x / share, part.y / share)
            if let step = stepOnce(unit: along, distance: distance * share, over: surfaces),
               step.covered > Motion.negligibleDistance { return true }
        }
        return false
    }

    /// One piece of a frame's movement: how far the head covered, and which way leads
    /// away from the module that stopped it short, where one did. Nil where the graph
    /// refuses where the piece leads — a hole with nothing to land on within reach.
    ///
    /// A climb costs the height it climbed on top of the ground it covered, because
    /// going up a stair is walking and walking takes the speed the configuration
    /// gives (FR-SNAKE-030). A drop costs nothing: falling is not walking.
    private mutating func stepOnce(unit: SIMD2<Double>, distance: Double,
                                   over surfaces: Surfaces) -> (covered: Double, against: SIMD2<Double>?)? {
        // The body first: as far as it goes before it touches something it cannot
        // pass (FR-SNAKE-010, ADR-0021). What the grid says is asked of where it got to.
        let room = surfaces.room(from: head, floor: floor, along: unit, upTo: distance)
        guard room.metres > Motion.negligibleDistance else { return (.zero, room.against) }
        let wanted = SIMD3(head.x + unit.x * room.metres, head.y, head.z + unit.y * room.metres)

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
            }
            return (room.metres, room.against)
        }
        // A drop lands the body on the floor below as well as taking it off this one,
        // and a landing inside something down there is refused like a wall.
        if let below = surfaces.landing(below: wanted, from: floor), surfaces.fits(wanted, floor: below) {
            // The drop is part of the path: the corner it leaves and the ground it
            // lands on both go into the trail, so the tail lies down the drop rather
            // than cutting the corner (FR-SNAKE-220).
            moveTo(SIMD3(wanted.x, surfaces.elevation(of: floor), wanted.z))
            floor = below
            moveTo(SIMD3(wanted.x, surfaces.elevation(of: below), wanted.z))
            return (room.metres, room.against)
        }
        return nil
    }

    private mutating func moveTo(_ position: SIMD3<Double>) {
        head = position
        trail.insert(position, at: trail.startIndex)
        trim()
    }

    /// The trail is kept just long enough to carry the tail, and no longer.
    private mutating func trim() {
        let needed = Double(segments) * segmentSpacing
        var walked: Double = .zero
        // The head's own place is always kept; `keep` is how many places are.
        var keep = trail.index(after: trail.startIndex)
        while keep < trail.count && walked < needed {
            walked += distance(trail[trail.index(before: keep)], trail[keep])
            trail.formIndex(after: &keep)
        }
        if trail.count > keep { trail.removeLast(trail.count - keep) }
    }

    /// Where each segment sits: walking back along the trail, one spacing at a time,
    /// so that a segment rests on the surface the head crossed (FR-SNAKE-020).
    var tail: [SIMD3<Double>] {
        // A tail needs a stretch of path: two places at least.
        guard segments > .zero, trail.index(after: trail.startIndex) < trail.endIndex else { return [] }
        var result: [SIMD3<Double>] = []
        var index = trail.startIndex
        var carried: Double = .zero
        for _ in Int.zero..<segments {
            var remaining = segmentSpacing
            while trail.index(after: index) < trail.endIndex {
                let next = trail.index(after: index)
                let span = distance(trail[index], trail[next]) - carried
                if span >= remaining {
                    let from = trail[index]
                    let to = trail[next]
                    let total = distance(from, to)
                    let travelled = carried + remaining
                    let t = total > .zero ? travelled / total : .zero
                    result.append(from + (to - from) * t)
                    carried = travelled
                    remaining = .zero
                    break
                }
                remaining -= span
                carried = .zero
                index = next
            }
            if remaining > .zero { return result }   // the trail is shorter than the tail
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
        guard damage > .zero, perSegment > .zero else { return .zero }
        // The tail is the life (ADR-0009), so a hit on a snake with no tail has
        // nothing to take but the snake (FR-SNAKE-210). Banking it would make the
        // last hit the only harmless one there is.
        guard segments > .zero else {
            isAlive = false
            return .zero
        }
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
