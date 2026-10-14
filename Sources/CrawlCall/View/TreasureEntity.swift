// The treasure on screen (FR-VIEW-370): one box, drawn where the treasure is — on the
// ground where it lies, or in the hands of the bot carrying it.
//
// One entity made once and moved, as the grenades are (FR-VIEW-350): there is one
// treasure in a match, it never stops existing, and it only ever changes where it is.
// It is hidden in the frames where there is nowhere to draw it — a map that names none,
// and the end of a match it was carried off in.
//
// Old gold and nothing else in the arena is, because the player has to pick it out
// across the room, and the one thing worth eating out of a squad is whoever holds it.
//
// file implements: FR-VIEW-370, FR-VIEW-240
import Foundation
import RealityKit
import UIKit

enum TreasureEntity {
    /// The box, made once.
    @MainActor
    static func make() -> Entity {
        let box = ModelEntity(mesh: .roundedBox(Prize.size), materials: [material()])
        box.name = EntityName.treasure
        box.isEnabled = false
        return box
    }

    /// Where it is this frame: on the ground where it lies, half its height above the
    /// floor, or at the hands of its carrier, a little ahead of the chest so that the
    /// figure does not swallow it (FR-VIEW-370). Hidden where there is nothing to draw.
    @MainActor
    static func update(_ entity: Entity, treasure: Treasure?, bots: [Bot]) {
        guard let place = place(of: treasure, among: bots) else {
            entity.isEnabled = false
            return
        }
        entity.isEnabled = true
        entity.position = SIMD3(Float(place.x), Float(place.y), Float(place.z))
    }

    /// Where the treasure is drawn, or nil where it is nowhere to be drawn: no treasure
    /// on the map, it has been carried off, or its carrier is no longer among the bots.
    static func place(of treasure: Treasure?, among bots: [Bot]) -> SIMD3<Double>? {
        guard let treasure else { return nil }
        switch treasure.place {
        case .lying(let point, _):
            return SIMD3(point.x, point.y + Prize.lift, point.z)
        case .carried(let id):
            guard let holder = bots.first(where: { $0.id == id }) else { return nil }
            let ahead = SIMD3(sin(holder.facing), .zero, cos(holder.facing)) * Prize.heldAhead
            return SIMD3(holder.position.x + ahead.x,
                         holder.position.y + Prize.heldAt,
                         holder.position.z + ahead.z)
        case .carriedOff:
            return nil
        }
    }

    @MainActor
    static func material() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(red: CGFloat(Prize.colour.x), green: CGFloat(Prize.colour.y),
                                                 blue: CGFloat(Prize.colour.z), alpha: 1))
        material.roughness = .init(floatLiteral: Prize.roughness)
        material.metallic = .init(floatLiteral: Prize.metallic)
        return material
    }
}
