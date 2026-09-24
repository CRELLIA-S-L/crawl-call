// The bots on screen: one figure each, the one its archetype is drawn as (FR-VIEW-070),
// in its squad's colour (FR-VIEW-060), put where the model has it — and, while one is
// being eaten, a figure going into the snake rather than blinking out (FR-VIEW-100).
//
// The three channels of FR-VIEW-060 are all here and agree: the body and the headgear
// are in the squad's colour (`Figure`), and the tracers are drawn in the same colour
// from `material(for:)` (FR-VIEW-170).
//
// A figure's origin is at its feet, so that it stands on the floor as placed and
// shrinks into the floor as it is swallowed.
//
// implements: FR-VIEW-060, FR-VIEW-070, FR-VIEW-100, FR-VIEW-190
import CoreGraphics
import Foundation
import RealityKit
import UIKit

enum BotEntity {
    /// One figure for every bot, `height` metres tall — the bot configuration's
    /// figure height (IF-BOT-010, ADR-0022).
    @MainActor
    static func make(for bots: [Bot], height: Double) -> Entity {
        let root = Entity()
        root.name = EntityName.bots
        let paints: [Squad: [Figure.Paint: any Material]] = [
            .red: Figure.materials(for: .red), .blue: Figure.materials(for: .blue),
        ]
        for bot in bots {
            let figure = Figure.make(bot.archetype, height: height, materials: paints[bot.squad] ?? Figure.materials(for: bot.squad))
            figure.name = EntityName.numbered(EntityName.bot, bot.id)
            root.addChild(figure)
        }
        update(root, from: bots)
        return root
    }

    /// Lights every figure by the scene's ambient light. A figure is a group of parts,
    /// and it is the parts that are drawn, so it is the parts that carry the receiver,
    /// as every other lit model in the scene does. The first build of the figures set
    /// it on the groups instead, and the SDK's documentation (iOS 27.0) does not say
    /// that a receiver on an entity reaches its children.
    @MainActor
    static func light(_ entity: Entity, by ambient: Entity) {
        for figure in entity.children {
            for part in figure.children {
                part.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ambient))
            }
        }
    }

    /// Puts every bot where the model has it, standing on the floor rather than sunk
    /// into it — and takes off screen the ones the model no longer has.
    ///
    /// A bot leaves the match by being eaten, and a body that stayed standing where
    /// it was swallowed would say the opposite of what happened. This walks the
    /// bodies rather than the bots for that reason: what is gone is what has no bot
    /// left to answer for it.
    @MainActor
    static func update(_ entity: Entity, from bots: [Bot]) {
        var standing: [String: Bot] = [:]
        for bot in bots { standing[EntityName.numbered(EntityName.bot, bot.id)] = bot }
        for body in entity.children {
            guard let bot = standing[body.name] else {
                body.isEnabled = false
                continue
            }
            body.isEnabled = true
            // Everything a meal did to this body is undone here, and not only where
            // it stood: a bot swallowed in the last match came back in the next one
            // the size the last bite had left it (found in play on 2026-09-23,
            // FR-VIEW-190). What this does not set is what survives a new match, so
            // it sets all of it — the shrinking of FR-VIEW-100 is applied after,
            // every frame, by `swallow`.
            body.scale = .one
            body.position = SIMD3(Float(bot.position.x), Float(bot.position.y), Float(bot.position.z))
        }
    }

    /// Draws the bot being eaten on its way in: pulled towards the head and shrinking
    /// as what is left of it does (FR-VIEW-100).
    ///
    /// `left` is what remains of the prey, one at the first bite and zero at the
    /// last. It never reaches zero on screen — a body that vanished while still
    /// full-sized would read as a bug rather than a meal, which is what the previous
    /// build did.
    @MainActor
    static func swallow(_ entity: Entity, prey id: Int, head: SIMD3<Double>, left: Double) {
        guard let body = entity.children.first(where: { $0.name == EntityName.numbered(EntityName.bot, id) }) else { return }
        let gone = min(max(Fraction.whole - left, Fraction.none), Fraction.whole)
        let scale = Float(max(0.15, Fraction.whole - gone))
        body.scale = SIMD3(repeating: scale)
        // Towards the head, and down into it as it goes: the snake's mouth is at the
        // floor, and the figure stands on its feet there, shrinking towards them.
        let x = bot(body.position.x, towards: Float(head.x), by: Float(gone))
        let z = bot(body.position.z, towards: Float(head.z), by: Float(gone))
        body.position = SIMD3(x, Float(head.y), z)
    }

    private static func bot(_ from: Float, towards target: Float, by part: Float) -> Float {
        from + (target - from) * min(part, Float(Fraction.whole))
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
