// Numbers of how drawn things are set in motion and pooled, which the mechanism fixes
// rather than the look (ART-070). What the models themselves look like — sizes,
// colours, materials — waits for their rework (Q-280).
//
// implements: FR-VIEW-170, FR-MAP-210
import Foundation

/// How a module drawn as a figure fills its box (ADR-0034). Only the drawing: for sight
/// and for the body the module is its box.
enum ModuleFigures {
    /// A tree: a trunk this share of the box's height, as wide as this share of the
    /// box, under a cone of crown wider than the box by this much, so that neighbouring
    /// trees meet as a canopy.
    static let trunkShare = 0.3
    static let trunkWidthShare = 0.3
    static let crownWidthShare = 1.4
    /// A shrub: a sphere as tall as the box and this much wider.
    static let shrubWidthShare = 1.2
    /// Primitives are generated at unit size and scaled.
    static let unit: Float = 1
    static let unitRadius: Float = 0.5
}

/// The pool of tracer bars the shots are drawn with (FR-VIEW-170).
enum Tracers {
    /// A bot fires at most once a deliberation step and a shot lasts exactly one, so
    /// two bars per bot cover a frame long enough to carry two steps.
    static let perBot = 2
    /// A pool is never empty, so that a match with no bots still has somewhere to put
    /// a shot.
    static let least = 1
    /// A bar is made one metre deep along +z and scaled to the shot's length.
    static let unitLength: Float = 1
    static let lengthAxis = SIMD3<Float>(0, 0, 1)
    /// Metres below which a shot has no direction to be drawn along.
    static let shortest: Float = 1e-6
}
