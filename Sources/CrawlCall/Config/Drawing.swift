// Numbers of how drawn things are set in motion and pooled, which the mechanism fixes
// rather than the look (ART-070). What the models themselves look like — sizes,
// colours, materials — waits for their rework (Q-280).
//
// file implements: FR-VIEW-350, FR-VIEW-360, FR-VIEW-370, FR-VIEW-170, FR-MAP-210, FR-VIEW-240, FR-VIEW-250, FR-VIEW-260, FR-VIEW-270, FR-VIEW-280, FR-VIEW-290, FR-VIEW-300, FR-VIEW-310, FR-VIEW-320
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

/// How many faces the game's own shapes are given where RealityKit's would be tens of
/// thousands (ADR-0046): segments round each rounded edge of a bot's figure, and the
/// bands and faces round a figure's head and eyes and round a shrub.
enum LowPoly {
    static let figureCornerSegments = 3
    /// A figure keeps the radius its drawing gives each part, up to just under half
    /// the part's smallest side, past which the extrusion would have no length left.
    static let figureCornerShare: Float = 0.48
    static let figureRings = 10
    static let figureSegments = 16
    static let shrubRings = 10
    static let shrubSegments = 16
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
    /// Points of line the body is made with room for beyond the tail's own: the neck of a
    /// head reared over its meal, its bend and where the match has the head (FR-VIEW-320).
    static let neckPoints = 2
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

/// A lunge drawn as a cartoon (FR-VIEW-310), in shares of the head's size along the way
/// it goes and across it: squashed at the end of the wind-up by `windUpSquash` and
/// widened by `windUpBulge`, stretched through the travel by `stretch` and thinned by
/// `thin`, and squashed where it ends by `landingSquash` and widened by `landingBulge`,
/// easing back to its own shape over `landingSeconds`.
enum LungeLook {
    static let windUpSquash = 0.3
    static let windUpBulge = 0.18
    static let stretch = 0.45
    static let thin = 0.2
    static let landingSquash = 0.3
    static let landingBulge = 0.2
    static let landingSeconds = 0.3
}

/// A living bot swallowed from the top down (FR-VIEW-320): how long the head takes to
/// rear up over the bot at the meal's start and to come down after it, in seconds; how
/// far below the cut the head's line comes, in metres, so that its mouth covers the
/// edge where the figure is cut away; how far it tips mouth-down, in degrees, short of
/// straight down so that its eyes still show; the least of the figure's height left
/// showing under the head, as a share of it, so that its boots never vanish before the
/// match has it gone (FR-VIEW-100); how far behind the reared head the neck bends over,
/// in metres, so that the body comes to the head from above and behind and its end
/// points down at the bot; and the opacity below which the cut figure is not drawn.
enum Swallowing {
    static let rearSeconds = 0.25
    static let mouthSink = 0.05
    static let tipDegrees = 70.0
    static let smallest = 0.15
    static let neckBend = 0.35
    static let cutThreshold = 0.5
}

/// A bot's walk (FR-VIEW-290): metres of ground a stride takes — a step with each foot;
/// how high the figure lifts at each step, in metres; how far it rocks to the side,
/// leans forward and swings each leg, in radians; how fast the walk comes on and dies
/// away, as a share a second; and the speed, in metres a second, below which a bot
/// counts as standing.
enum BotGait {
    static let stride = 1.1
    static let lift = 0.04
    static let rock = 0.1
    static let lean = 0.07
    static let swing = 0.5
    static let easing = 8.0
    static let movingSpeed = 0.2
}

/// A dead bot's figure (FR-VIEW-300): how far above the ground it stands, in metres,
/// lying on its back — half the depth of its torso (`Figure`), so that its back rests on
/// the ground rather than in it.
enum BotBody {
    static let lyingLift = 0.15
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

/// How the treasure is drawn (FR-VIEW-370).
enum Prize {
    /// How big it is drawn, in metres: a chest that can be picked out across the room
    /// and still be carried in front of a bot 1.12 m tall. Half a metre and not a third
    /// of one, which on the phone on 2026-10-14 was a dozen pixels across the arena.
    static let size = SIMD3<Float>(0.5, 0.36, 0.36)
    /// How far above the ground its middle rests while it lies there: half its height,
    /// so that it sits on the floor rather than in it.
    static let lift = 0.18
    /// Where a carrier holds it: at the height of the hands, this far in front of the
    /// chest, so that the figure does not swallow it.
    static let heldAt = 0.62
    static let heldAhead = 0.28
    /// What it is painted. Gold was tried on the phone on 2026-10-14 and taken back:
    /// the kit's crate is (0.85, 0.55, 0.25) and its partition (0.8, 0.72, 0.35), so a
    /// gold box in a room full of crates is a crate. This violet is in nothing the kit
    /// draws and in nothing the setting draws, which is the whole of what is asked of
    /// it — the player has to find the thing across the room.
    static let colour = SIMD3(0.62, 0.28, 0.85)
    static let roughness: Float = 0.3
    static let metallic: Float = 0.9
}

/// The pool of tracer bars the rounds are drawn with (FR-VIEW-170).
/// Numbers of the grenades and blasts on screen (FR-VIEW-350, FR-VIEW-360).
enum Blasts {
    /// How big a grenade is drawn, in metres: a ball an eye can follow across a room
    /// and smaller than the hand that threw it.
    static let grenadeRadius = 0.09
    /// How many blasts can be on screen at once: the pouches cannot all go off in one
    /// moment, and this is room for a knot of them that nearly does.
    static let flashes = 8
    /// A pool is never empty, so that a match with no bots still has somewhere to put
    /// a grenade, and it holds one over what can be thrown, for the frame in which one
    /// is thrown as another goes off. How many that is, is counted where the bots are
    /// known (`BlastEntity`): what a figure is made of is not the configuration's.
    static let least = 1
    static let oneMore = 1
    /// A blast's ball is made one metre across and scaled to what it has grown to.
    static let unitRadius: Float = 1
    /// The smallest a blast is drawn, in metres, so that the frame it goes off in is
    /// something rather than nothing.
    static let smallest = 0.05
    /// What they are painted: a dark ball for the grenade, and a pale cloud for the
    /// blast, see-through so that what it covers is not lost behind it.
    static let grenadeColour = SIMD3(0.18, 0.2, 0.22)
    static let flashColour = SIMD3(1.0, 0.86, 0.45)
    static let flashOpacity = 0.55
}

enum Tracers {
    /// How many rounds one bot can have in flight at once: a round flies the round
    /// range at the round speed, and a bot sends one a deliberation period at most
    /// (FR-BOT-060), so the rounds of that time, and one more for the frame in which
    /// one is sent as another is spent.
    static func perBot(for configuration: BotConfiguration) -> Int {
        guard configuration.roundSpeed > .zero, configuration.deliberationPeriod > .zero else { return perBot }
        let flight = configuration.roundRange / configuration.roundSpeed
        return Int((flight / configuration.deliberationPeriod).rounded(.up)) + oneMore
    }
    static let oneMore = 1
    /// What a pool made without the configuration holds per bot: the shipped one's
    /// 20 m at 25 m/s is 0.8 s, four periods of 0.2 s, and one more.
    static let perBot = 5
    /// Metres of the streak a round is drawn as, behind where it is: about what it
    /// flies in a frame at sixty frames a second at the shipped speed.
    static let streak = 0.5
    /// A pool is never empty, so that a match with no bots still has somewhere to put
    /// a round.
    static let least = 1
    /// A bar is made one metre deep along +z and scaled to the streak's length.
    static let unitLength: Float = 1
    static let lengthAxis = SIMD3<Float>(0, 0, 1)
    /// Metres below which a streak has no direction to be drawn along.
    static let shortest: Float = 1e-6
}
