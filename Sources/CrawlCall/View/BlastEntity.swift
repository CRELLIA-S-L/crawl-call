// The grenades on screen and the blasts they make (FR-VIEW-350, FR-VIEW-360). A thrown
// grenade is a small ball drawn where it is while its fuse burns; the blast it leaves is
// a ball growing from nothing to the blast radius over the moment it is drawn for.
//
// Two pools made once and moved, for the reason the tracers' pool exists (FR-VIEW-170):
// a thing that comes and goes several times a second would otherwise build and throw
// away a mesh as often.
//
// file implements: FR-VIEW-350, FR-VIEW-360
import CoreGraphics
import Foundation
import RealityKit
import UIKit

enum BlastEntity {
    /// A ball per grenade that can be in the air at once, and one per blast that can be
    /// on screen at once.
    @MainActor
    static func make(for bots: [Bot], configuration: BotConfiguration) -> Entity {
        let root = Entity()
        root.name = EntityName.blasts
        let ball = MeshResource.generateSphere(radius: Float(Blasts.grenadeRadius))
        let cloud = MeshResource.generateSphere(radius: Blasts.unitRadius)
        for index in Int.zero..<Blasts.grenades(for: bots, configuration: configuration) {
            let thrown = ModelEntity(mesh: ball, materials: [material(Blasts.grenadeColour, opacity: 1)])
            thrown.name = EntityName.numbered(EntityName.grenade, index)
            thrown.isEnabled = false
            root.addChild(thrown)
        }
        for index in Int.zero..<Blasts.flashes {
            let flash = ModelEntity(mesh: cloud,
                                    materials: [material(Blasts.flashColour, opacity: Blasts.flashOpacity)])
            flash.name = EntityName.numbered(EntityName.flash, index)
            flash.isEnabled = false
            root.addChild(flash)
        }
        return root
    }

    /// Every grenade in the air drawn where it is, every blast drawn where it went off at
    /// the size it has grown to, and the rest of both pools off screen.
    @MainActor
    static func update(_ entity: Entity, grenades: [Thrown], blasts: [Flash]) {
        var thrown = entity.children.filter { $0.name.hasPrefix(EntityName.grenade) }
        var flashes = entity.children.filter { $0.name.hasPrefix(EntityName.flash) }
        for ball in thrown + flashes { ball.isEnabled = false }
        for grenade in grenades {
            guard let ball = thrown.popLast() else { continue }
            ball.isEnabled = true
            ball.scale = .one
            ball.position = SIMD3(Float(grenade.position.x), Float(grenade.position.y), Float(grenade.position.z))
        }
        for blast in blasts {
            guard let cloud = flashes.popLast() else { continue }
            cloud.isEnabled = true
            cloud.position = SIMD3(Float(blast.position.x), Float(blast.position.y), Float(blast.position.z))
            // From nothing at the moment it went off to the whole blast radius at the end
            // of the moment it is drawn for (FR-VIEW-360).
            cloud.scale = .one * Float(max(Blasts.smallest, blast.radius * blast.grown))
        }
    }

    @MainActor
    static func material(_ rgb: SIMD3<Double>, opacity: Double) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(red: CGFloat(rgb.x), green: CGFloat(rgb.y),
                                                 blue: CGFloat(rgb.z), alpha: CGFloat(opacity)))
        material.roughness = 0.8
        material.metallic = 0.0
        if opacity < Fraction.whole { material.blending = .transparent(opacity: .init(floatLiteral: Float(opacity))) }
        return material
    }
}
