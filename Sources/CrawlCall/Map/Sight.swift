// What stands in the way of a straight line between two points. One rule, because
// the player's picture and the bots' eyes have to agree about what a wall is: the
// view draws see-through whatever hides the snake (FR-VIEW-150), and a bot sees the
// snake exactly when nothing stands between them (FR-BOT-050).
//
// It lives in the map layer rather than in either caller: geometry is what the map
// is, and when debris stops blocking sight (FR-MAP-040) this is the one place that
// learns about it.
//
// implements: FR-VIEW-150, FR-BOT-050
import Foundation

enum Sight {
    /// Whether a box comes within `margin` of the straight line from `eye` to
    /// `point` — the slab test over the segment, against the box grown by that
    /// margin.
    ///
    /// The margin is what makes this a body rather than a point: a wall that hides
    /// half of something hides it, so the box is grown by the body's own radius and
    /// by whatever else the caller wants counted.
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
        if eye.y >= point.y, centre.y + size.y / 2 <= point.y + 1e-9 { return false }
        let direction = point - eye
        var near = 0.0
        var far = 1.0
        for axis in 0..<3 {
            let step = direction[axis]
            let half = size[axis] / 2 + margin
            let low = centre[axis] - half - eye[axis]
            let high = centre[axis] + half - eye[axis]
            if abs(step) < 1e-12 {
                // Parallel to this pair of faces: either inside them for the whole
                // segment, or never.
                if low > 0 || high < 0 { return false }
                continue
            }
            let first = min(low / step, high / step)
            let second = max(low / step, high / step)
            near = max(near, first)
            far = min(far, second)
            if near > far { return false }
        }
        return true
    }

    /// Whether nothing the plan placed stands between the two points.
    ///
    /// No eye height is invented here: a bot and the snake stand on the same surface,
    /// so the line runs along it, and what cuts it is what cover is — a wall, a
    /// partition, a crate (glossary). The floor they are both standing on does not,
    /// by the rule above.
    static func isClear(from eye: SIMD3<Double>, to point: SIMD3<Double>,
                        through plan: ScenePlan) -> Bool {
        // The line's own box first. A module outside it cannot touch the line, and
        // the comparison costs a handful of operations where the slab test costs
        // thirty — which is the difference between a deliberation step of three
        // milliseconds and one of a few tenths (NFR-PERF-020). The answer is the
        // same either way: this rejects only what the slab test would reject too.
        let low = SIMD3(min(eye.x, point.x), min(eye.y, point.y), min(eye.z, point.z))
        let high = SIMD3(max(eye.x, point.x), max(eye.y, point.y), max(eye.z, point.z))
        for piece in plan.pieces where piece.size.x > 0 && piece.size.y > 0 && piece.size.z > 0 {
            let half = piece.size / 2
            if piece.centre.x + half.x < low.x || piece.centre.x - half.x > high.x { continue }
            if piece.centre.y + half.y < low.y || piece.centre.y - half.y > high.y { continue }
            if piece.centre.z + half.z < low.z || piece.centre.z - half.z > high.z { continue }
            if blocks(centre: piece.centre, size: piece.size, from: eye, to: point, margin: 0) {
                return false
            }
        }
        return true
    }
}
