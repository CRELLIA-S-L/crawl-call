// What the player is allowed to see through. Two rules share this file because they
// share the switch: a floor above the snake stops being a lid over the room it covers
// (FR-VIEW-140), and anything standing between the camera and the snake stops hiding
// it (FR-VIEW-150). Neither is possible to walk around — the camera's yaw never
// changes — so the picture gives way instead of the player.
//
// Both looks of a module are made once, when the map is built, and swapped as the
// rules change their mind: a material is cheap to keep and not cheap to make.
//
// implements: FR-VIEW-140, FR-VIEW-150
import CoreGraphics
import Foundation
import RealityKit
import UIKit

@MainActor
struct SeeThrough {
    /// One module of the map on screen: what is drawn, where its box stands, the
    /// floor it belongs to, and the two looks it has.
    struct Module {
        let model: ModelEntity
        let level: Int
        let centre: SIMD3<Double>
        let size: SIMD3<Double>
        let solid: [any Material]
        let clear: [any Material]
    }

    private let modules: [Module]
    /// Which modules are see-through now, by their place in `modules`, so that a
    /// module whose look has not changed is not written to sixty times a second.
    private var through: Set<Int> = []

    init(_ modules: [Module]) { self.modules = modules }

    /// A module as the kit's legend colours it.
    static func solid(colour: SIMD3<Double>) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        // `tint:` with a platform colour is the only initialiser the SDK exposes;
        // the value it keeps is a CGColor, but `color:` belongs to another struct.
        // This is the one line of the view that macOS will need its own of.
        material.baseColor = .init(tint: UIColor(red: CGFloat(colour.x),
                                                 green: CGFloat(colour.y),
                                                 blue: CGFloat(colour.z),
                                                 alpha: 1))
        material.roughness = 0.85
        material.metallic = 0.0
        return material
    }

    /// The same module drawn clear: what is behind it reads through its faces, and
    /// its own edges still mark where it is. A wireframe of the module's triangles
    /// was tried instead and rejected — it read as a net and hid what stood under it.
    /// The opacity is settled by eye; it moves into the view configuration
    /// (IF-VIEW-020) if it ever has to be tuned per map.
    static func clear(colour: SIMD3<Double>) -> PhysicallyBasedMaterial {
        var material = solid(colour: colour)
        material.blending = .transparent(opacity: 0.28)
        return material
    }

    /// Whether a box comes within `margin` of the straight line from `eye` to
    /// `point` — the slab test over the segment, against the box grown by that
    /// margin.
    ///
    /// The margin is what makes this a body rather than a point: the snake is drawn
    /// as spheres, and a wall that hides half a sphere hides it, so the box is grown
    /// by the body's own radius and by whatever the view configuration adds on top
    /// of it, which is what starts the fade before the player has lost sight of
    /// anything.
    ///
    /// A module whose top is no higher than the body it would hide is never in the
    /// way of a camera standing above that body: every point of the line is at least
    /// as high as the body itself. That is what keeps the floor the snake is standing
    /// on — which touches the end of the line, and which the margin would otherwise
    /// swallow — solid underfoot.
    nonisolated static func blocks(centre: SIMD3<Double>, size: SIMD3<Double>,
                                   from eye: SIMD3<Double>, to point: SIMD3<Double>,
                                   margin: Double) -> Bool {
        if eye.y > point.y, centre.y + size.y / 2 <= point.y + 1e-9 { return false }
        let direction = point - eye
        var near = 0.0
        var far = 1.0
        for axis in 0..<3 {
            let step = direction[axis]
            let half = size[axis] / 2 + margin
            let low = centre[axis] - half - eye[axis]
            let high = centre[axis] + half - eye[axis]
            if abs(step) < 1e-12 {
                // Parallel to this pair of faces: either inside them for the whole
                // segment, or never.
                if low > 0 || high < 0 { return false }
                continue
            }
            let first = min(low / step, high / step)
            let second = max(low / step, high / step)
            near = max(near, first)
            far = min(far, second)
            if near > far { return false }
        }
        return true
    }

    /// The map as it should be drawn now: solid, except for the floors above the
    /// head (FR-VIEW-140) and whatever stands between the camera and the snake
    /// (FR-VIEW-150).
    mutating func show(headOn level: Int, snake: [SIMD3<Double>],
                       from eye: SIMD3<Double>, margin: Double) {
        var wanted: Set<Int> = []
        for (index, module) in modules.enumerated() {
            if module.level > level {
                wanted.insert(index)
                continue
            }
            for point in snake where Self.blocks(centre: module.centre, size: module.size,
                                                 from: eye, to: point, margin: margin) {
                wanted.insert(index)
                break
            }
        }
        guard wanted != through else { return }
        for index in wanted.subtracting(through) {
            modules[index].model.model?.materials = modules[index].clear
            // A module that went on casting a solid shadow would darken the very
            // thing it was made see-through for.
            modules[index].model.components.set(DynamicLightShadowComponent(castsShadow: false))
        }
        for index in through.subtracting(wanted) {
            modules[index].model.model?.materials = modules[index].solid
            modules[index].model.components.set(DynamicLightShadowComponent(castsShadow: true))
        }
        through = wanted
    }
}
