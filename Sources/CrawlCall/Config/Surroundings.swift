// Numbers of the world around the arena that the method fixes rather than the look
// (ART-070); the look itself — how wide the island is, what colour its water, how
// often birds cross it — is the setting's configuration (IF-GREENHOLM-010, ADR-0031).
//
// implements: FR-MAP-140, FR-GREENHOLM-010, FR-GREENHOLM-020, FR-GREENHOLM-030, FR-MAP-200
import Foundation

/// The camera of a running match, as far as the surroundings must answer for it.
enum MatchCamera {
    /// The pitches FR-VIEW-010 allows, in degrees below the horizontal. The surroundings
    /// cover all of them, not only the one the view configuration ships with, so that
    /// the maintainer can settle the pitch by eye without the world running out.
    static let lowestPitch = 50.0
    static let highestPitch = 60.0
}

/// How the part of the ground a frame can show is found (FR-MAP-140).
enum Coverage {
    /// Degrees between the pitches the reach is computed at. Between two of them the
    /// reach can exceed both by a little; `slack` pays for that.
    static let pitchStep = 0.25
    /// Metres added on every side of the computed reach: the sampling above, and a
    /// frame edge rounded to the pixel, are both far smaller.
    static let slack = 1.0
    /// A frame's four corners, as the signs of their right and up offsets: its footprint
    /// on flat ground is the quadrilateral they meet it at.
    static let cornerSigns: [(right: Double, up: Double)] = [(-1, 1), (1, 1), (1, -1), (-1, -1)]
}

/// The shapes scenery is drawn from, each built once at unit size and scaled per part.
enum SceneryShape {
    /// A unit mesh is one metre across and one high, so its scale is its size.
    static let unit: Float = 1
    /// How rough scenery's surfaces are, 0 a mirror and 1 chalk: matt, as the arena's.
    static let roughness: Float = 0.85
    static let metallic: Float = 0
}

/// Numbers of the island that follow from geometry, not from taste.
enum IslandShape {
    /// Metres the island's banks reach below the water, so that no gap shows at the
    /// waterline from any angle.
    static let submerged = 0.5
    /// Metres of water: a slab, not a plane, so that it has an underside to its top.
    static let waterDepth = 0.1
}

/// Numbers of how the sky picture is painted (FR-GREENHOLM-020).
enum SkyImage {
    /// Pixels down the picture; the gradient is smooth, so more buys nothing visible.
    static let height = 64
    /// An equirectangular picture is twice as wide as it is tall.
    static let widthInHeights = 2
    static let bitsPerComponent = 8
    /// The horizon runs across the middle of an equirectangular picture.
    static let horizon = 0.5
}

/// Numbers of how a bird is drawn and moves (FR-GREENHOLM-030).
enum BirdShape {
    /// A bird's body is this long, this wide and this tall, in its sizes.
    static let bodyLength = 1.0
    static let bodyWidth = 0.3
    static let bodyHeight = 0.25
    /// A wing is this long from the body out, this deep front to back, and thin.
    static let wingSpan = 0.8
    static let wingDepth = 0.35
    static let wingThickness = 0.04
    /// How far up and down a wing swings from level, in degrees.
    static let flapDegrees = 35.0
    /// Where a bird of a flock flies behind and beside the one ahead, in its sizes:
    /// a V, the leader at its point.
    static let behind = 2.5
    static let beside = 2.0
    /// A flock has one leader, and the rest fly in its two arms.
    static let leaders = 1
    static let arms = 2
    /// Flights alternate between the two directions across.
    static let directions = 2
    /// The first flight is one interval into the match, not at its start.
    static let firstFlight = 1
    /// A flock's lanes over the arena, as shares of its depth, taken in turn by the
    /// golden ratio so that no two flights in a row keep to the same line.
    static let laneStep = (5.0.squareRoot() - 1) / 2
}

/// Counting on the grids a setting's edge is drawn on (FR-MAP-200).
enum Distances {
    /// The next sample, and the one extra that a count of steps needs to be a count of
    /// samples.
    static let oneMore = 1
    /// A squared distance, in samples, larger than any grid has: a sample of no set.
    static let far = 1e20
}

/// The corners of a square of samples, in order round it, and the least a polygon is.
enum Square {
    static let origin = 0
    static let across = 1
    static let diagonal = 2
    static let down = 3
    static let triangle = 3
}

/// The grid a setting's edge is drawn on (FR-MAP-200).
enum OutlineGrid {
    /// Metres between samples: the edge is placed between samples by their values, so
    /// it is smooth well below this, and the grid of an arena some tens of metres
    /// across stays within a hundred thousand samples.
    static let step = 0.05
    /// Metres of grid beyond the shore, so that the water's own edge is never cut by
    /// the grid's.
    static let pad = 0.5
}
