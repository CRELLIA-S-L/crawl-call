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
// implements: FR-VIEW-290, FR-VIEW-060, FR-VIEW-070, FR-VIEW-100, FR-VIEW-190, FR-BOT-280, FR-VIEW-300, FR-VIEW-320
import CoreGraphics
import Foundation
import Metal
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
        // Down the whole figure: the legs hang from hips (FR-VIEW-290), a level below
        // the rest of its parts.
        func lit(_ part: Entity) {
            part.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ambient))
            for child in part.children { lit(child) }
        }
        for figure in entity.children {
            for part in figure.children { lit(part) }
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
    static func update(_ entity: Entity, from bots: [Bot], gaits: [Int: Gait] = [:], eaten: Int? = nil) {
        var standing: [String: Bot] = [:]
        for bot in bots { standing[EntityName.numbered(EntityName.bot, bot.id)] = bot }
        for body in entity.children {
            guard let bot = standing[body.name] else {
                body.isEnabled = false
                continue
            }
            body.isEnabled = true
            // A figure cut by a meal it is no longer the prey of is drawn whole again
            // (FR-VIEW-320) — in a new match above all.
            if bot.id != eaten { uncut(body) }
            // Everything a meal did to this body is undone here, and not only where
            // it stood: a bot swallowed in the last match came back in the next one
            // the size the last bite had left it (found in play on 2026-09-23,
            // FR-VIEW-190). What this does not set is what survives a new match, so
            // it sets all of it — the shrinking of FR-VIEW-100 is applied after,
            // every frame, by `swallow`.
            body.scale = .one
            body.position = SIMD3(Float(bot.position.x), Float(bot.position.y), Float(bot.position.z))
            // Facing where the model has it face (FR-BOT-280): the figure's front is +z.
            // Stepping as it walks (FR-VIEW-290): lifted at each step, rocking side to
            // side, leaning into the walk, the legs swinging from the hips.
            let pose = (gaits[bot.id] ?? Gait()).pose
            body.position.y += Float(pose.lift)
            body.orientation = simd_quatf(angle: Float(bot.facing), axis: SIMD3(0, 1, 0))
                * simd_quatf(angle: Float(pose.lean), axis: SIMD3(1, 0, 0))
                * simd_quatf(angle: Float(pose.rock), axis: SIMD3(0, 0, 1))
            for (name, sign) in [(EntityName.leftHip, Float(1)), (EntityName.rightHip, Float(-1))] {
                body.children.first { $0.name == name }?.orientation =
                    simd_quatf(angle: -sign * Float(pose.swing), axis: SIMD3(1, 0, 0))
            }
            // A body lies where it fell, on its back, its feet where it stood
            // (FR-VIEW-300).
            if !bot.isAlive {
                body.position.y = Float(bot.position.y) + Float(BotBody.lyingLift)
                body.orientation = simd_quatf(angle: Float(bot.facing), axis: SIMD3(0, 1, 0))
                    * simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))
            }
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

    /// Draws a living bot being swallowed from the top down (FR-VIEW-320): where it
    /// stands and as big as it is, with what is above the mouth of the head coming down
    /// over it cut away — inside the head — so that its boots are the last of it to show.
    /// `left` is what remains of it, as for `swallow`.
    @MainActor
    static func slurp(_ entity: Entity, prey id: Int, feet: SIMD3<Double>, height: Double, left: Double) {
        guard let body = entity.children.first(where: { $0.name == EntityName.numbered(EntityName.bot, id) }) else { return }
        let pose = SwallowPose.prey(at: feet, height: height, gone: Fraction.whole - left)
        body.scale = .one
        body.position = SIMD3<Float>(pose.position)
        let cut = Float(pose.position.y + height * pose.height)
        for model in models(in: body) {
            guard var materials = model.model?.materials else { continue }
            if !model.components.has(UncutMaterials.self) {
                model.components.set(UncutMaterials(materials: materials))
                materials = materials.map { cutting($0) ?? $0 }
            }
            model.model?.materials = materials.map { material in
                guard var cutting = material as? CustomMaterial else { return material }
                cutting.custom.value = SIMD4(cut, .zero, .zero, .zero)
                return cutting
            }
        }
    }

    /// The materials a part of a figure was drawn with before a meal cut it
    /// (FR-VIEW-320), kept to be put back.
    struct UncutMaterials: Component {
        let materials: [any Material]
    }

    /// A figure drawn whole again, with the materials it had before it was cut.
    @MainActor
    static func uncut(_ body: Entity) {
        for model in models(in: body) {
            guard let kept = model.components[UncutMaterials.self] else { continue }
            model.model?.materials = kept.materials
            model.components.remove(UncutMaterials.self)
        }
    }

    /// Every part of a figure that is drawn, down to the legs hung from the hips.
    @MainActor
    private static func models(in entity: Entity) -> [ModelEntity] {
        entity.children.flatMap { child -> [ModelEntity] in
            ((child as? ModelEntity).map { [$0] } ?? []) + models(in: child)
        }
    }

    /// A material drawn as `material` below the cut and not at all above it: the cut's
    /// shader, and an opacity threshold that throws out what the shader clears
    /// (RealityKitSurfaceShader.h, iOS 27.0 SDK). Nil where Metal or the function is not
    /// there, and the figure is then drawn whole.
    @MainActor
    private static func cutting(_ material: any Material) -> CustomMaterial? {
        guard let library = cutLibrary else { return nil }
        let shader = CustomMaterial.SurfaceShader(named: Resource.botCutShader, in: library)
        guard var cut = try? CustomMaterial(from: material, surfaceShader: shader) else { return nil }
        cut.opacityThreshold = Float(Swallowing.cutThreshold)
        return cut
    }
    private static let cutLibrary: (any MTLLibrary)? = MTLCreateSystemDefaultDevice()?.makeDefaultLibrary()

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
