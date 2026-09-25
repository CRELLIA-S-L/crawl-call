// Numbers of how drawn things are set in motion and pooled, which the mechanism fixes
// rather than the look (ART-070). What the models themselves look like — sizes,
// colours, materials — waits for their rework (Q-280).
//
// implements: FR-VIEW-170, FR-MAP-210, FR-VIEW-240, FR-VIEW-250, FR-VIEW-260, FR-VIEW-270, FR-VIEW-280
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

/// How much a drawn box's edges are rounded (FR-VIEW-240): this radius, or this
/// share of the box's smallest side where that is less, so that a thin partition is
/// not rounded into a bolster. Only the drawing: for sight and for the body a box has
/// square edges.
enum Rounding {
    static let radius: Float = 0.03
    static let smallestSideShare: Float = 0.25
    /// Segments across each rounded edge and corner. RealityKit's own rounded box has
    /// no such number and is 13 068 triangles at any size; an extruded one at two
    /// segments is 328 (ADR-0037).
    static let segments = 2
}

/// The shape of the snake's body (FR-VIEW-250): a tube round a line through the head
/// and every point of the tail.
enum SnakeShape {
    /// Faces round the tube, and rings between one point of the tail and the next:
    /// ten by three is sixty triangles a point, under the requirement's sixty-four.
    static let sides = 10
    static let ringsBetweenPoints = 3
    /// Rings that round off each end, the last of them the end's point.
    static let endRings = 4
    /// The share of the body's length, from the tail's end, over which it narrows, and
    /// the share of its radius left at the end before the end is rounded off.
    static let taperShare = 0.35
    static let tipShare = 0.18
    /// Metres below which two points of the line are one.
    static let samePoint = 1e-6
    /// Which way a snake that has not moved yet points: along -z, away from the camera.
    static let restingDirection = SIMD3<Double>(0, 0, -1)
    /// The head (FR-VIEW-260): how much wider than the body it is, and over how many
    /// metres behind it the body swells to that.
    static let headShare = 1.3
    static let headLength = 0.5
}

/// The snake's skin (FR-VIEW-270): its green, the darker green of its spots, and how
/// rough it is — a little glossy, 0 a mirror and 1 chalk.
enum SnakeSkin {
    static let green = SIMD3<Double>(0.33, 0.76, 0.3)
    static let spots = SIMD3<Double>(0.13, 0.42, 0.17)
    static let roughness: Float = 0.45
}

/// A meal's swelling on the body (FR-VIEW-280): how much wider it makes the body at
/// its middle, as a share of the radius, at its full size; over how many metres it
/// fades out either side of its middle — the width of its bell; where behind the
/// head it sits while the prey goes in, in metres; and how fast it travels down the
/// body once the meal is over, in metres a second.
enum SnakeLump {
    static let swell = 0.6
    static let width = 0.3
    static let behindHead = 0.45
    static let speed = 1.5
}

/// The snake's eyes (FR-VIEW-260), in shares of the head's radius: how big an eye is,
/// how far out from the head's centre it sits and in which direction — forward, up
/// and to the side — how big its pupil is as a share of the eye, how far out on the
/// eye the pupil sits, and the faces of the sphere they are made of.
enum SnakeEyes {
    static let size = 0.4
    static let out = 0.82
    static let forward = 0.45
    static let up = 0.75
    static let side = 0.48
    static let pupilSize = 0.5
    static let pupilOut = 0.62
    static let rings = 8
    static let segments = 12
    static let white = SIMD3<Double>(0.98, 0.98, 0.95)
    static let pupil = SIMD3<Double>(0.07, 0.07, 0.09)
    static let roughness: Float = 0.35
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
