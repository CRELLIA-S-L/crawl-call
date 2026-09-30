// The snake as the game reasons about it: where the head is, where it has been, and
// where the tail therefore lies. No RealityKit here — this is the part a test can read.
//
// implements: FR-MAP-150, FR-SNAKE-010, FR-SNAKE-015, FR-SNAKE-290, FR-VIEW-330, FR-SNAKE-020, FR-SNAKE-030, FR-SNAKE-060, FR-SNAKE-070, FR-SNAKE-210, FR-SNAKE-220
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
    /// A drop under way: an arc from the edge the head walked off to where it lands,
    /// taken in the time the fall takes, the direction held waiting until it has
    /// landed (FR-SNAKE-220, ADR-0040).
    private(set) var drop: Drop?
    /// The speed the head last walked at, which it goes on across at off a ledge.
    private var pace: Double = .zero
    /// The way the head last moved across the ground, as a unit on the map plane; nil
    /// until it has moved. What a turn is turned from (FR-SNAKE-290).
    private(set) var heading: SIMD2<Double>?
    /// How far the head has come along its path since the match began, in metres: where
    /// on the ground the drawn body's sway is (FR-VIEW-330).
    private(set) var crawled: Double = .zero

    struct Drop: Equatable {
        let from: SIMD3<Double>
        let to: SIMD3<Double>
        let seconds: Double
        var elapsed: Double = .zero

        /// Where the head is `time` seconds after it went over: across at a steady
        /// speed, and down as the square of the time, as a body falls.
        func position(at time: Double) -> SIMD3<Double> {
            guard seconds > .zero else { return to }
            let share = min(max(time / seconds, .zero), Fraction.whole)
            let across = from + (to - from) * share
            return SIMD3(across.x, from.y + (to.y - from.y) * pow(share, Motion.fallPower), across.z)
        }
    }

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

    /// Moves the head for one frame towards the direction the player holds.
    ///
    /// The direction is on the map plane; the head keeps to walkable surfaces and its
    /// body out of what stands on them, takes a drop where the tuning allows one, and
    /// slides along what it cannot pass rather than stopping against it (FR-SNAKE-010,
    /// FR-SNAKE-015, FR-SNAKE-220, ADR-0021). Speed is the configuration's
    /// (FR-SNAKE-030).
    ///
    /// Given a turning radius, the head turns from the way it last moved towards the one
    /// held no tighter than an arc of that radius, piece by piece as it goes
    /// (FR-SNAKE-290); without one — a lunge, a coil — it goes the way it is given at
    /// once.
    mutating func advance(direction: SIMD2<Double>, speed: Double, seconds: Double, over surfaces: Surfaces,
                          turningRadius: Double? = nil) {
        guard speed > .zero, seconds > .zero else { return }
        pace = speed
        // A drop under way is come down first, whether or not a direction is held;
        // what is left of the frame once it has landed is walked.
        let left = fall(for: seconds)
        guard left > .zero else { return }
        var budget = speed * left

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
            let way = turningRadius.map { Snake.turn(heading ?? unit, towards: unit, by: step / $0) } ?? unit
            guard let spent = slide(unit: way, distance: step, over: surfaces) else { return }
            budget -= spent
            // A piece that went off a ledge: the rest of the frame is the drop's, and
            // what the drop leaves of it is walked on from where the head landed.
            if drop != nil {
                budget = fall(for: max(budget, .zero) / speed) * speed
            }
        }
    }

    /// Goes on along a drop under way for up to `seconds`, and says how much of that
    /// time is left once the head has landed: none while it is still in the air.
    /// Every place on the way goes into the trail, so the tail follows the arc.
    private mutating func fall(for seconds: Double) -> Double {
        guard var current = drop else { return seconds }
        let remaining = current.seconds - current.elapsed
        if seconds < remaining {
            current.elapsed += seconds
            drop = current
            moveTo(current.position(at: current.elapsed))
            return .zero
        }
        drop = nil
        moveTo(current.to)
        return seconds - max(remaining, .zero)
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
            // Off a ledge: nothing more is walked until the head has come down.
            if drop != nil { return step.covered }
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
            guard share > Motion.negligibleAxisShare else { continue }
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
        // The body is measured from the ground it stands on: its node's surface, which on
        // a flight is its step's (FR-MAP-150).
        let here = surfaces.cell(of: head, floor: floor)
        let feet = surfaces.height(of: here)
        let room = surfaces.room(from: head, feet: feet, along: unit, upTo: distance)
        guard room.metres > Motion.negligibleDistance else { return (.zero, room.against) }
        let wanted = SIMD3(head.x + unit.x * room.metres, head.y, head.z + unit.y * room.metres)
        let target = surfaces.cell(of: wanted, floor: floor)

        // Within the cell it is in, the head only moves.
        if target == here {
            moveTo(wanted)
            return (room.metres, room.against)
        }
        // Into a neighbouring cell the graph joins it to: on the same floor, or off the
        // top of a flight onto the floor above (FR-MAP-020). A change of height — a step
        // up or down — is walked over the frames that follow, like any climb, and the
        // trail keeps both heights so the tail climbs behind the head (FR-SNAKE-010).
        if let next = surfaces.step(from: here, into: target) {
            moveTo(wanted)
            floor = next.floor
            let height = surfaces.height(of: next)
            if abs(height - head.y) > Geometry.samePosition { climbingTo = height }
            // A way straight up at the cell entered: a transition (Q-330), walked in
            // whichever direction the head came at it from. The floor changes at the
            // cell — it is walkable on both, which is what a transition means — and the
            // height between them is walked as a climb. Entering is what does it, not
            // standing: a head that has just dropped onto the same cell would otherwise
            // be sent straight back up.
            if let other = surfaces.rise(at: wanted, from: floor) ?? surfaces.descent(at: wanted, from: floor) {
                floor = other
                climbingTo = surfaces.height(of: surfaces.cell(of: wanted, floor: other))
            }
            return (room.metres, room.against)
        }
        // A drop lands the body on the ground below as well as taking it off this one —
        // off a balcony, or off the side of a flight — and a landing inside something
        // down there is refused like a wall.
        if let below = surfaces.landing(below: wanted, from: floor, at: feet),
           surfaces.fits(wanted, feet: surfaces.height(of: below), leaving: feet) {
            // The drop is part of the path: the edge it leaves goes into the trail now,
            // and every place along the arc as the head goes over it in the frames that
            // follow, so the tail follows the head down (FR-SNAKE-220, ADR-0040). The
            // arc lands straight below where nothing farther lets the body land clear.
            moveTo(SIMD3(wanted.x, feet, wanted.z))
            climbingTo = nil
            let arc = surfaces.arc(from: head, floor: floor, along: unit, speed: pace)
                ?? (SIMD3(wanted.x, surfaces.height(of: below), wanted.z), below.floor, .zero)
            floor = arc.floor
            drop = Drop(from: head, to: arc.landing, seconds: arc.seconds)
            if arc.seconds <= .zero { _ = fall(for: .zero) }
            return (room.metres, room.against)
        }
        return nil
    }

    /// A unit on the map plane turned towards another by at most `angle` radians, the
    /// shorter way round; a half turn always goes the same way, so that the same held
    /// stick turns the snake the same way every time.
    static func turn(_ from: SIMD2<Double>, towards to: SIMD2<Double>, by angle: Double) -> SIMD2<Double> {
        let gap = atan2(from.x * to.y - from.y * to.x, from.x * to.x + from.y * to.y)
        guard abs(gap) > angle, angle.isFinite else { return to }
        // A half turn has no shorter way; atan2 calls it π or −π by the sign of a zero.
        let clockwise = gap < .zero && abs(gap) < .pi - Geometry.samePosition
        let turned = atan2(from.y, from.x) + (clockwise ? -angle : angle)
        return SIMD2(cos(turned), sin(turned))
    }

    private mutating func moveTo(_ position: SIMD3<Double>) {
        let across = SIMD2(position.x - head.x, position.z - head.z)
        let length = (across * across).sum().squareRoot()
        if length > Geometry.samePosition { heading = across / length }
        crawled += distance(head, position)
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
