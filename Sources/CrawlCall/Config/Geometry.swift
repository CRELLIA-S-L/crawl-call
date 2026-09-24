// Numbers of geometry that the arithmetic itself fixes, rather than anything a person
// would tune (ART-070): halves, the ends of a segment, which side of a box a point is
// on, and how close two numbers must be to count as the same.
//
// implements: FR-VIEW-150, FR-BOT-050, FR-TOOL-020, FR-MAP-090
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
