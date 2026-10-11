// How the arena is looked at: the camera it is seen through and the light it is read
// by. Separate from the map layer because they answer a different question — the map
// is what the arena is, this is how it reaches the player.
//
// file implements: FR-VIEW-010, FR-VIEW-020, FR-VIEW-130, FR-TOOL-200, IF-VIEW-020, FR-VIEW-210
import CoreGraphics
import Foundation
import RealityKit

enum SceneView {
    /// Even light from every direction, built from one flat colour: a scene assembled
    /// in code has no environment to be lit by, so one is made.
    @MainActor
    static func ambient(for plan: ScenePlan, view: ViewConfiguration) -> Entity {
        let side = AmbientImage.side
        let width = side * AmbientImage.widthInSides
        // `bytesPerRow` of zero lets Core Graphics choose the row length itself.
        guard let context = CGContext(data: nil, width: width, height: side,
                                      bitsPerComponent: AmbientImage.bitsPerComponent, bytesPerRow: .zero,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            // A 16 × 8 RGB bitmap is not something the system refuses at run time; if
            // it ever did, the scene would be wrong in a way no fallback could hide.
            preconditionFailure(String(describing: SceneError.ambientBitmapNotCreated))
        }
        let sky = view.ambientColour
        context.setFillColor(red: sky.red, green: sky.green, blue: sky.blue, alpha: Colour.opaque)
        context.fill(CGRect(x: .zero, y: .zero, width: width, height: side))
        guard let image = context.makeImage() else {
            preconditionFailure(String(describing: SceneError.ambientBitmapNotReadBack))
        }

        let entity = Entity()
        entity.name = EntityName.ambient
        // `generate(fromEquirectangular:)` is unavailable on iOS; the SDK's
        // replacement is this initialiser, which the compiler names itself.
        guard let resource = try? EnvironmentResource(equirectangular: image) else {
            preconditionFailure(String(describing: SceneError.ambientLightNotGenerated))
        }
        var component = ImageBasedLightComponent(source: .single(resource))
        component.intensityExponent = Float(view.ambientIntensityExponent)
        entity.components.set(component)
        return entity
    }

    /// One bright daylight source, casting the shadows the shapes are read by
    /// (FR-VIEW-130). What it cannot reach is filled by `ambient(for:)`, not by a
    /// second directional light: two suns would cast two shadow directions, and the
    /// requirement asks for a single source on purpose.
    @MainActor
    static func light(for plan: ScenePlan, view: ViewConfiguration) -> Entity {
        let span = Float(max(plan.bounds.extent.x, plan.bounds.extent.z))
        let sun = DirectionalLight()
        sun.name = EntityName.light
        sun.light.intensity = Float(view.sunIntensity)
        sun.light.color = .white
        sun.light.isRealWorldProxy = false
        sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: span * SunShadow.reachInSpans,
                                                      depthBias: SunShadow.depthBias)
        // Down and across, so walls catch the light on one side and shadows fall along
        // the floor rather than under the geometry.
        sun.orientation = simd_quatf(angle: -radians(view.sunElevation), axis: Geometry.xAxis)
            * simd_quatf(angle: radians(view.sunAzimuth), axis: Geometry.yAxis)
        sun.position = SIMD3(Float(plan.bounds.centre.x),
                             Float(plan.bounds.highest.y) + span,
                             Float(plan.bounds.centre.z))
        return sun
    }

    /// A perspective camera at the pitch the view configuration sets, with a yaw that
    /// does not change (FR-VIEW-010). What it looks *at* is FR-VIEW-020's business and
    /// needs a snake; until there is one it frames the whole map.
    @MainActor
    static func camera(for plan: ScenePlan, view: ViewConfiguration) -> Entity {
        let camera = PerspectiveCamera()
        camera.name = EntityName.camera
        camera.camera.fieldOfViewInDegrees = Float(view.cameraFieldOfView)
        let pitch = radians(view.cameraPitch)
        camera.orientation = simd_quatf(angle: -pitch, axis: Geometry.xAxis)
        let target = plan.bounds.centre
        // In Float, as RealityKit takes it; `distance(framing:view:)` is the same
        // product in Double, for what the match computes in Double.
        let back = Float(max(plan.bounds.extent.x, plan.bounds.extent.z)) * Float(view.cameraDistanceInMapWidths)
        camera.position = SIMD3(Float(target.x),
                                Float(target.y) + back * sin(pitch),
                                Float(target.z) + back * cos(pitch))
        return camera
    }

    /// How wide the ground is in view at a given distance, in metres, from the
    /// camera's vertical field of view.
    static func groundSpan(distance: Double, fieldOfViewDegrees: Double) -> Double {
        Geometry.bothSides * distance * tan(fieldOfViewDegrees * .pi / Geometry.fullTurnDegrees)
    }

    /// How far back a camera stands to frame the whole map, in metres (FR-VIEW-020).
    static func distance(framing plan: ScenePlan, view: ViewConfiguration) -> Double {
        max(plan.bounds.extent.x, plan.bounds.extent.z) * view.cameraDistanceInMapWidths
    }

    /// An angle in degrees, in radians, as RealityKit takes it.
    static func radians(_ degrees: Double) -> Float { Float(degrees * .pi / Geometry.halfTurnDegrees) }

    /// Where the camera should look now, given where it looked and where the head is.
    ///
    /// The focus moves only when the head would leave the central region the view
    /// configuration defines (FR-VIEW-020), so the picture holds still while the snake
    /// moves inside it, which is what a fixed-angle camera is for.
    ///
    /// The region's fractions are applied to the ground span of the vertical field of
    /// view, along the depth axis always — conservative, because the pitch
    /// foreshortens it — and across as well for a frame at least as wide as it is
    /// tall. A frame narrower than that, an iPad held upright or a slim window beside
    /// another app (FR-VIEW-210), shows less across than down, and the span across is
    /// narrowed by the frame's aspect, width over height, so the head stays in it.
    static func focus(keeping head: SIMD3<Double>,
                      inside region: ViewConfiguration.CentralRegion,
                      from focus: SIMD3<Double>,
                      distance: Double,
                      fieldOfViewDegrees: Double,
                      aspect: Double = Fraction.whole,
                      within arena: ScenePlan.Bounds) -> SIMD3<Double> {
        let spanDown = groundSpan(distance: distance, fieldOfViewDegrees: fieldOfViewDegrees)
        let spanAcross = spanDown * min(aspect, Fraction.whole)
        let span = spanDown
        let halfX = spanAcross * region.width * Geometry.half
        let halfZ = span * region.height * Geometry.half
        var moved = focus
        moved.x = min(max(focus.x, head.x - halfX), head.x + halfX)
        moved.z = min(max(focus.z, head.z - halfZ), head.z + halfZ)
        // And then no further than the arena: ground past its edge is nothing at all,
        // and a match that begins in a corner spends most of the screen on it
        // (FR-VIEW-020). The window is the span across and the span down that the
        // region above uses: across narrowed by the frame's aspect where the frame is
        // taller than it is wide, down taken whole and so conservative.
        moved.x = stopped(moved.x, half: spanAcross * Geometry.half, between: arena.lowest.x, and: arena.highest.x)
        moved.z = stopped(moved.z, half: span * Geometry.half, between: arena.lowest.z, and: arena.highest.z)
        // Height follows the head outright: a floor change is not something to lag
        // behind, or the snake leaves the frame downwards.
        moved.y = head.y
        return moved
    }

    /// The focus moved over `seconds` towards where it should be as a critically damped
    /// spring moves, carrying its `velocity` across the ground from frame to frame
    /// (FR-VIEW-020): it sets off gently rather than at once at speed, slows as it
    /// arrives, and does not overshoot a target that has stopped. `lag` is the spring's
    /// time, 2/ω: about how long it takes to catch up. The height is taken at once, as
    /// `focus(keeping:)` takes it; no lag is no spring.
    ///
    /// The step is the spring's exact solution over the frame, x(t) = (c + (v + ωc)t)e^(−ωt)
    /// for c the gap to the target, so a long frame does not throw it off.
    static func followed(from focus: SIMD3<Double>, velocity: inout SIMD2<Double>, to target: SIMD3<Double>,
                         seconds: Double, lag: Double) -> SIMD3<Double> {
        guard lag > .zero else {
            velocity = .zero
            return target
        }
        let omega = Geometry.bothSides / lag
        let t = max(seconds, .zero)
        let decay = exp(-omega * t)
        let gap = SIMD2(focus.x - target.x, focus.z - target.z)
        let pull = (velocity + gap * omega) * t
        velocity = (velocity - pull * omega) * decay
        let moved = SIMD2(target.x, target.z) + (gap + pull) * decay
        return SIMD3(moved.x, target.y, moved.y)
    }

    /// Keeps a window of `2 * half` inside the range, or centres it where the range
    /// is narrower than the window and nothing can keep it inside.
    private static func stopped(_ value: Double, half: Double,
                                between low: Double, and high: Double) -> Double {
        guard high - low > Geometry.bothSides * half else { return (low + high) * Geometry.half }
        return min(max(value, low + half), high - half)
    }

    /// The camera that looks at a focus point from a pitch and, in debug mode's free
    /// camera, a yaw (ADR-0023). At no yaw the camera stands on the +z side of the
    /// focus, as every match has it (FR-VIEW-010); a yaw turns it round the focus,
    /// anticlockwise seen from above for a positive one.
    @MainActor
    static func place(_ camera: Entity, lookingAt focus: SIMD3<Double>,
                      pitchDegrees: Double, yawDegrees: Double = .zero, distance: Double) {
        let pitch = radians(pitchDegrees)
        let yaw = radians(yawDegrees)
        camera.orientation = simd_quatf(angle: yaw, axis: Geometry.yAxis)
            * simd_quatf(angle: -pitch, axis: Geometry.xAxis)
        let across = Float(distance) * cos(pitch)
        camera.position = SIMD3(Float(focus.x) + across * sin(yaw),
                                Float(focus.y) + Float(distance) * sin(pitch),
                                Float(focus.z) + across * cos(yaw))
    }

    /// Which way on the ground the screen's right and the screen's down point, for a
    /// camera turned by a yaw: at none, +x and +z.
    static func screenAxes(yawDegrees: Double) -> (right: SIMD2<Double>, down: SIMD2<Double>) {
        let yaw = yawDegrees * .pi / Geometry.halfTurnDegrees
        return (right: SIMD2(cos(yaw), -sin(yaw)), down: SIMD2(sin(yaw), cos(yaw)))
    }
}

/// What building the scene's light can fail at. None of it is something the system
/// refuses at run time for an image this small; each is reported by its kind all the
/// same (FR-TOOL-200).
enum SceneError: IdentifiedError, CaseIterable {
    case ambientBitmapNotCreated
    case ambientBitmapNotReadBack
    case ambientLightNotGenerated

    var identifier: ErrorIdentifier {
        switch self {
        case .ambientBitmapNotCreated:  return .sceneAmbientBitmapNotCreated
        case .ambientBitmapNotReadBack: return .sceneAmbientBitmapNotReadBack
        case .ambientLightNotGenerated: return .sceneAmbientLightNotGenerated
        }
    }

    var details: String {
        switch self {
        case .ambientBitmapNotCreated:  return "the ambient light bitmap could not be created"
        case .ambientBitmapNotReadBack: return "the ambient light bitmap could not be read back"
        case .ambientLightNotGenerated: return "the ambient light could not be generated from a flat image"
        }
    }
}
