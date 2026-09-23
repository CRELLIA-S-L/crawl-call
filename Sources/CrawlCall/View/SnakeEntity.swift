// The snake on screen: a head and one body for each segment, moved to where the model
// says they are. The model is in `Snake`; nothing here decides anything about motion.
//
// What the snake looks like is not specified anywhere yet — the concept describes the
// style (§2) and no requirement names a colour for the player's own body — so the two
// shades below are a stage-1 choice, said out loud rather than passed off as a rule.
//
// implements: FR-SNAKE-010, FR-SNAKE-020
import Foundation
import RealityKit
import UIKit

enum SnakeEntity {
    /// A head and as many bodies as the snake carries, all the same size.
    @MainActor
    static func make(radius: Double, segments: Int) -> Entity {
        let root = Entity()
        root.name = "snake"
        root.addChild(body(radius: radius, colour: UIColor(red: 0.30, green: 0.62, blue: 0.35, alpha: 1), name: "head"))
        for index in 0..<segments {
            root.addChild(body(radius: radius * 0.92,
                               colour: UIColor(red: 0.38, green: 0.70, blue: 0.42, alpha: 1),
                               name: "segment\(index)"))
        }
        return root
    }

    /// Puts the head and every segment where the model has them. Segments the trail is
    /// too short to carry are tucked under the head rather than left where they were,
    /// which would read as a body the snake has shed.
    @MainActor
    static func update(_ entity: Entity, from snake: Snake) {
        guard let head = entity.children.first(where: { $0.name == "head" }) else { return }
        head.position = SIMD3(Float(snake.head.x), Float(snake.head.y), Float(snake.head.z))
        let tail = snake.tail
        for (index, child) in entity.children.enumerated() where child.name.hasPrefix("segment") {
            let segment = index - 1                     // the head is the first child
            let place = segment < tail.count ? tail[segment] : snake.head
            child.position = SIMD3(Float(place.x), Float(place.y), Float(place.z))
            child.isEnabled = segment < tail.count
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
