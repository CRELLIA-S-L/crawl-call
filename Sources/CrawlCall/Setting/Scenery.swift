// What a setting draws, as data a test can read before anything is built (ADR-0031):
// the ground around the arena, the rim that closes the space in, and the backdrop.
// Scenery is for the eye only, so it lives here and never in `ScenePlan`, whose pieces
// are what the snake collides with, what the bots see and what is cut open
// (FR-MAP-130).
//
// implements: FR-MAP-130, FR-MAP-140
import Foundation

struct Scenery: Equatable {
    /// One primitive, at unit size scaled to `size`: a box, a cylinder or a cone
    /// standing up, or a sphere.
    struct Part: Equatable {
        enum Shape: Equatable, CaseIterable { case box, cylinder, cone, sphere }
        /// Which of a setting's layers the part belongs to (ADR-0031).
        enum Layer: Equatable { case ground, water, rim }

        let shape: Shape
        let layer: Layer
        /// Width, height and depth of the part's box, in metres.
        let size: SIMD3<Double>
        /// The centre of that box, in metres, with y up.
        let centre: SIMD3<Double>
        /// Red, green and blue in 0…1.
        let colour: SIMD3<Double>

        var top: Double { centre.y + size.y * Geometry.half }
        var lowest: SIMD3<Double> { centre - size * Geometry.half }
        var highest: SIMD3<Double> { centre + size * Geometry.half }
    }

    let parts: [Part]
    /// The ground the match camera can show, which the water reaches to (FR-MAP-140).
    let covered: GroundRect
    /// The height of the lowest surface the scenery offers — the water's.
    let surface: Double
    /// The sky above, as its colour straight up and at the horizon (FR-GREENHOLM-020).
    let sky: Sky?
    /// Birds that cross over the arena now and then (FR-GREENHOLM-030).
    let birds: Birds?

    struct Sky: Equatable {
        let zenith: SIMD3<Double>
        let horizon: SIMD3<Double>
    }
}
