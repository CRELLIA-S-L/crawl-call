// How much ground the match camera can show around the arena (FR-MAP-140): the
// arithmetic a setting is sized by, kept apart from RealityKit so that a test can
// check it against a derivation of its own (ADR-0031).
//
// The camera looks at a focus point from the +z side, pitched down, with a vertical
// field of view (`PerspectiveCameraComponent.fieldOfViewOrientation` defaults to
// vertical in the iOS 27.0 SDK). A frame's footprint on flat ground is the
// quadrilateral its four corner rays meet the ground at, and every coordinate of it is
// affine in the drop from the focus to the ground and in the frame's aspect, so their
// extremes are at the ends of their ranges; the pitch is sampled.
//
// implements: FR-MAP-140, FR-TOOL-200, FR-MAP-200
import Foundation

/// The camera a match can be seen through, over the whole range it can take.
struct CameraRange: Equatable {
    /// Degrees below the horizontal: the range FR-VIEW-010 allows.
    let pitches: ClosedRange<Double>
    /// The vertical field of view, in degrees.
    let fieldOfView: Double
    /// Metres from the camera to the point it looks at.
    let distance: Double
    /// The widest frame, width over height, the game can be given on this device.
    let widestAspect: Double
    /// The pitch the view configuration ships, in degrees: what a match is seen at
    /// unless the maintainer changes it, inside `pitches`.
    let pitch: Double

    /// The match camera of a view configuration over a plan (FR-VIEW-010, FR-VIEW-020).
    init(view: ViewConfiguration, plan: ScenePlan, widestAspect: Double) {
        self.init(pitches: MatchCamera.lowestPitch...MatchCamera.highestPitch,
                  fieldOfView: view.cameraFieldOfView,
                  distance: SceneView.distance(framing: plan, view: view),
                  widestAspect: widestAspect, pitch: view.cameraPitch)
    }

    init(pitches: ClosedRange<Double>, fieldOfView: Double, distance: Double, widestAspect: Double,
         pitch: Double? = nil) {
        self.pitches = pitches
        self.fieldOfView = fieldOfView
        self.distance = distance
        self.widestAspect = widestAspect
        self.pitch = pitch ?? pitches.lowerBound
    }
}

/// A rectangle on the ground, x across and z towards the camera.
struct GroundRect: Equatable {
    let lowest: SIMD2<Double>
    let highest: SIMD2<Double>

    func contains(_ other: GroundRect) -> Bool {
        all(lowest .<= other.lowest) && all(highest .>= other.highest)
    }

    func contains(_ point: SIMD2<Double>) -> Bool {
        all(lowest .<= point) && all(point .<= highest)
    }

    func grown(by margin: Double) -> GroundRect {
        GroundRect(lowest: lowest - margin, highest: highest + margin)
    }

    /// This rectangle less `hole`, as up to four rectangles round it: the strips
    /// before and after it along z, the full width, and the two beside it between them.
    func around(_ hole: GroundRect) -> [GroundRect] {
        let low = pointwiseMax(hole.lowest, lowest), high = pointwiseMin(hole.highest, highest)
        guard low.x < high.x, low.y < high.y else { return [self] }
        return [GroundRect(lowest: lowest, highest: SIMD2(highest.x, low.y)),
                GroundRect(lowest: SIMD2(lowest.x, high.y), highest: highest),
                GroundRect(lowest: SIMD2(lowest.x, low.y), highest: SIMD2(low.x, high.y)),
                GroundRect(lowest: SIMD2(high.x, low.y), highest: SIMD2(highest.x, high.y))]
            .filter { $0.highest.x > $0.lowest.x && $0.highest.y > $0.lowest.y }
    }
}

enum FrameCoverage {
    /// How far past the point looked at the frame reaches on the ground: `beyond` it,
    /// away from the camera; `toward` the camera; and `across`, to either side.
    struct Reach: Equatable {
        var beyond: Double
        var toward: Double
        var across: Double
    }

    /// Where a frame's four corners meet a plane `drop` metres below the point looked
    /// at, relative to it: x across, z towards the camera. Nil where a corner looks at
    /// or above the horizon and never meets it.
    static func footprint(pitchDegrees: Double, fieldOfViewDegrees: Double, distance: Double,
                          aspect: Double, drop: Double) -> [SIMD2<Double>]? {
        let pitch = pitchDegrees * .pi / Geometry.halfTurnDegrees
        let halfHeight = tan(fieldOfViewDegrees * .pi / Geometry.fullTurnDegrees)
        let halfWidth = halfHeight * aspect
        // The camera's own axes, in the scene: it looks down and towards -z.
        let forward = SIMD3(Fraction.none, -sin(pitch), -cos(pitch))
        let up = SIMD3(Fraction.none, cos(pitch), -sin(pitch))
        let right = SIMD3(Fraction.whole, Fraction.none, Fraction.none)
        let camera = SIMD3(Fraction.none, distance * sin(pitch), distance * cos(pitch))
        var corners: [SIMD2<Double>] = []
        for sign in Coverage.cornerSigns {
            let ray = forward + up * (sign.up * halfHeight) + right * (sign.right * halfWidth)
            guard ray.y < -Geometry.grazing else { return nil }
            let along = (camera.y + drop) / -ray.y
            let hit = camera + ray * along
            corners.append(SIMD2(hit.x, hit.z))
        }
        return corners
    }

    /// The reach over every pitch of the range, every frame up to the widest and every
    /// drop between the two given. Nil where some frame sees the horizon.
    static func reach(of camera: CameraRange, drops: ClosedRange<Double>) -> Reach? {
        var reach = Reach(beyond: -.infinity, toward: -.infinity, across: -.infinity)
        var pitch = camera.pitches.lowerBound
        var pitches: [Double] = []
        while pitch < camera.pitches.upperBound {
            pitches.append(pitch)
            pitch += Coverage.pitchStep
        }
        pitches.append(camera.pitches.upperBound)
        for pitch in pitches {
            for drop in [drops.lowerBound, drops.upperBound] {
                guard let corners = footprint(pitchDegrees: pitch, fieldOfViewDegrees: camera.fieldOfView,
                                              distance: camera.distance, aspect: camera.widestAspect,
                                              drop: drop) else { return nil }
                for corner in corners {
                    reach.beyond = max(reach.beyond, -corner.y)
                    reach.toward = max(reach.toward, corner.y)
                    reach.across = max(reach.across, abs(corner.x))
                }
            }
        }
        return reach
    }

    /// The ground a setting must cover at `surface` metres up, for a camera that can
    /// look at any point of the arena's footprint at any height between its lowest and
    /// its highest (FR-VIEW-020 keeps the point inside the arena and at the head's
    /// height). Grown by `Coverage.slack` on every side.
    static func covered(arena: ScenePlan.Bounds, camera: CameraRange, surface: Double) -> GroundRect? {
        let drops = (arena.lowest.y - surface)...(arena.highest.y - surface)
        guard let reach = reach(of: camera, drops: drops) else { return nil }
        return GroundRect(lowest: SIMD2(arena.lowest.x - reach.across, arena.lowest.z - reach.beyond),
                          highest: SIMD2(arena.highest.x + reach.across, arena.highest.z + reach.toward))
            .grown(by: Coverage.slack)
    }

    /// Throws where a frame of the match camera, at the lowest pitch FR-VIEW-010
    /// allows, reaches the horizon: the widest frame does not change that, since the
    /// frame's top edge is level across it.
    static func requireGroundInFrame(view: ViewConfiguration) throws {
        guard footprint(pitchDegrees: MatchCamera.lowestPitch, fieldOfViewDegrees: view.cameraFieldOfView,
                        distance: Fraction.whole, aspect: Fraction.whole, drop: .zero) != nil else {
            throw CoverageError.horizonInFrame(fieldOfView: view.cameraFieldOfView,
                                               lowestPitch: MatchCamera.lowestPitch)
        }
    }

}

/// What finding the coverage can fail at (FR-TOOL-200).
enum CoverageError: IdentifiedError, Equatable {
    /// A frame of the range looks up to the horizon, so no finite world covers it.
    case horizonInFrame(fieldOfView: Double, lowestPitch: Double)

    var identifier: ErrorIdentifier { .settingHorizonInFrame }

    var details: String {
        switch self {
        case .horizonInFrame(let f, let p):
            return "a field of view of \(f) degrees at a pitch of \(p) shows the horizon, which no setting can cover"
        }
    }
}
