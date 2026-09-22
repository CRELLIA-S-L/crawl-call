// The plan, in RealityKit. Everything that decides *where* a module goes is in
// `ScenePlan`, which a test can read; this file only turns metres into entities.
//
// How the result is lit and seen is not here but in `View/`: the map is what the
// arena is, the camera and the light are how it is looked at.
//
// Colour comes from the kit's legend, not from here: what a module looks like is a
// property of the kit a map is assembled from (FR-MAP-100).
//
// implements: FR-TOOL-020
import CoreGraphics
import Foundation
import RealityKit
import UIKit

enum SceneBuilder {
    /// The whole scene: the map, the light it is read by, and the camera it is seen
    /// through, with every model told which ambient light to receive.
    @MainActor
    static func scene(for plan: ScenePlan, pitchDegrees: Double) -> Entity {
        let root = Entity()
        root.name = "scene"
        let ambient = SceneView.ambient(for: plan)
        let map = entity(for: plan)
        // A directional light leaves what it cannot reach unlit, and unlit is black on
        // screen — which FR-VIEW-130 forbids. The ambient light is what fills those in,
        // and it only reaches models that say they receive it.
        for model in map.children {
            model.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ambient))
        }
        root.addChild(ambient)
        root.addChild(map)
        root.addChild(SceneView.light(for: plan))
        root.addChild(SceneView.camera(for: plan, pitchDegrees: pitchDegrees))
        return root
    }

    /// One entity holding the whole map, so the caller can add or drop it in one move.
    @MainActor
    static func entity(for plan: ScenePlan) -> Entity {
        let root = Entity()
        root.name = "map"
        for piece in plan.pieces where piece.size.x > 0 && piece.size.y > 0 && piece.size.z > 0 {
            let mesh = MeshResource.generateBox(width: Float(piece.size.x),
                                                height: Float(piece.size.y),
                                                depth: Float(piece.size.z))
            var material = PhysicallyBasedMaterial()
            // `tint:` with a platform colour is the only initialiser the SDK exposes;
            // the value it keeps is a CGColor, but `color:` belongs to another struct.
            // This is the one line in the map layer that macOS will need its own of.
            material.baseColor = .init(tint: UIColor(red: CGFloat(piece.colour.x),
                                                     green: CGFloat(piece.colour.y),
                                                     blue: CGFloat(piece.colour.z),
                                                     alpha: 1))
            material.roughness = 0.85
            material.metallic = 0.0
            let model = ModelEntity(mesh: mesh, materials: [material])
            model.name = piece.module
            model.position = SIMD3(Float(piece.centre.x), Float(piece.centre.y), Float(piece.centre.z))
            root.addChild(model)
        }
        return root
    }

}
