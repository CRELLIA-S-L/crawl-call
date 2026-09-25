// What stands in the way of a straight line between two points. One rule, because
// the player's picture and the bots' eyes have to agree about what a wall is: the
// view draws see-through whatever hides the snake (FR-VIEW-150), and a bot sees the
// snake exactly when nothing stands between them (FR-BOT-050).
//
// It lives in the map layer rather than in either caller: geometry is what the map
// is, and when debris stops blocking sight (FR-MAP-040) this is the one place that
// learns about it.
//
// implements: FR-VIEW-150, FR-BOT-050, FR-MAP-220
import Foundation

enum Sight {
    /// Whether a box comes within `margin` of the straight line from `eye` to
    /// `point`, the line stopping a margin short of `point` (ADR-0019, points 2–4).
    ///
    /// The margin is what makes this a body rather than a point: a wall that hides
    /// half of something hides it, so the reach is the body's own radius and whatever
    /// else the caller wants counted. It is a distance and therefore a ball: growing
    /// the box by the margin on each axis instead would add a cube of side twice the
    /// margin, reaching a further half again into a corner and giving the box height
    /// it has not got — which is what this asked until 2026-09-23.
    ///
    /// The cheap test comes first and rejects nearly everything: a box that the
    /// segment misses even when grown on every axis is further away than the margin
    /// in any direction, because a Chebyshev reach of the margin covers a Euclidean
    /// one. What survives is measured exactly.
    ///
    /// A module whose top is no higher than the body it would hide is never in the
    /// way of an eye standing at or above that body: every point of the line is at
    /// least as high as the body itself. That is what keeps the floor a body stands
    /// on — which touches the end of the line, and which the margin would otherwise
    /// swallow — out of the answer, for a camera looking down and for a bot looking
    /// across a room alike.
    static func blocks(centre: SIMD3<Double>, size: SIMD3<Double>,
                       from eye: SIMD3<Double>, to point: SIMD3<Double>,
                       margin: Double) -> Bool {
        crossing(centre: centre, size: size, from: eye, to: point, margin: margin) != nil
    }

    /// Where the line from `eye` towards `point` passes the box, when the box hides
    /// the point: the two ends of the stretch of that line — stopped a margin short of
    /// `point`, as `blocks` says — that runs within the box grown by the margin. Nil
    /// where the box does not hide the point.
    ///
    /// This is what a hole is cut around (ADR-0020): the place the line of sight goes
    /// through the module, which for a tall module standing well in front of the snake
    /// is nowhere near the snake. Every point of the module within the margin of the
    /// line lies within the margin of this stretch, because the stretch is all of the
    /// line that comes that near.
    static func crossing(centre: SIMD3<Double>, size: SIMD3<Double>,
                         from eye: SIMD3<Double>, to point: SIMD3<Double>,
                         margin: Double) -> (SIMD3<Double>, SIMD3<Double>)? {
        if eye.y >= point.y, centre.y + size.y * Geometry.half <= point.y + Geometry.samePosition { return nil }
        var direction = point - eye
        // The margin is room to the side of the line, never room past its end. Grown
        // in every direction at once, a box swallows the point the line stops at, so
        // a wall standing a hand's breadth *behind* the body answered "in the way" —
        // and nothing a camera in front of that body does can put it between the two
        // (FR-VIEW-150). The line therefore ends a margin short, and the room the
        // margin buys reaches the body and no further.
        let reach = (direction.x * direction.x + direction.y * direction.y
                     + direction.z * direction.z).squareRoot()
        if margin > .zero, reach > margin { direction *= (reach - margin) / reach }

        var near = Geometry.segmentStart
        var far = Geometry.segmentEnd
        for axis in direction.indices {
            let step = direction[axis]
            let half = size[axis] * Geometry.half + margin
            let low = centre[axis] - half - eye[axis]
            let high = centre[axis] + half - eye[axis]
            if abs(step) < Geometry.parallel {
                // Parallel to this pair of faces: either inside them for the whole
                // segment, or never.
                if low > .zero || high < .zero { return nil }
                continue
            }
            let first = min(low / step, high / step)
            let second = max(low / step, high / step)
            near = max(near, first)
            far = min(far, second)
            if near > far { return nil }
        }
        let stretch = (eye + direction * near, eye + direction * far)
        guard margin > .zero else { return stretch }
        let reached = nearestSquared(lowest: centre - size * Geometry.half, highest: centre + size * Geometry.half,
                                     from: eye, along: direction) <= margin * margin + Geometry.squaredSlack
        return reached ? stretch : nil
    }

    /// The square of the shortest distance between the segment `eye` → `eye +
    /// direction` and the box, exactly.
    ///
    /// How far a point of the segment lies outside the box is, on each axis, one of
    /// three straight lines of the parameter — below the box, above it, or inside and
    /// contributing nothing — and which of the three it is changes only where the
    /// segment crosses a face. Between two such crossings every axis is on one line,
    /// so the squared distance is one quadratic with a non-negative leading term, and
    /// its least value on the piece is at an end of the piece or at its vertex. There
    /// are at most six crossings, so at most seven pieces, and no iteration or
    /// tolerance is needed to find the answer.
    private static func nearestSquared(lowest: SIMD3<Double>, highest: SIMD3<Double>,
                                       from eye: SIMD3<Double>,
                                       along direction: SIMD3<Double>) -> Double {
        var cuts: [Double] = [Geometry.segmentStart, Geometry.segmentEnd]
        for axis in direction.indices where abs(direction[axis]) > Geometry.parallel {
            for face in [lowest[axis], highest[axis]] {
                let t = (face - eye[axis]) / direction[axis]
                if t > Geometry.segmentStart, t < Geometry.segmentEnd { cuts.append(t) }
            }
        }
        cuts.sort()

        var best = Double.greatestFiniteMagnitude
        for (from, to) in zip(cuts, cuts.dropFirst()) {
            guard to - from > Geometry.emptyPiece else { continue }
            // Which side of the box each axis is on holds for the whole piece, so it
            // is read once, in the middle of it.
            let middle = eye + direction * ((from + to) * Geometry.half)
            var constant: Double = .zero, slope: Double = .zero, squares: Double = .zero
            for axis in direction.indices {
                let outward: Double
                if middle[axis] < lowest[axis] { outward = Geometry.belowSide }
                else if middle[axis] > highest[axis] { outward = Geometry.aboveSide }
                else { continue }
                // How far outside, as a straight line of the parameter.
                let start = outward * (eye[axis] - (outward < .zero ? lowest[axis] : highest[axis]))
                let rate = outward * direction[axis]
                squares += rate * rate
                constant += start * start
                slope += Geometry.squareCrossFactor * start * rate
            }
            func value(_ t: Double) -> Double { squares * t * t + slope * t + constant }
            best = min(best, min(value(from), value(to)))
            if squares > .zero {
                let vertex = -slope / (Geometry.squareCrossFactor * squares)
                if vertex > from, vertex < to { best = min(best, value(vertex)) }
            }
        }
        // A quadratic read at its own vertex can come out a hair below zero where the
        // true answer is zero, and a negative square of a distance is not a thing.
        return max(best, .zero)
    }

    /// Whether nothing the plan placed stands between the two points.
    ///
    /// The two points are whatever the caller asks about: a bot asks from its eyes
    /// (ADR-0022) to the ground under a part of the snake, and what cuts that line is
    /// whatever stands higher than the line where it crosses — a fence close in front
    /// of the snake, and not one the bot looks over. The floor the snake is lying on
    /// does not, by the rule above.
    static func isClear(from eye: SIMD3<Double>, to point: SIMD3<Double>,
                        through plan: ScenePlan) -> Bool {
        // The line's own box first. A module outside it cannot touch the line, and
        // the comparison costs a handful of operations where the slab test costs
        // thirty — which is the difference between a deliberation step of three
        // milliseconds and one of a few tenths (NFR-PERF-020). The answer is the
        // same either way: this rejects only what the slab test would reject too.
        let low = SIMD3(min(eye.x, point.x), min(eye.y, point.y), min(eye.z, point.z))
        let high = SIMD3(max(eye.x, point.x), max(eye.y, point.y), max(eye.z, point.z))
        for candidate in plan.index.candidates(low: low, high: high) {
            let piece = plan.pieces[candidate]
            // What stops no sight — a module its kit says a line of sight passes
            // through — lets the line through (FR-MAP-220).
            guard piece.stopsSight else { continue }
            guard piece.size.min() > .zero else { continue }
            let half = piece.size * Geometry.half
            if piece.centre.x + half.x < low.x || piece.centre.x - half.x > high.x { continue }
            if piece.centre.y + half.y < low.y || piece.centre.y - half.y > high.y { continue }
            if piece.centre.z + half.z < low.z || piece.centre.z - half.z > high.z { continue }
            if blocks(centre: piece.centre, size: piece.size, from: eye, to: point, margin: .zero) {
                return false
            }
        }
        return true
    }
}
