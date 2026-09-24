// The snake on screen: a head and one body for each segment, moved to where the model
// says they are. The model is in `Snake`; nothing here decides anything about motion.
//
// What the snake looks like is not specified anywhere yet — the concept describes the
// style (§2) and no requirement names a colour for the player's own body — so the two
// shades below are a stage-1 choice, said out loud rather than passed off as a rule.
//
// implements: FR-SNAKE-010, FR-SNAKE-020, FR-VIEW-180
import Foundation
import RealityKit
import UIKit

enum SnakeEntity {
    private static let headColour = UIColor(red: 0.30, green: 0.62, blue: 0.35, alpha: 1)
    private static let bodyColour = UIColor(red: 0.38, green: 0.70, blue: 0.42, alpha: 1)

    /// A head and as many bodies as the snake carries, all the same size.
    @MainActor
    static func make(radius: Double, segments: Int) -> Entity {
        let root = Entity()
        root.name = EntityName.snake
        root.addChild(body(radius: radius, colour: headColour, name: EntityName.head))
        for index in 0..<segments {
            root.addChild(body(radius: radius * 0.92, colour: bodyColour, name: EntityName.numbered(EntityName.segment, index)))
        }
        return root
    }

    /// Puts the head and every segment where the model has them. Segments the trail is
    /// too short to carry are tucked under the head rather than left where they were,
    /// which would read as a body the snake has shed.
    ///
    /// Bodies are made here as the tail needs them (FR-VIEW-180), not once at the
    /// start: a snake that has eaten is longer than the one the match began with, and
    /// a fixed set of bodies would stop at the starting length and say nothing about
    /// it. They are never destroyed — a tail that shortens will lengthen again, and a
    /// body off screen costs less than one built twice a second under fire.
    @MainActor
    static func update(_ entity: Entity, from snake: Snake, radius: Double) {
        guard let head = entity.children.first(where: { $0.name == EntityName.head }) else { return }
        head.position = SIMD3(Float(snake.head.x), Float(snake.head.y), Float(snake.head.z))
        let tail = snake.tail

        var bodies = entity.children.filter { $0.name.hasPrefix(EntityName.segment) }
        while bodies.count < tail.count {
            let made = body(radius: radius * 0.92, colour: bodyColour, name: EntityName.numbered(EntityName.segment, bodies.count))
            // Whatever lights the head lights the new body; a segment that missed the
            // scene's light would arrive in a different world from the rest of it.
            if let light = head.components[ImageBasedLightReceiverComponent.self] {
                made.components.set(light)
            }
            entity.addChild(made)
            bodies.append(made)
        }

        for (index, child) in bodies.enumerated() {
            let place = index < tail.count ? tail[index] : snake.head
            child.position = SIMD3(Float(place.x), Float(place.y), Float(place.z))
            child.isEnabled = index < tail.count
        }
    }

    @MainActor
    private static func body(radius: Double, colour: UIColor, name: String) -> ModelEntity {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: colour)
        material.roughness = 0.8
        material.metallic = 0.0
        let model = ModelEntity(mesh: .generateSphere(radius: Float(radius)), materials: [material])
        model.name = name
        return model
    }
}
