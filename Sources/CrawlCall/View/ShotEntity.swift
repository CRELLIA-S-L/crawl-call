// The shots on screen (FR-VIEW-170). A shot is a thin bar from the bot that fired to
// the point it aimed at, in that squad's colour (FR-VIEW-060), and it lasts the
// deliberation period the model gives it.
//
// Drawn rather than simulated: the model has no projectile, so there is nothing to
// animate along the line — the line is the event. A pool of bars is made once and
// moved, because a shot a fifth of a second long would otherwise build and throw
// away a mesh several times a second for every bot in the match.
//
// implements: FR-VIEW-170
import Foundation
import RealityKit

enum ShotEntity {
    /// How thick the bar is, in metres — thin enough to read as a shot at the game
    /// camera's distance and thick enough to be seen at all.
    static let thickness = 0.03

    /// A bar a metre long, scaled to the length of the shot it draws. One per shot
    /// that can be alive at once: a bot fires at most once a deliberation step, and a
    /// shot lasts exactly one, so two per bot covers the frame long enough to carry
    /// two steps.
    @MainActor
    static func make(for bots: [Bot]) -> Entity {
        let root = Entity()
        root.name = "shots"
        let materials: [Squad: PhysicallyBasedMaterial] = [
            .red: BotEntity.material(for: .red), .blue: BotEntity.material(for: .blue),
        ]
        let mesh = MeshResource.generateBox(width: Float(thickness), height: Float(thickness), depth: 1)
        for index in 0..<max(1, bots.count * 2) {
            let squad: Squad = index % 2 == 0 ? .red : .blue
            let bar = ModelEntity(mesh: mesh, materials: [materials[squad] ?? BotEntity.material(for: squad)])
            bar.name = "shot\(index)\(squad == .red ? "r" : "b")"
            bar.isEnabled = false
            root.addChild(bar)
        }
        return root
    }

    /// Puts one bar on every shot there is, and takes the rest off screen.
    ///
    /// A bar is used only for a shot of its own squad, so that the colour is never
    /// the wrong one; a shot with no bar left of its colour is not drawn, which is
    /// the pool running out rather than anything the requirement allows, and the pool
    /// is sized so that it does not.
    @MainActor
    static func update(_ entity: Entity, from shots: [Shot]) {
        var free: [Squad: [Entity]] = [.red: [], .blue: []]
        for bar in entity.children {
            bar.isEnabled = false
            free[bar.name.hasSuffix("r") ? .red : .blue, default: []].append(bar)
        }
        for shot in shots {
            guard let bar = free[shot.squad]?.popLast() else { continue }
            place(bar, from: shot.from, to: shot.to)
            bar.isEnabled = true
        }
    }

    /// The bar laid along the line, its two ends on the two points.
    @MainActor
    static func place(_ bar: Entity, from: SIMD3<Double>, to: SIMD3<Double>) {
        // Both ends as the model has them: it fired from the shooter's eyes at a point
        // of the snake, and the line is the line it took (ADR-0022).
        let start = SIMD3<Float>(Float(from.x), Float(from.y), Float(from.z))
        let end = SIMD3<Float>(Float(to.x), Float(to.y), Float(to.z))
        let along = end - start
        let length = simd_length(along)
        guard length > 1e-6 else {
            bar.isEnabled = false
            return
        }
        bar.position = (start + end) / 2
        // The box is a metre deep and its depth is +z, so the bar is scaled to the
        // length and turned from +z onto the line. `simd_quatf(from:to:)` wants both
        // normalized and handles the opposite-directions case by picking an arbitrary
        // axis, which for a bar that is square in section changes nothing.
        bar.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: along / length)
        bar.scale = SIMD3<Float>(1, 1, length)
    }
}
