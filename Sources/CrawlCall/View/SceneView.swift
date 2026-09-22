// How the arena is looked at: the camera it is seen through and the light it is read
// by. Separate from the map layer because they answer a different question — the map
// is what the arena is, this is how it reaches the player.
//
// implements: FR-VIEW-010, FR-VIEW-130
import CoreGraphics
import Foundation
import RealityKit

enum SceneView {
    /// Even light from every direction, built from one flat colour: a scene assembled
    /// in code has no environment to be lit by, so one is made.
    @MainActor
    static func ambient(for plan: ScenePlan) -> Entity {
        let side = 8
        guard let context = CGContext(data: nil, width: side * 2, height: side,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            // A 16 × 8 RGB bitmap is not something the system refuses at run time; if
            // it ever did, the scene would be wrong in a way no fallback could hide.
            preconditionFailure("the ambient light bitmap could not be created")
        }
        context.setFillColor(red: 0.62, green: 0.68, blue: 0.78, alpha: 1)   // daylight sky
        context.fill(CGRect(x: 0, y: 0, width: side * 2, height: side))
        guard let image = context.makeImage() else {
            preconditionFailure("the ambient light bitmap could not be read back")
        }

        let entity = Entity()
        entity.name = "ambient"
        // `generate(fromEquirectangular:)` is unavailable on iOS; the SDK's
        // replacement is this initialiser, which the compiler names itself.
        guard let resource = try? EnvironmentResource(equirectangular: image) else {
            preconditionFailure("the ambient light could not be generated from a flat image")
        }
        var component = ImageBasedLightComponent(source: .single(resource))
        component.intensityExponent = 1.0
        entity.components.set(component)
        return entity
    }

    /// One bright daylight source, casting the shadows the shapes are read by
    /// (FR-VIEW-130). What it cannot reach is filled by `ambient(for:)`, not by a
    /// second directional light: two suns would cast two shadow directions, and the
    /// requirement asks for a single source on purpose.
    @MainActor
    static func light(for plan: ScenePlan) -> Entity {
        let span = Float(max(plan.bounds.extent.x, plan.bounds.extent.z))
        let sun = DirectionalLight()
        sun.name = "light"
        sun.light.intensity = 12_000
        sun.light.color = .white
        sun.light.isRealWorldProxy = false
        sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: span * 2, depthBias: 1.0)
        // Down and across, so walls catch the light on one side and shadows fall along
        // the floor rather than under the geometry.
        sun.orientation = simd_quatf(angle: -.pi / 3, axis: SIMD3(1, 0, 0))
            * simd_quatf(angle: .pi / 5, axis: SIMD3(0, 1, 0))
        sun.position = SIMD3(Float(plan.bounds.centre.x),
                             Float(plan.bounds.highest.y) + span,
                             Float(plan.bounds.centre.z))
        return sun
    }

    /// A perspective camera at the pitch the view configuration sets, with a yaw that
    /// does not change (FR-VIEW-010). What it looks *at* is FR-VIEW-020's business and
    /// needs a snake; until there is one it frames the whole map.
    @MainActor
    static func camera(for plan: ScenePlan, pitchDegrees: Double) -> Entity {
        let camera = PerspectiveCamera()
        camera.name = "camera"
        camera.camera.fieldOfViewInDegrees = 50
        let pitch = Float(pitchDegrees * .pi / 180)
        camera.orientation = simd_quatf(angle: -pitch, axis: SIMD3(1, 0, 0))
        let target = plan.bounds.centre
        let distance = Float(max(plan.bounds.extent.x, plan.bounds.extent.z)) * 1.1
        camera.position = SIMD3(Float(target.x),
                                Float(target.y) + distance * sin(pitch),
                                Float(target.z) + distance * cos(pitch))
        return camera
    }
}
