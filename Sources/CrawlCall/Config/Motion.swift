// Numbers of how the snake's body is moved that the method fixes rather than the
// tuning (ART-070): how small a movement is no movement, how many times a step is
// retried along what stopped it, how precisely a contact is found.
//
// file implements: FR-SNAKE-010, FR-SNAKE-015, FR-SNAKE-020, FR-SNAKE-030, FR-SNAKE-220, FR-SNAKE-270, FR-SNAKE-280, FR-SNAKE-055, FR-SNAKE-016
import Foundation

enum Motion {
    /// Metres the head may rise onto its own body, or come down off it, for each metre it
    /// covers on the ground (FR-SNAKE-055, ADR-0067): steep enough to rest on a body it
    /// crosses squarely by the time it is over it, not so steep that it jumps.
    static let liftSlope = 2.0
    /// Metres the head may rise onto its own body for each metre it covers: steeper than
    /// it comes down, so that a head going round an obstacle straight onto its body at the
    /// whole of its speed (FR-SNAKE-015) is up on it before it is into it.
    static let liftRise = 4.0
    /// The share of the held direction that must run along an obstacle for the stick to
    /// lean to a side of it: five degrees off square (sin 5°). Less, and it leans to
    /// neither, so that a stick held at a point just past an obstacle does not swing the
    /// head from one side of it to the other (FR-SNAKE-015, FR-SNAKE-016, ADR-0069).
    static let leanShare = 0.0872
    /// Metres along each way round an obstacle a head pushed squarely into it looks for
    /// room, to go round by the roomier (FR-SNAKE-015, ADR-0069): two body widths.
    static let roomProbe = 1.2
    /// Metres below which what is left of a frame's distance, or what a step covered,
    /// is no movement at all.
    static let negligibleDistance = 1e-12
    /// The share of a step that runs along an obstacle below which there is nothing
    /// left to slide along.
    static let negligibleShare = 1e-9
    /// The share of a unit direction along one axis below which that axis carries no
    /// part of a step worth taking.
    static let negligibleAxisShare = 1e-12
    /// Metres: the shortest piece a frame is walked in, however small the cells.
    static let shortestPiece = 1e-6
    /// A step is tried the way asked for, then along what stopped it, then along a
    /// second thing where the first led into a corner (FR-SNAKE-015).
    static let slideAttempts = 3
    /// Metres: the search for where the body touches stops once it has narrowed the
    /// contact to this.
    static let contactPrecision = 1e-7
    /// Metres of slack in asking whether a step goes no deeper into something than the
    /// body already is.
    static let depthSlack = 1e-12
    /// Metres the body may be inside something and still count as standing clear.
    static let overlapTolerance = 1e-9
    /// How many times a body set down inside something is moved out of it before
    /// the place is given up (ADR-0021).
    static let pushOutAttempts = 8
    /// The body is as tall as it is wide: its height is this many radii (ADR-0021).
    static let heightInRadii = 2.0
    /// Which way a climb goes along y.
    static let down = -1.0
    static let up = 1.0
    /// Metres between the landings tried for a drop's arc, from the farthest the
    /// speed and the fall allow back to straight down (FR-SNAKE-220, ADR-0040), and
    /// between the places along its way where the body is asked whether it fits.
    static let arcSearchStep = 0.05
    static let arcCheckStep = 0.1
    /// The fall's height goes as the square of the share of its time gone by.
    static let fallPower = 2.0
}

extension Motion {
    /// The tail's segments are spaced a body's width apart along the path: two radii.
    static let widthInRadii = 2.0
}

/// How a lunge's travel eases out (FR-SNAKE-270, ADR-0052): its speed at a share u of
/// its time is `peak` · (1 − u²) times its average, fastest as it sets off and nothing
/// as it ends. `peak` is 3/2, which makes the average one; `covered` is its integral,
/// the share of the reach covered by the share u of the time.
enum LungeEase {
    static let peak = 1.5
    static let cube = 3.0

    static func covered(_ u: Double) -> Double {
        let t = min(max(u, .zero), Fraction.whole)
        return peak * (t - t * t * t / cube)
    }
}

/// How the room for a coil is found (FR-SNAKE-280, ADR-0053): the points round the ring
/// the body is tried at, the ways round the bot a place is looked for, and the step
/// outwards between rings of places, in metres.
enum CoilRoom {
    static let ringPoints = 16
    static let searchWays = 16
    static let searchStep = 0.1
}
