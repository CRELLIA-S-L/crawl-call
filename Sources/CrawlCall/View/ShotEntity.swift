// The rounds on screen (FR-VIEW-170). A round in flight is a short thin bar trailing
// behind where it is, along the way it flies, in that squad's colour (FR-VIEW-060):
// a streak, which is how the eye reads something too quick to follow as a dot.
//
// A pool of bars is made once and moved, because a round lasting under a second would
// otherwise build and throw away a mesh several times a second for every bot in the
// match.
//
// implements: FR-VIEW-170, FR-VIEW-240
import Foundation
import RealityKit

enum ShotEntity {
    /// How thick the bar is, in metres — thin enough to read as a shot at the game
    /// camera's distance and thick enough to be seen at all.
    static let thickness = 0.03

    /// A bar a metre long, scaled to the length of the streak it draws. `perBot` per
    /// bot: as many rounds as one bot can have in flight at once (`Tracers.perBot(for:)`).
    @MainActor
    static func make(for bots: [Bot], perBot: Int = Tracers.perBot) -> Entity {
        let root = Entity()
        root.name = EntityName.shots
        let materials: [Squad: PhysicallyBasedMaterial] = [
            .red: BotEntity.material(for: .red), .blue: BotEntity.material(for: .blue),
        ]
        let mesh = MeshResource.roundedBox(SIMD3(Float(thickness), Float(thickness), Tracers.unitLength))
        for index in Int.zero..<max(Tracers.least, bots.count * perBot) {
            // The squads take turns down the pool, so each has half of it.
            let squad = Squad.allCases[index % Squad.allCases.count]
            let bar = ModelEntity(mesh: mesh, materials: [materials[squad] ?? BotEntity.material(for: squad)])
            bar.name = EntityName.numbered(EntityName.shot, index)
                + (squad == .red ? EntityName.redSquadSuffix : EntityName.blueSquadSuffix)
            bar.isEnabled = false
            root.addChild(bar)
        }
        return root
    }

    /// Puts one bar on every round in flight, and takes the rest off screen: from where
    /// the round is back along its way by the streak's length, or by as far as it has
    /// flown where that is less, so that no streak reaches behind the shooter's eyes.
    ///
    /// A bar is used only for a round of its own squad, so that the colour is never
    /// the wrong one; a round with no bar left of its colour is not drawn, which is
    /// the pool running out rather than anything the requirement allows, and the pool
    /// is sized so that it does not.
    @MainActor
    static func update(_ entity: Entity, from rounds: [Round]) {
        var free: [Squad: [Entity]] = [.red: [], .blue: []]
        for bar in entity.children {
            bar.isEnabled = false
            free[bar.name.hasSuffix(EntityName.redSquadSuffix) ? .red : .blue, default: []].append(bar)
        }
        for round in rounds {
            guard let bar = free[round.squad]?.popLast() else { continue }
            let tail = round.position - round.direction * min(Tracers.streak, round.flown)
            bar.isEnabled = true
            place(bar, from: tail, to: round.position)
        }
    }

    /// The bar laid along the line, its two ends on the two points.
    @MainActor
    static func place(_ bar: Entity, from: SIMD3<Double>, to: SIMD3<Double>) {
        let start = SIMD3<Float>(Float(from.x), Float(from.y), Float(from.z))
        let end = SIMD3<Float>(Float(to.x), Float(to.y), Float(to.z))
        let along = end - start
        let length = simd_length(along)
        guard length > Tracers.shortest else {
            bar.isEnabled = false
            return
        }
        bar.position = (start + end) * Float(Geometry.half)
        // The box is a metre deep and its depth is +z, so the bar is scaled to the
        // length and turned from +z onto the line. `simd_quatf(from:to:)` wants both
        // normalized and handles the opposite-directions case by picking an arbitrary
        // axis, which for a bar that is square in section changes nothing.
        bar.orientation = simd_quatf(from: Tracers.lengthAxis, to: along / length)
        var stretch = SIMD3<Float>.one
        stretch.z = length
        bar.scale = stretch
    }
}
