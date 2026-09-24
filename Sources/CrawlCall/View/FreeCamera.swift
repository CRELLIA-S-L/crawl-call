// The camera of debug mode, taken off the snake by the user and moved where they want
// it (FR-TOOL-070): nearer and further, across the arena, tilted and turned round what
// it looks at (ADR-0023).
//
// No RealityKit and no touches here: the gestures say how far the fingers moved, the
// session says where the camera goes, and this is the arithmetic between, which a test
// can read.
//
// implements: FR-TOOL-070
import Foundation

struct FreeCamera: Equatable {
    /// The point on the ground the camera looks at.
    private(set) var focus: SIMD3<Double>
    /// How far the camera stands from it, in metres, along its line of sight.
    private(set) var distance: Double
    /// How far below the horizontal it looks, in degrees.
    private(set) var pitch: Double
    /// How far it has been turned round the focus from the match's heading, in degrees;
    /// positive turns it anticlockwise seen from above.
    private(set) var yaw: Double = 0
    /// How near and how far it may be taken, and how low and how steep it may look
    /// (IF-VIEW-020).
    let nearest: Double
    let farthest: Double
    let lowestPitch: Double
    let highestPitch: Double
    /// Where the focus may go: over the arena and no further, the ground past its edge
    /// being nothing to look at (FR-VIEW-020).
    let arena: ScenePlan.Bounds

    init(focus: SIMD3<Double>, distance: Double, pitch: Double,
         nearest: Double, farthest: Double, lowestPitch: Double, highestPitch: Double,
         arena: ScenePlan.Bounds) {
        self.nearest = nearest
        self.farthest = max(farthest, nearest)
        self.lowestPitch = lowestPitch
        self.highestPitch = max(highestPitch, lowestPitch)
        self.arena = arena
        self.focus = focus
        self.distance = min(max(distance, nearest), self.farthest)
        self.pitch = min(max(pitch, lowestPitch), self.highestPitch)
        self.focus = kept(focus)
    }

    /// Pinched by a factor: apart is above one and brings the camera nearer, together
    /// is below one and takes it further, within the limits.
    mutating func zoom(by factor: Double) {
        guard factor > 0, factor.isFinite else { return }
        distance = min(max(distance / factor, nearest), farthest)
    }

    /// Dragged by two fingers, in points on a screen `height` points tall, seen through
    /// a vertical field of view. The ground under the fingers goes with them: the focus
    /// moves the other way, as far on the ground as the drag covers on the screen at
    /// the distance the camera is now, along the screen's own axes as the camera is
    /// turned.
    mutating func pan(by points: SIMD2<Double>, screenHeight height: Double, fieldOfViewDegrees: Double) {
        guard height > 0 else { return }
        let metresPerPoint = SceneView.groundSpan(distance: distance, fieldOfViewDegrees: fieldOfViewDegrees) / height
        // Across the screen is across the ground. Up and down the screen is the ground
        // seen at the pitch, so a point of it covers more ground than a point across.
        let down = sin(pitch * .pi / 180)
        let depth = down > 1e-6 ? metresPerPoint / down : metresPerPoint
        let axes = SceneView.screenAxes(yawDegrees: yaw)
        var moved = focus
        moved.x -= points.x * metresPerPoint * axes.right.x + points.y * depth * axes.down.x
        moved.z -= points.x * metresPerPoint * axes.right.y + points.y * depth * axes.down.y
        focus = kept(moved)
    }

    /// Twisted by two fingers, in radians, clockwise on the screen positive: the ground
    /// turns with the fingers, which is the camera turning the other way round the
    /// point it looks at. No limit: round is round.
    mutating func turn(by radians: Double) {
        guard radians.isFinite else { return }
        yaw = (yaw + radians * 180 / .pi).truncatingRemainder(dividingBy: 360)
    }

    /// Dragged up or down by three fingers, in points on a screen `height` points tall:
    /// up lowers the camera towards the horizon, down raises it to look straight down,
    /// and the whole height of the screen is the whole range the limits allow.
    mutating func tilt(by points: Double, screenHeight height: Double) {
        guard height > 0, points.isFinite else { return }
        let degreesPerPoint = (highestPitch - lowestPitch) / height
        pitch = min(max(pitch + points * degreesPerPoint, lowestPitch), highestPitch)
    }

    private func kept(_ point: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(min(max(point.x, arena.lowest.x), arena.highest.x),
              point.y,
              min(max(point.z, arena.lowest.z), arena.highest.z))
    }
}
