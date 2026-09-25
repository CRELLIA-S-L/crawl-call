// What a setting draws, as data a test can read before anything is built (ADR-0031,
// ADR-0034): the ground the map stands on, cut to its outline, the water beyond it,
// and the backdrop.
// Scenery is for the eye only, so it lives here and never in `ScenePlan`, whose pieces
// are what the snake collides with, what the bots see and what is cut open
// (FR-MAP-130).
//
// implements: FR-MAP-130, FR-MAP-140, FR-MAP-200
import Foundation

struct Scenery: Equatable {
    /// One primitive, at unit size scaled to `size`: a box.
    struct Part: Equatable {
        enum Shape: Equatable, CaseIterable { case box }
        /// Which of a setting's layers the part belongs to (ADR-0031).
        enum Layer: Equatable { case ground, water }

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

    /// A surface cut to a shape no primitive has: the island's ground and its walls
    /// along the map's outline, and the water up to its shore (FR-MAP-200).
    struct Surface: Equatable {
        let layer: Part.Layer
        let colour: SIMD3<Double>
        let mesh: Mesh
    }

    let parts: [Part]
    let surfaces: [Surface]
    /// The ground the match camera can show, which the water reaches to (FR-MAP-140).
    let covered: GroundRect
    /// The height of the lowest surface the scenery offers — the water's.
    let surface: Double
    /// The sky above, as its colour straight up and at the horizon (FR-GREENHOLM-020).
    let sky: Sky?
    /// Birds that cross over the arena now and then (FR-GREENHOLM-030).
    let birds: Birds?
    /// How rough the water's surface is, 0 a mirror and 1 chalk (FR-GREENHOLM-060).
    let waterRoughness: Double
    /// How strongly the water reflects, 0 not at all (FR-GREENHOLM-060).
    let waterSpecular: Double
    /// The glints that move across the water (FR-GREENHOLM-070).
    let ripple: Ripple

    struct Ripple: Equatable {
        /// Metres from one wave to the next, and metres a second they travel.
        let wavelength: Double
        let speed: Double
        /// How far a glint lifts the water's colour towards white, 0 to 1.
        let strength: Double
        /// How steep the waves are: the largest tilt of the surface, as rise over run.
        let slope: Double
    }

    struct Sky: Equatable {
        let zenith: SIMD3<Double>
        let horizon: SIMD3<Double>
    }
}
