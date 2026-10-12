// Numbers of how a bot's scores are shaped, which the formulas fix rather than the
// tuning (ART-070); the weight of each term against the others is tuning, and is in
// the bot configuration (IF-BOT-010).
//
// file implements: FR-BOT-450, FR-BOT-340, FR-BOT-080, FR-BOT-090, FR-BOT-210, FR-BOT-150, FR-BOT-160, FR-BOT-060, FR-BOT-270, FR-BOT-280, FR-BOT-050, FR-BOT-230, FR-BOT-400, FR-BOT-430
import Foundation

enum Utility {
    /// The share of its remaining health that takes from a bot's wish for cover: a
    /// whole bot still wants cover half as much as a bot on its last legs.
    static let coverHealthShare = 0.5
}

/// Numbers of who deliberates when (FR-BOT-150, FR-BOT-160).
enum Scheduling {
    /// A bot that has seen the snake, or stands within the interrupt distance of it,
    /// has this many times the claim of one that has not — the "at least three times"
    /// FR-BOT-160 asks for, taken at its word.
    static let urgentImportance = 3
    static let ordinaryImportance = 1
    /// A bot's wait is counted in steps: one for the step it is in, and one more for
    /// every step it goes without a slot.
    static let firstWait = 1
    static let waitStep = 1
}

/// Numbers of a bot walking its route.
enum Walking {
    /// Metres of a step left below which a bot has walked it all.
    static let arrived = 1e-9
    /// How far apart, as a share of a cell, the points are that a straight walk is
    /// tested at (FR-BOT-270): a quarter, so that no cell a line crosses is missed.
    static let lookStep = 0.25
    /// Metres beyond two body radii at which a bot is still up against another: the
    /// room the push apart leaves between two bodies, and a little over (FR-BOT-300).
    static let touching = 0.05
}

/// How a facing is worked out and turned (FR-BOT-280).
enum Turning {
    /// Metres a bot must move, or a point lie away from it, for there to be a way to
    /// face.
    static let noWay = 1e-6

    /// The facing from one point to another, level: the angle round the vertical from
    /// +z towards +x. Nil where the two are one above the other.
    static func angle(from start: SIMD3<Double>, to end: SIMD3<Double>) -> Double? {
        let x = end.x - start.x, z = end.z - start.z
        return (x * x + z * z).squareRoot() > noWay ? atan2(x, z) : nil
    }

    /// `facing` turned towards `wanted` the short way round, by no more than `most`.
    static func toward(_ wanted: Double, from facing: Double, by most: Double) -> Double {
        let half = Double.pi, whole = Double.pi * Geometry.bothSides
        var gap = (wanted - facing).truncatingRemainder(dividingBy: whole)
        if gap > half { gap -= whole }
        if gap < -half { gap += whole }
        return abs(gap) <= most ? wanted : facing + (gap > .zero ? most : -most)
    }
}

/// How a bot looks at the map round it (FR-BOT-230): how far in from a cell's centre,
/// as a share of a cell, towards the bot the point it looks at is — past the edge of
/// what stands in the cell, so that a wall is seen by its face — and how far off the
/// ground, in metres, so that the floor it lies on is not in the way.
///
/// And how a standing bot chooses where to look (FR-BOT-340): the open ground, in
/// metres, before it that is enough for it not to turn — three cells, more than a wall
/// at arm's length and less than a corridor's length — and how many ways round it
/// weighs when it does turn.
enum Looking {
    static let nearSide = 0.55
    static let offGround = 0.05
    static let openEnough = 1.5
    static let ways = 16
}

/// How a bot places the snake's head on the graph (FR-BOT-115): a share of a floor
/// by which a head a hair under a floor's level is still on that floor, so that a
/// rounding in its height does not drop it to the one below.
enum Placing {
    static let floorSlack = 1e-6
}

/// Numbers of a bot with nothing else to do (FR-BOT-360, FR-BOT-370, FR-BOT-380): how
/// near, in metres, a bot must come to where an enemy was last seen to count it gone —
/// two cells, standing where the enemy stood; and how much a way round
/// counts that turns to a threat, against one that only turns away from where the bot
/// looks now — twice, so that a threat is looked at whenever it is not already.
enum Idle {
    static let arrived = 1.0
    static let threatShare = 2.0
}

/// Numbers of firing (FR-BOT-060).
enum Firing {
    /// A shot spends one round of the magazine.
    static let roundsPerShot = 1
    /// Seconds of slack in the comparison of a weapon's time between shots with the
    /// time since its last one (FR-BOT-450). A weapon whose cadence is the
    /// deliberation period must fire at every slot it gets, and the difference of two
    /// times a match added up a frame at a time is the period give or take the last
    /// bits of a double — so the comparison is made with a tolerance, as every other
    /// comparison of two distances or two times in this project is
    /// (`specs/50-verification.md`). A nanosecond is far below any cadence a weapon
    /// could be given and far above the error a match of any length accumulates.
    static let cadenceSlack = 1e-9
}

/// How a round in flight is followed (FR-BOT-060, FR-BOT-400).
enum Flying {
    /// Metres between where a round leaves and where it is sent below which it has no
    /// way to fly.
    static let noWay = 1e-6
    /// Halvings of a frame's flight spent finding where a round first touches a body:
    /// fifty leave less than a nanometre of a metre's flight.
    static let searchSteps = 50
    /// A third of the way in, and two thirds: the two points each narrowing of the
    /// search for the closest approach compares.
    static let lowerThird = 1.0 / 3
    static let upperThird = 2.0 / 3
}

/// How a bot fires from beside cover or on the move (FR-BOT-420, FR-BOT-425, FR-BOT-430).
enum Skirmish {
    /// The two ways across the line of fire, as a sign.
    static let rightward = 1.0
}
