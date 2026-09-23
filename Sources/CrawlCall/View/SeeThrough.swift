// What the player is allowed to see through. Three rules share this file because they
// share the switch: a floor above the snake stops being a lid over the room it covers
// (FR-VIEW-140), anything standing between the camera and the snake stops hiding it
// (FR-VIEW-150), and so does anything hiding the ground the head is about to be
// steered over (FR-VIEW-155). None is possible to walk around — the camera's yaw
// never changes — so the picture gives way instead of the player.
//
// Both looks of a module are made once, when the map is built, and swapped as the
// rules change their mind: a material is cheap to keep and not cheap to make.
//
// implements: FR-VIEW-140, FR-VIEW-150, FR-VIEW-155
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

    /// What stands in the way is the map layer's rule, not the view's: the picture
    /// and the bots' eyes have to agree about what a wall is (`Sight`).
    nonisolated static func blocks(centre: SIMD3<Double>, size: SIMD3<Double>,
                                   from eye: SIMD3<Double>, to point: SIMD3<Double>,
                                   margin: Double) -> Bool {
        Sight.blocks(centre: centre, size: size, from: eye, to: point, margin: margin)
    }

    /// The ground the player is kept able to see, and the head it is taken around
    /// (FR-VIEW-155). The two travel together because neither means anything without
    /// the other: the ground says what must stay visible, the head says which side of
    /// it the camera is on.
    struct Window {
        let head: SIMD3<Double>
        let ground: [SIMD3<Double>]
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
        guard reach > 1e-12 else { return false }
        let unitX = awayX / reach, unitZ = awayZ / reach
        let halfX = size.x / 2, halfZ = size.z / 2
        var nearest = Double.greatestFiniteMagnitude
        for stepX in [-halfX, halfX] {
            for stepZ in [-halfZ, halfZ] {
                nearest = min(nearest, (centre.x + stepX - head.x) * unitX
                                     + (centre.z + stepZ - head.z) * unitZ)
            }
        }
        return nearest > 0
    }

    /// The floor the player is kept able to see around the head (FR-VIEW-155): the
    /// walkable cells of the head's own floor whose centres lie within the radius,
    /// as points on the surface. The graph answers what is floor, so a cell the map
    /// never laid is not ground the player is owed a sight of.
    ///
    /// The points lie on the floor's own surface and not at whatever height the head
    /// is at: a head walking a stair has already changed floors and is still climbing
    /// towards it — three metres at three metres a second is a second of it — and a
    /// window hung at that height would be on no floor at all.
    nonisolated static func window(around head: SIMD3<Double>, floor: Int, floorHeight: Double,
                                   radius: Double, cellSize: Double,
                                   in graph: NavigationGraph) -> Window {
        guard radius > 0, cellSize > 0 else { return Window(head: head, ground: []) }
        let surface = Double(floor) * floorHeight
        let reach = Int((radius / cellSize).rounded(.up))
        let here = NavigationGraph.Node(floor: floor,
                                        x: Int((head.x / cellSize).rounded()),
                                        z: Int((head.z / cellSize).rounded()))
        var points: [SIMD3<Double>] = []
        for dx in -reach...reach {
            for dz in -reach...reach {
                let node = NavigationGraph.Node(floor: floor, x: here.x + dx, z: here.z + dz)
                guard graph.isWalkable(node) else { continue }
                let point = SIMD3(Double(node.x) * cellSize, surface, Double(node.z) * cellSize)
                let away = point - head
                guard away.x * away.x + away.z * away.z <= radius * radius else { continue }
                points.append(point)
            }
        }
        return Window(head: head, ground: points)
    }

    /// The map as it should be drawn now: solid, except for the floors above the
    /// head (FR-VIEW-140), whatever stands between the camera and the snake
    /// (FR-VIEW-150), and whatever stands between the camera and the window of
    /// ground around the head (FR-VIEW-155).
    mutating func show(headOn level: Int, snake: [SIMD3<Double>], window: Window? = nil,
                       from eye: SIMD3<Double>, margin: Double) {
        let ground = window?.ground ?? []
        // Every line of the window starts at the eye and ends inside the window, so
        // nothing outside the box holding both can cross one. A module rejected here
        // is one the slab test would reject too, thirty operations later — and the
        // window is scores of points where the snake is a handful (NFR-PERF-010).
        var low = eye, high = eye
        for point in ground {
            low = SIMD3(min(low.x, point.x), min(low.y, point.y), min(low.z, point.z))
            high = SIMD3(max(high.x, point.x), max(high.y, point.y), max(high.z, point.z))
        }

        var wanted: Set<Int> = []
        for (index, module) in modules.enumerated() {
            if module.level > level {
                wanted.insert(index)
                continue
            }
            var hides = false
            for point in snake where Self.blocks(centre: module.centre, size: module.size,
                                                 from: eye, to: point, margin: margin) {
                hides = true
                break
            }
            if !hides, let window, !ground.isEmpty {
                let half = module.size / 2 + SIMD3(repeating: margin)
                let near = module.centre.x + half.x >= low.x && module.centre.x - half.x <= high.x
                    && module.centre.y + half.y >= low.y && module.centre.y - half.y <= high.y
                    && module.centre.z + half.z >= low.z && module.centre.z - half.z <= high.z
                // Nothing standing wholly beyond the head was ever hiding the ground
                // the head is on from a camera in front of it: what it hides is the
                // ground behind itself, which the window has no business clearing
                // (FR-VIEW-155).
                if near, !Self.beyond(centre: module.centre, size: module.size,
                                      from: eye, past: window.head) {
                    for point in ground where Self.blocks(centre: module.centre, size: module.size,
                                                          from: eye, to: point, margin: margin) {
                        hides = true
                        break
                    }
                }
            }
            if hides { wanted.insert(index) }
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
