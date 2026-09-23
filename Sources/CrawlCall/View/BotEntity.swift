// The bots on screen. Stage 1 is grey primitives, so a bot is a box the height of a
// person, and the one thing it has to say at a glance is which side it is on
// (FR-VIEW-060).
//
// **Partial, and how.** The requirement asks for three channels that agree — body
// colour, the silhouette of the equipment, and the colour of the tracers. This is the
// first: there are no weapons modelled to give a silhouette and no shot drawn to give
// a tracer, and both arrive with the archetype silhouettes (FR-VIEW-070) and the
// firing effects. The colours chosen here are the ones those will have to match.
//
// implements: FR-VIEW-060
import CoreGraphics
import Foundation
import RealityKit
import UIKit

enum BotEntity {
    /// How tall a bot stands and how wide it is, in metres. Nothing specifies a bot's
    /// size; a person on a half-metre grid is this, and it is said out loud rather
    /// than passed off as a rule.
    static let height = 1.6
    static let width = 0.4

    @MainActor
    static func make(for bots: [Bot]) -> Entity {
        let root = Entity()
        root.name = "bots"
        for bot in bots {
            let mesh = MeshResource.generateBox(width: Float(width), height: Float(height),
                                                depth: Float(width), cornerRadius: 0.05)
            let model = ModelEntity(mesh: mesh, materials: [material(for: bot.squad)])
            model.name = "bot\(bot.id)"
            root.addChild(model)
        }
        update(root, from: bots)
        return root
    }

    /// Puts every bot where the model has it, standing on the floor rather than sunk
    /// into it.
    @MainActor
    static func update(_ entity: Entity, from bots: [Bot]) {
        for bot in bots {
            guard let model = entity.children.first(where: { $0.name == "bot\(bot.id)" }) else { continue }
            model.position = SIMD3(Float(bot.position.x),
                                   Float(bot.position.y + height / 2),
                                   Float(bot.position.z))
        }
    }

    /// One colour a side, told apart at a glance and from the snake's green and the
    /// kit's greys. Red, green and blue in 0…1, as the kit's legend gives colours, so
    /// that the two can be compared without asking a material what it holds.
    static func colour(for squad: Squad) -> SIMD3<Double> {
        squad == .red ? SIMD3(0.82, 0.30, 0.28) : SIMD3(0.26, 0.44, 0.80)
    }

    @MainActor
    static func material(for squad: Squad) -> PhysicallyBasedMaterial {
        let rgb = colour(for: squad)
        let colour = UIColor(red: CGFloat(rgb.x), green: CGFloat(rgb.y), blue: CGFloat(rgb.z), alpha: 1)
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: colour)
        material.roughness = 0.8
        material.metallic = 0.0
        return material
    }
}
