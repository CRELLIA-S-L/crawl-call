// Numbers of geometry that the arithmetic itself fixes, rather than anything a person
// would tune (ART-070): halves, the ends of a segment, which side of a box a point is
// on, and how close two numbers must be to count as the same.
//
// implements: FR-VIEW-150, FR-BOT-050, FR-TOOL-020, FR-MAP-090, FR-SNAKE-010, FR-VIEW-020, FR-VIEW-100, FR-BOT-080, FR-MAP-270
import Foundation

enum Geometry {
    /// A box's centre is half its size from each face.
    static let half = 0.5

    /// A segment `eye + direction · t` runs from t = start to t = end.
    static let segmentStart = 0.0
    static let segmentEnd = 1.0

    /// Which side of a box, along one axis, a point lies on.
    static let belowSide = -1.0
    static let aboveSide = 1.0

    /// In (a + b·t)², the middle term is this many times a·b·t; and a quadratic
    /// a·t² + b·t + c has its vertex at −b / (this · a).
    static let squareCrossFactor = 2.0

    /// Metres within which two positions are the same position.
    static let samePosition = 1e-9
    /// A direction component smaller than this runs parallel to the faces across it.
    static let parallel = 1e-12
    /// Slack in comparing a squared distance with a squared margin.
    static let squaredSlack = 1e-12
    /// Two cuts of a segment closer than this bound no piece worth measuring.
    static let emptyPiece = 1e-15
}

/// The two ends of a share of something: none of it and all of it. What is left of a
/// magazine is the whole less the share spent, and a nearness runs from the whole at
/// arm's length to nothing at the limit.
enum Fraction {
    static let none = 0.0
    static let whole = 1.0
}

/// The smoothstep curve, 3t² − 2t³: from 0 to 1 with no slope at either end, so that
/// what follows it rises without a kink.
enum SmoothStep {
    static let three = 3.0
    static let two = 2.0
}

extension Geometry {
    /// Degrees in half a turn and in a whole one: an angle in degrees becomes radians
    /// by `.pi / halfTurnDegrees`.
    static let halfTurnDegrees = 180.0
    static let fullTurnDegrees = 360.0
    /// A whole turn, in radians.
    static let fullTurn = Double.pi * 2
    /// A width measured out to both sides of a centre line is this many times what
    /// lies to one side.
    static let bothSides = 2.0
    /// Metres below which a line has no length and no direction.
    static let negligibleLength = 1e-12
    /// A sine below this is looking along the ground rather than down at it.
    static let grazing = 1e-6
    /// The scene's axes: x across, y up.
    static let xAxis = SIMD3<Float>(1, 0, 0)
    static let yAxis = SIMD3<Float>(0, 1, 0)
    /// And z, towards the match camera.
    static let zAxis = SIMD3<Float>(0, 0, 1)
}
