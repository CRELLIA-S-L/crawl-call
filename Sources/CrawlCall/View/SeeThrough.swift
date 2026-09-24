// What the player is allowed to see through. Three rules share this file because they
// share the switch: a floor above the snake stops being a lid over the room it covers
// (FR-VIEW-140), anything standing between the camera and the snake stops hiding it
// (FR-VIEW-150), and so does anything standing near the head, where the snake is
// about to be steered (FR-VIEW-155). None is possible to walk around — the camera's
// yaw never changes — so the picture gives way instead of the player.
//
// A floor above fades whole. Anything else is cut open: a hole in the module's own
// material, around where the line of sight goes through it or around the head, and
// the rest of the module left standing (ADR-0020).
//
// The looks of a module are made once, when the map is built, and swapped as the
// rules change their mind: a material is cheap to keep and not cheap to make.
//
// implements: FR-VIEW-140, FR-VIEW-150, FR-VIEW-155
import CoreGraphics
import Foundation
import Metal
import RealityKit
import UIKit

@MainActor
struct SeeThrough {
    /// One module of the map on screen: what is drawn, where its box stands, the
    /// floor it belongs to, and its looks: solid, faded whole, and cut open.
    struct Module {
        let model: ModelEntity
        let level: Int
        let centre: SIMD3<Double>
        let size: SIMD3<Double>
        let solid: [any Material]
        let clear: [any Material]
        /// The module drawn through the hole shader, where the shader loaded; nil
        /// otherwise, and then a module that wants a hole fades whole instead, as it
        /// did before ADR-0020 — never worse than that.
        var holed: [any Material]? = nil
    }

    private let modules: [Module]
    private let boxes: [Box]
    /// What was drawn last frame, by place in `modules`, so that a module whose look
    /// has not changed is not written to sixty times a second. A hole moves with the
    /// snake, so a module that has one is written every frame regardless.
    private var lids: Set<Int> = []
    private var cut: Set<Int> = []

    init(_ modules: [Module]) {
        self.modules = modules
        self.boxes = modules.map { Box(centre: $0.centre, size: $0.size, level: $0.level) }
    }

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

    /// The module's own look drawn through the hole shader (ADR-0020). Nil where Metal
    /// or the function is not there, and the module then falls back to fading whole.
    ///
    /// The contract is the SDK's (RealityKitSurfaceShader.h, iOS 27.0): the function
    /// is looked up in the app's default library, which Xcode builds from every
    /// .metal file in the target; transparent blending, because opaque blending would
    /// throw the shader's opacity away.
    static func holed(from solid: any Material) -> CustomMaterial? {
        guard let library = holeLibrary else { return nil }
        let shader = CustomMaterial.SurfaceShader(named: Resource.holeShader, in: library)
        guard var holed = try? CustomMaterial(from: solid, surfaceShader: shader) else { return nil }
        holed.blending = .transparent(opacity: 1.0)
        return holed
    }
    private static let holeLibrary: (any MTLLibrary)? = MTLCreateSystemDefaultDevice()?.makeDefaultLibrary()

    /// What stands in the way is the map layer's rule, not the view's: the picture
    /// and the bots' eyes have to agree about what a wall is (`Sight`).
    nonisolated static func blocks(centre: SIMD3<Double>, size: SIMD3<Double>,
                                   from eye: SIMD3<Double>, to point: SIMD3<Double>,
                                   margin: Double) -> Bool {
        Sight.blocks(centre: centre, size: size, from: eye, to: point, margin: margin)
    }

    /// Whether a module stands wholly further from the camera than the head does,
    /// measured across the ground (FR-VIEW-155).
    ///
    /// Across the ground, and not by the plane the camera looks along: that plane is
    /// tilted by the camera's pitch, and the top of a waist-high fence behind the head
    /// falls on the camera's side of it, which would make the test say nothing. The
    /// margin takes no part either — it is room to the side of a line, not room past
    /// its end — or the ring of cells touching the head is cleared all over again.
    nonisolated static func beyond(centre: SIMD3<Double>, size: SIMD3<Double>,
                                   from eye: SIMD3<Double>, past head: SIMD3<Double>) -> Bool {
        let awayX = head.x - eye.x, awayZ = head.z - eye.z
        let reach = (awayX * awayX + awayZ * awayZ).squareRoot()
        // A camera directly overhead has no direction across the ground, and nothing
        // it sees is beyond anything else.
        guard reach > Geometry.negligibleLength else { return false }
        let unitX = awayX / reach, unitZ = awayZ / reach
        let halfX = size.x * Geometry.half, halfZ = size.z * Geometry.half
        var nearest = Double.greatestFiniteMagnitude
        for stepX in [-halfX, halfX] {
            for stepZ in [-halfZ, halfZ] {
                nearest = min(nearest, (centre.x + stepX - head.x) * unitX
                                     + (centre.z + stepZ - head.z) * unitZ)
            }
        }
        return nearest > .zero
    }

    /// A hole cut in a module (ADR-0020), and the shape it is cut in.
    ///
    /// Around a point: a sphere, clear at the point and solid beyond the radius — the
    /// window around the head (FR-VIEW-155). Along a line of sight: every part of the
    /// module within the radius of the line from the camera to a point of the snake,
    /// and nearer the camera than that point (FR-VIEW-150). The second is what the
    /// module needs when something stands in front of the snake: a thin partition
    /// crossed by a steep line of sight is in the way along an ellipse a few tenths of
    /// a metre across, and a sphere holding that stretch of line would clear the whole
    /// partition, which is what the first build of this did on the phone.
    struct Hole: Equatable {
        enum Shape: Equatable {
            case around(SIMD3<Double>)
            case along(SIMD3<Double>)
        }
        let shape: Shape
        let radius: Double

        /// As the shader takes it, in the one four-component value a material carries:
        /// the point, and the radius — positive around it, negative along the line of
        /// sight to it.
        var parameter: SIMD4<Float> {
            switch shape {
            case .around(let c): return SIMD4(Float(c.x), Float(c.y), Float(c.z), Float(radius))
            case .along(let p): return SIMD4(Float(p.x), Float(p.y), Float(p.z), -Float(radius))
            }
        }
    }

    /// A module's place and floor, which is all the choosing needs to know of it.
    struct Box {
        let centre: SIMD3<Double>
        let size: SIMD3<Double>
        let level: Int
    }

    /// Which modules are cut open, and where (ADR-0020). A floor above the head is not
    /// among them — it is a lid and fades whole (FR-VIEW-140) — and a module missing
    /// from the answer stays solid.
    ///
    /// A module in front of the snake is cut along the lines of sight to the parts it
    /// hides, to the margin — the same margin that says it is in the way. A module
    /// near the head, higher than the floor the head is on and not wholly beyond it,
    /// is cut around the head to the visibility radius. A module that is both is cut
    /// with one sphere holding everything either would clear. The hole is only ever
    /// wider than it has to be, never narrower.
    ///
    /// `surface` is the height of the floor the head is on, and not the head's own
    /// height: a head walking a stair has already changed floors and is a second's
    /// climb short of the surface, and a height test against it would cut open the
    /// very balcony it is climbing onto.
    nonisolated static func holes(in boxes: [Box], headOn level: Int, head: SIMD3<Double>,
                                  surface: Double, snake: [SIMD3<Double>],
                                  from eye: SIMD3<Double>, margin: Double,
                                  visibilityRadius: Double) -> [Int: Hole] {
        var answer: [Int: Hole] = [:]
        for (index, box) in boxes.enumerated() where box.level <= level {
            // Every part of the snake this module stands in front of (FR-VIEW-150),
            // with where its line of sight goes through the module.
            var hidden: [(part: SIMD3<Double>, crossing: (SIMD3<Double>, SIMD3<Double>))] = []
            for point in snake {
                if let crossing = Sight.crossing(centre: box.centre, size: box.size,
                                                 from: eye, to: point, margin: margin) {
                    hidden.append((point, crossing))
                }
            }
            // The ground around the head (FR-VIEW-155): near enough, higher than the
            // floor the head is on so that floor is never opened onto the void, and not
            // wholly beyond the head.
            let window = visibilityRadius > .zero
                && box.centre.y + box.size.y * Geometry.half > surface + Geometry.samePosition
                && !beyond(centre: box.centre, size: box.size, from: eye, past: head)
                && distance(from: head, to: box) <= visibilityRadius

            switch (hidden.isEmpty, window) {
            case (true, false):
                continue
            case (true, true):
                answer[index] = Hole(shape: .around(head), radius: visibilityRadius)
            case (false, false):
                // Cut along the line of sight to the middle of the parts it hides, wide
                // enough for the farthest of them: the lines to them all start at the
                // camera and spread towards the snake, so where they pass the module
                // they are no further apart than at the snake itself.
                let aim = hidden.reduce(SIMD3<Double>.zero) { $0 + $1.part } / Double(hidden.count)
                let spread = hidden.map { length($0.part - aim) }.max() ?? .zero
                answer[index] = Hole(shape: .along(aim), radius: margin + spread)
            case (false, true):
                // Both at once, which is the ordinary case beside the head: one sphere
                // holding every stretch of line through the module and the head's own
                // window. Wider than either needs, never narrower (ADR-0020).
                var spheres = hidden.map { entry -> (SIMD3<Double>, Double) in
                    let (from, to) = entry.crossing
                    return ((from + to) * Geometry.half, margin + length(to - from) * Geometry.half)
                }
                spheres.append((head, visibilityRadius))
                let centre = spheres.reduce(SIMD3<Double>.zero) { $0 + $1.0 } / Double(spheres.count)
                let reach = spheres.map { length($0.0 - centre) + $0.1 }.max() ?? .zero
                answer[index] = Hole(shape: .around(centre), radius: reach)
            }
        }
        return answer
    }

    nonisolated static func length(_ v: SIMD3<Double>) -> Double {
        (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
    }

    /// How far a point is from the nearest part of a box; nothing, where it is inside.
    nonisolated static func distance(from point: SIMD3<Double>, to box: Box) -> Double {
        let low = box.centre - box.size * Geometry.half
        let high = box.centre + box.size * Geometry.half
        let nearest = SIMD3(min(max(point.x, low.x), high.x),
                            min(max(point.y, low.y), high.y),
                            min(max(point.z, low.z), high.z))
        let d = point - nearest
        return (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot()
    }

    /// The map as it should be drawn now: solid, except for the floors above the
    /// head, which fade whole (FR-VIEW-140), and whatever `holes` chooses, which is cut
    /// open (FR-VIEW-150, FR-VIEW-155, ADR-0020).
    mutating func show(headOn level: Int, head: SIMD3<Double>, surface: Double,
                       snake: [SIMD3<Double>], from eye: SIMD3<Double>,
                       margin: Double, visibilityRadius: Double) {
        let nowLids = Set(boxes.indices.filter { boxes[$0].level > level })
        let holes = Self.holes(in: boxes, headOn: level, head: head, surface: surface,
                               snake: snake, from: eye, margin: margin,
                               visibilityRadius: visibilityRadius)
        let nowCut = Set(holes.keys)

        for (index, hole) in holes {
            if var holed = modules[index].holed?.first as? CustomMaterial {
                holed.custom.value = hole.parameter
                modules[index].model.model?.materials = [holed]
                // It still stands; only a patch of it is see-through (ADR-0020).
                modules[index].model.components.set(DynamicLightShadowComponent(castsShadow: true))
            } else if !cut.contains(index) {
                modules[index].model.model?.materials = modules[index].clear
                modules[index].model.components.set(DynamicLightShadowComponent(castsShadow: false))
            }
        }
        for index in nowLids.subtracting(lids) {
            modules[index].model.model?.materials = modules[index].clear
            // A module that went on casting a solid shadow would darken the very
            // thing it was made see-through for.
            modules[index].model.components.set(DynamicLightShadowComponent(castsShadow: false))
        }
        for index in lids.union(cut).subtracting(nowLids).subtracting(nowCut) {
            modules[index].model.model?.materials = modules[index].solid
            modules[index].model.components.set(DynamicLightShadowComponent(castsShadow: true))
        }
        lids = nowLids
        cut = nowCut
    }
}
