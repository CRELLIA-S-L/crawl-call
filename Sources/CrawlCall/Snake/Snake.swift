// The snake as the game reasons about it: where the head is, where it has been, and
// where the tail therefore lies. No RealityKit here — this is the part a test can read.
//
// file implements: FR-MAP-150, FR-SNAKE-010, FR-SNAKE-015, FR-SNAKE-016, FR-SNAKE-055, FR-SNAKE-056, FR-SNAKE-290, FR-VIEW-330, FR-SNAKE-020, FR-SNAKE-030, FR-SNAKE-060, FR-SNAKE-070, FR-SNAKE-210, FR-SNAKE-220
import Foundation

struct Snake {
    /// Where the head is now, in metres, on the floor it is on.
    private(set) var head: SIMD3<Double>
    private(set) var floor: Int
    /// Every place the head has been, newest first, including the vertical portions of
    /// a drop. The tail is read off this, so it is the path and not a decoration.
    private(set) var trail: [SIMD3<Double>]
    /// For each place of the trail, the height it would be at with nothing of the body
    /// under it — where the head went, before it rode up onto its own body — and how fast
    /// it is coming down to what is under it now (FR-SNAKE-056).
    private(set) var grounds: [Double]
    private var falls: [Double]
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
    /// The way round a turn back is being taken, clockwise or not, where it is being taken
    /// the other way round from the shorter (ADR-0061); nil once the held direction is no
    /// longer behind the head, and while the shorter way is the one.
    private var roundabout: Bool?
    /// How far the head has come along its path since the match began, in metres: where
    /// on the ground the drawn body's sway is (FR-VIEW-330).
    private(set) var crawled: Double = .zero
    /// How many segments behind the head are its neck, past which the head crawls over
    /// its own body, as the last frame walked was given it; nil where it does not — in a
    /// coil, and where it was not asked to (FR-SNAKE-055).
    private var neck: Int?
    /// How many times the head has gone off a ledge since the match began: a drop begun
    /// and landed within one long frame is still one (FR-SNAKE-285).
    private(set) var drops = Int.zero
    /// How far above the ground the head rides where it crawls over its own body past
    /// the neck: its body resting on the body it crosses (FR-SNAKE-055).
    private(set) var lift: Double = .zero
    /// Where the head is drawn: on top of what it crawls over.
    var drawnHead: SIMD3<Double> { head + SIMD3(.zero, lift, .zero) }

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
        self.grounds = [head.y]
        self.falls = [.zero]
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
                          turningRadius: Double? = nil, neck: Int? = nil, feel: Double? = nil) {
        guard speed > .zero, seconds > .zero else { return }
        self.neck = neck
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
        guard length > .zero else { roundabout = nil; return }
        let unit = SIMD2(direction.x / length, direction.y / length)

        // The frame's distance is walked in pieces no longer than half a cell. A whole
        // step would only ever ask about where it lands: at three metres a second a
        // half-second frame is a metre and a half, and a wall in between would go
        // unnoticed. Frames do get long — a pause, a stall, the app coming back — and
        // the snake must not pass through geometry because of it.
        let longest = max(surfaces.cellSize * Geometry.half, Motion.shortestPiece)
        while budget > Motion.negligibleDistance {
            let step = min(budget, longest)
            let towards = feel.flatMap { feelRound(towards: unit, within: $0, over: surfaces) } ?? unit
            var way = unit
            if let radius = turningRadius {
                let going = heading ?? unit
                let back = (going * towards).sum() < -Motion.leanShare
                if !back { roundabout = nil }
                way = Snake.turn(going, towards: towards, by: step / radius, clockwise: roundabout)
                // Turning back, where the shorter way round leads straight into what the head
                // cannot pass: the other way round, where that is open, and on that way until
                // the turn is no longer back. Taken into the wall, the turn would be stopped
                // and the slide would send the head back along the wall at once, over its own
                // neck (ADR-0061).
                if back, roundabout == nil, !opens(way, for: step, over: surfaces) {
                    let other = !Snake.clockwise(going, towards: towards)
                    let otherWay = Snake.turn(going, towards: towards, by: step / radius, clockwise: other)
                    if opens(otherWay, for: step, over: surfaces) { way = otherWay; roundabout = other }
                }
            } else {
                // A lunge or a coil steers the head itself: a turn back it broke off is over.
                roundabout = nil
            }
            guard let spent = slide(unit: way, held: unit, distance: step, over: surfaces) else { return }
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

    /// One piece of a frame's movement, taken along the obstacle where the way the head
    /// is going is not open (FR-SNAKE-015). Nil only where the head could not move at all.
    ///
    /// What is left of the piece is walked along the obstacle, all of it, to the side the
    /// held direction leans to along it, or, where it leans to neither — pushed squarely
    /// in, or held straight back — on the way the head is already going along it, or, at
    /// rest against it, to the side with more room: the head goes round what it meets, as
    /// a snake does, and stops only where neither way along it is open (ADR-0069).
    ///
    /// There are two kinds of obstacle and two ways of taking what runs along them.
    /// A module the body touches has a face, and the rest of the piece is laid along
    /// that face — at the end of a wall the face turns, and the head rounds the corner
    /// rather than catching on it (ADR-0021). A cell the graph refuses — the lip of a
    /// hole — has no face but its cell's sides, and the piece is taken along them
    /// instead. A corner needs nothing of its own in either: it is an obstacle on each of
    /// the two ways, and both are refused.
    private mutating func slide(unit: SIMD2<Double>, held: SIMD2<Double>? = nil, distance: Double,
                                over surfaces: Surfaces) -> Double? {
        var direction = unit
        let leaning = held ?? unit
        var restingAgainst: SIMD2<Double>?
        var left = distance
        var moved = false
        // The way asked for; then along what stopped it; then along a second thing,
        // where the first led into a corner.
        for attempt in Int.zero..<Motion.slideAttempts {
            guard let step = stepOnce(unit: direction, distance: left, over: surfaces) else {
                // Along a cell's side, the stick as it is held, not as a slide has turned it.
                return slideAcrossCells(unit: direction, held: held ?? unit, distance: left, over: surfaces) || moved
                    ? distance : nil
            }
            // Off a ledge: nothing more is walked until the head has come down.
            if drop != nil { return step.covered }
            guard let against = step.against else { return distance }
            moved = moved || step.covered > Motion.negligibleDistance
            // `against` leads away from the obstacle: what runs along it is what is left
            // of a way once its part towards or away from the obstacle is taken out.
            func along(_ way: SIMD2<Double>) -> (unit: SIMD2<Double>, share: Double) {
                let pressing = way.x * against.x + way.y * against.y
                let rest = SIMD2(way.x - pressing * against.x, way.y - pressing * against.y)
                let share = (rest.x * rest.x + rest.y * rest.y).squareRoot()
                return (share > Motion.negligibleShare ? rest / share : .zero, share)
            }
            // To the side the stick leans to along it; leaning to neither — by less than the
            // lean that counts — on the way the head is already going along it, or, at rest
            // against it, the side with more room; at the whole of the base speed either way
            // (FR-SNAKE-015, ADR-0069).
            let lean = along(leaning)
            var side: SIMD2<Double>
            // Brought to rest against a face the stick leans to neither side of, the head
            // goes round to the roomier side of that face (below).
            if lean.share <= Motion.leanShare { restingAgainst = against }
            if attempt == .zero {
                side = lean.share > Motion.leanShare ? lean.unit : along(heading ?? .zero).unit
                if side == .zero { side = roomier(across: against, over: surfaces) }
            } else {
                // A second face, met sliding along the first: a corner. Along it only as the
                // stick leans, and never back the way the slide came — the stick pushed into
                // both walls stands the head in the corner, rather than sending it back and
                // forth between them, which piled the body up there in the air.
                side = lean.share > Motion.leanShare ? lean.unit : .zero
                if (side * direction).sum() < -Motion.negligibleShare { side = .zero }
            }
            left -= step.covered
            guard side != .zero, left > Motion.negligibleDistance else { break }
            direction = side
        }
        if moved { return distance }
        // Brought to rest against a face the stick leans to neither side of — going along a
        // wall into a corner, the stick into the wall: at rest against it, to the side with
        // more room, which may be back along it the way it came (FR-SNAKE-015).
        if let restingAgainst {
            let side = roomier(across: restingAgainst, over: surfaces)
            if let step = stepOnce(unit: side, distance: distance, over: surfaces),
               step.covered > Motion.negligibleDistance { return distance }
        }
        // Wedged in a corner, where every way along what it touches leads into the other
        // side of the corner: out the way the stick is held, if that is open (ADR-0069).
        if let held, held != unit, let step = stepOnce(unit: held, distance: distance, over: surfaces),
           step.covered > Motion.negligibleDistance { return distance }
        return nil
    }

    /// Where the head turns to, feeling its way (FR-SNAKE-016): where the way it is going
    /// meets what it cannot pass within `distance`, it turns as hard as it may along what
    /// it would meet, to the side it would pass it on — the side the held direction leans
    /// to along it, or, the stick leaning to neither, the side the way it is going glances
    /// off to — until the way ahead is clear; the turning radius takes it there no faster
    /// than it allows. Nil where there is nothing to feel round: no way yet, a clear way
    /// ahead, a stick held back behind the head, or a way and a stick both square on to
    /// what is ahead, which the slide sees to on touching it (ADR-0069).
    private func feelRound(towards held: SIMD2<Double>, within distance: Double, over surfaces: Surfaces) -> SIMD2<Double>? {
        guard let going = heading, distance > .zero, (going * held).sum() > -Motion.negligibleShare else { return nil }
        let feet = surfaces.height(of: surfaces.cell(of: head, floor: floor))
        let ahead = surfaces.room(from: head, feet: feet, along: going, upTo: distance, standing: true)
        guard ahead.metres < distance - Motion.negligibleDistance, let against = ahead.against else { return nil }
        func along(_ way: SIMD2<Double>) -> SIMD2<Double>? {
            let rest = way - against * (way * against).sum()
            let length = (rest * rest).sum().squareRoot()
            return length > Motion.negligibleShare ? rest / length : nil
        }
        let lean = held - against * (held * against).sum()
        return (lean * lean).sum().squareRoot() > Motion.leanShare ? along(held) : along(going)
    }

    /// Whether a piece of `distance` metres along `way` is open all the way: not refused,
    /// and not stopped short by anything the body touches. Tried on a copy, which is
    /// thrown away.
    private func opens(_ way: SIMD2<Double>, for distance: Double, over surfaces: Surfaces) -> Bool {
        var trial = self
        guard let step = trial.stepOnce(unit: way, distance: distance, over: surfaces) else { return false }
        return step.against == nil
    }

    /// Of the two ways along a face that leads away as `against` does, the one with more
    /// room for the body, up to `Motion.roomProbe` metres; the one nearer the way the head
    /// is going where the two are even, and the first of them where that is even too.
    private func roomier(across against: SIMD2<Double>, over surfaces: Surfaces) -> SIMD2<Double> {
        let one = SIMD2(-against.y, against.x), other = SIMD2(against.y, -against.x)
        let feet = surfaces.height(of: surfaces.cell(of: head, floor: floor))
        // Room for the body among the modules, and on ground the graph holds: the edge of
        // the ground or of a hole ends the room as a wall does.
        func ground(along way: SIMD2<Double>) -> Double {
            let step = surfaces.cellSize * Walking.lookStep
            var metres = step
            while metres <= Motion.roomProbe {
                let point = head + SIMD3(way.x, .zero, way.y) * metres
                guard surfaces.graph.isWalkable(surfaces.cell(of: point, floor: floor)) else { return metres - step }
                metres += step
            }
            return Motion.roomProbe
        }
        let room = [one, other].map {
            min(surfaces.room(from: head, feet: feet, along: $0, upTo: Motion.roomProbe).metres, ground(along: $0))
        }
        if abs(room[0] - room[1]) > Motion.negligibleDistance { return room[0] > room[1] ? one : other }
        let going = heading ?? .zero
        return (going * other).sum() > (going * one).sum() ? other : one
    }

    /// The piece split along the two axes, for an obstacle the graph refuses rather
    /// than one the body touches. True where either part moved the head.
    ///
    /// The edge is a cell's side, so what runs along it is the axis the piece did not
    /// cross. As along a face (FR-SNAKE-015), the head goes that way at the whole of the
    /// piece, to the side the held direction leans to on that axis; leaning to neither, to
    /// whichever side lets it move, the way the head is going first (ADR-0069). Into a
    /// corner — both axes crossed — the held direction's larger part is tried first.
    private mutating func slideAcrossCells(unit: SIMD2<Double>, held: SIMD2<Double>? = nil, distance: Double,
                                           over surfaces: Surfaces) -> Bool {
        let here = surfaces.cell(of: head, floor: floor)
        let target = surfaces.cell(of: head + SIMD3(unit.x, .zero, unit.y) * distance, floor: floor)
        let crossesX = target.x != here.x, crossesZ = target.z != here.z
        let leaning = held ?? unit
        var ways: [SIMD2<Double>]
        if crossesX != crossesZ {
            // Along the one side crossed: the other axis, the stick's way on it, or both ways.
            let axis = crossesX ? SIMD2<Double>(.zero, Fraction.whole) : SIMD2<Double>(Fraction.whole, .zero)
            let lean = (leaning * axis).sum()
            let going = ((heading ?? unit) * axis).sum()
            if abs(lean) > Motion.leanShare {
                ways = [axis * (lean > .zero ? Fraction.whole : -Fraction.whole)]
            } else {
                let first = going < .zero ? -axis : axis
                ways = [first, -first]
            }
        } else {
            ways = abs(leaning.x) >= abs(leaning.y)
                ? [SIMD2(leaning.x, .zero), SIMD2(.zero, leaning.y)]
                : [SIMD2(.zero, leaning.y), SIMD2(leaning.x, .zero)]
            ways = ways.compactMap { part in
                let share = abs(part.x + part.y)
                return share > Motion.negligibleAxisShare ? part / share : nil
            }
        }
        // Never back against the stick — against it by more than the lean that counts, so
        // that a thumb trembling either side of square does not turn the head back and forth.
        for way in ways where (way * leaning).sum() >= -Motion.leanShare {
            if let step = stepOnce(unit: way, distance: distance, over: surfaces),
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
            drops += 1
            if arc.seconds <= .zero { _ = fall(for: .zero) }
            return (room.metres, room.against)
        }
        return nil
    }

    /// A unit on the map plane turned towards another by at most `angle` radians, the
    /// shorter way round, or the way `clockwise` says where it is given; a half turn
    /// always goes the same way, so that the same held stick turns the snake the same way
    /// every time.
    static func turn(_ from: SIMD2<Double>, towards to: SIMD2<Double>, by angle: Double,
                     clockwise given: Bool? = nil) -> SIMD2<Double> {
        let shorter = clockwise(from, towards: to)
        let sense = given ?? shorter
        let gap = atan2(from.x * to.y - from.y * to.x, from.x * to.x + from.y * to.y)
        // The other way round is the whole turn less the shorter.
        let whole = sense == shorter ? abs(gap) : Geometry.fullTurn - abs(gap)
        guard whole > angle, angle.isFinite else { return to }
        let turned = atan2(from.y, from.x) + (sense ? -angle : angle)
        return SIMD2(cos(turned), sin(turned))
    }

    /// Whether the shorter way round from one unit to another is clockwise, by the sign
    /// `turn` reads; a half turn has no shorter way and is always taken the same way.
    static func clockwise(_ from: SIMD2<Double>, towards to: SIMD2<Double>) -> Bool {
        let gap = atan2(from.x * to.y - from.y * to.x, from.x * to.x + from.y * to.y)
        // atan2 calls a half turn π or −π by the sign of a zero.
        return gap < .zero && abs(gap) < .pi - Geometry.samePosition
    }

    private mutating func moveTo(_ position: SIMD3<Double>) {
        let across = SIMD2(position.x - head.x, position.z - head.z)
        let length = (across * across).sum().squareRoot()
        if length > Geometry.samePosition { heading = across / length }
        crawled += distance(head, position)
        // Up onto its body and down off it no steeper than the lift slope, so that a head
        // that stops climbing — into a coil — or starts — off a meal it ended on its own body
        // — goes down or up over the ground it covers, not in one frame (ADR-0067).
        // Covered includes a climb or a drop: a head lifted over its body that goes straight
        // up a way between floors, or straight down, comes off it as well.
        let covered = (across * across).sum().squareRoot() + abs(position.y - head.y)
        lift = min(max(lift(at: position), lift - covered * Motion.liftSlope), lift + covered * Motion.liftRise)
        head = position
        trail.insert(position + SIMD3(.zero, lift, .zero), at: trail.startIndex)
        grounds.insert(position.y, at: grounds.startIndex)
        falls.insert(.zero, at: falls.startIndex)
        trim()
    }

    /// How high a head at `position` rides over its own body past the neck: where the
    /// two bodies would overlap, level, the head rises until its body rests on the other,
    /// on a circle of a body's width round the other's line, so that it goes up and over
    /// smoothly. Nothing where the head was not asked to crawl over itself — in a coil —
    /// and nothing where no part of the body past the neck is within a body's width.
    private func lift(at position: SIMD3<Double>) -> Double {
        guard let neck else { return .zero }
        let points = Array(tail.dropFirst(max(neck, .zero)))
        guard !points.isEmpty else { return .zero }
        let pieces = points.count > 1 ? Array(zip(points, points.dropFirst())) : points.map { ($0, $0) }
        let width = segmentSpacing
        var highest = Double.zero
        for (a, b) in pieces {
            let run = SIMD2(b.x - a.x, b.z - a.z)
            let squared = (run * run).sum()
            let from = SIMD2(position.x - a.x, position.z - a.z)
            let t = squared > .zero ? min(Fraction.whole, max(.zero, (from * run).sum() / squared)) : .zero
            let gap = from - run * t
            let level = (gap * gap).sum()
            guard level < width * width else { continue }
            let under = a.y + (b.y - a.y) * t - position.y
            // Only a body lying on about the head's own level is crawled over: one a floor
            // below or above is not in its way.
            guard abs(under) < width * 2 else { continue }
            highest = max(highest, under + (width * width - level).squareRoot())
        }
        return max(highest, .zero)
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
        if trail.count > keep {
            trail.removeLast(trail.count - keep)
            grounds.removeLast(grounds.count - keep)
            falls.removeLast(falls.count - keep)
        }
    }

    /// Lets every part of the body that lies higher than what is under it now come down
    /// under `gravity`, over `seconds` (FR-SNAKE-056). What is under a part is the body
    /// laid down before it, past the neck — `neck` segments of the path — where it
    /// crosses it (FR-SNAKE-055), or else the ground; a part never goes up by this. The
    /// oldest parts settle first, so that a part rests on the part under it as it is now.
    mutating func settle(seconds: Double, neck: Int, gravity: Double) {
        guard seconds > .zero, trail.count > 1 else { return }
        let width = segmentSpacing
        var along = [Double.zero]
        for i in trail.indices.dropFirst() {
            let run = SIMD2(trail[i].x - trail[i - 1].x, trail[i].z - trail[i - 1].z)
            along.append(along[i - 1] + (run * run).sum().squareRoot())
        }
        let neckLength = Double(max(neck, .zero)) * width
        for i in trail.indices.reversed() {
            let lifted = trail[i].y - grounds[i]
            guard lifted > Motion.negligibleDistance else { falls[i] = .zero; continue }
            var support = Double.zero
            // From the first place past the neck on: `along` only grows.
            var first = i + 1
            while first < trail.count - 1, along[first] - along[i] < neckLength { first += 1 }
            for j in trail.indices.dropFirst(first).dropLast() {
                let a = trail[j], b = trail[j + 1]
                let run = SIMD2(b.x - a.x, b.z - a.z)
                let squared = (run * run).sum()
                let from = SIMD2(trail[i].x - a.x, trail[i].z - a.z)
                let t = squared > .zero ? min(Fraction.whole, max(.zero, (from * run).sum() / squared)) : .zero
                let gap = from - run * t
                let level = (gap * gap).sum()
                guard level < width * width else { continue }
                let under = a.y + (b.y - a.y) * t - grounds[i]
                guard abs(under) < width * Geometry.bothSides else { continue }
                support = max(support, under + (width * width - level).squareRoot())
            }
            guard lifted > support + Motion.negligibleDistance else { falls[i] = .zero; continue }
            let speed = falls[i] + gravity * seconds
            let down = max(support, lifted - speed * seconds)
            falls[i] = down > support ? speed : .zero
            trail[i].y = grounds[i] + down
        }
        lift = trail[trail.startIndex].y - grounds[grounds.startIndex]
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
