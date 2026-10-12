// Which part of the arena a word names, and where the middle of that part is.
//
// The vocabulary is the one a commander is already spoken to in: `SquadView.place`
// writes "east side", "north-east" and "middle" into the state (IF-CMD-010), and this
// is the same list read the other way, so the commander answers in the words it was
// told things in and nothing new has to be measured for safety (ADR-0017, ADR-0085).
//
// The parts are the arena's own quarters and not a grid of its cells: coarse on
// purpose, because a commander that could name a cell would be taking the bots'
// decisions for them, which is the whole of the rule this file serves.
//
// file implements: FR-CMD-040
import Foundation

enum Places {
    /// The nine parts of an arena, in the words the state uses for a place.
    enum Part: String, CaseIterable, Equatable, Sendable {
        case middle
        case north = "north side"
        case south = "south side"
        case east = "east side"
        case west = "west side"
        case northEast = "north-east"
        case northWest = "north-west"
        case southEast = "south-east"
        case southWest = "south-west"
    }

    /// The middle of a part, in the arena's own coordinates: the centre of the box
    /// `SquadView.place` would answer that part for.
    ///
    /// A point and not a box, because what the deliberation does with it is measure
    /// nearness (FR-BOT-116): the slope from here to the far corner is what carries a
    /// squad across the arena, and a box would need a rule for what being inside it is
    /// worth against being just outside.
    static func middle(of part: Part, in bounds: ScenePlan.Bounds) -> SIMD3<Double> {
        let span = bounds.highest - bounds.lowest
        let middle = (bounds.highest + bounds.lowest) * Geometry.half
        let quarter = SIMD3<Double>(span.x * aQuarter, .zero, span.z * aQuarter)
        let x: Double
        switch part {
        case .east, .northEast, .southEast: x = (middle.x + quarter.x + bounds.highest.x) * Geometry.half
        case .west, .northWest, .southWest: x = (bounds.lowest.x + middle.x - quarter.x) * Geometry.half
        case .middle, .north, .south: x = middle.x
        }
        let z: Double
        switch part {
        case .south, .southEast, .southWest: z = (middle.z + quarter.z + bounds.highest.z) * Geometry.half
        case .north, .northEast, .northWest: z = (bounds.lowest.z + middle.z - quarter.z) * Geometry.half
        case .middle, .east, .west: z = middle.z
        }
        return SIMD3(x, middle.y, z)
    }

    private static let aQuarter = 0.25
}
