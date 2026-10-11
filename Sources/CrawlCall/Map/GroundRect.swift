// A rectangle of ground, which the arena's setting is measured and laid out in: what
// the match camera can cover (FR-MAP-140), what the ground under it is made of, and
// what the setting's outline is levelled over (FR-MAP-200).
//
// It sits with the setting's ground rather than with the coverage arithmetic that first
// needed it, because the outline and the scenery both measure in it, and a value the
// parts above the ground read has to be declared at or below them (ADR-0073).
//
// file implements: FR-MAP-140, FR-MAP-200
import Foundation

/// A rectangle on the ground, x across and z towards the camera.
struct GroundRect: Equatable {
    let lowest: SIMD2<Double>
    let highest: SIMD2<Double>

    func contains(_ other: GroundRect) -> Bool {
        all(lowest .<= other.lowest) && all(highest .>= other.highest)
    }

    func contains(_ point: SIMD2<Double>) -> Bool {
        all(lowest .<= point) && all(point .<= highest)
    }

    func grown(by margin: Double) -> GroundRect {
        GroundRect(lowest: lowest - margin, highest: highest + margin)
    }

    /// This rectangle less `hole`, as up to four rectangles round it: the strips
    /// before and after it along z, the full width, and the two beside it between them.
    func around(_ hole: GroundRect) -> [GroundRect] {
        let low = pointwiseMax(hole.lowest, lowest), high = pointwiseMin(hole.highest, highest)
        guard low.x < high.x, low.y < high.y else { return [self] }
        return [GroundRect(lowest: lowest, highest: SIMD2(highest.x, low.y)),
                GroundRect(lowest: SIMD2(lowest.x, high.y), highest: highest),
                GroundRect(lowest: SIMD2(lowest.x, low.y), highest: SIMD2(low.x, high.y)),
                GroundRect(lowest: SIMD2(high.x, low.y), highest: SIMD2(highest.x, high.y))]
            .filter { $0.highest.x > $0.lowest.x && $0.highest.y > $0.lowest.y }
    }
}
