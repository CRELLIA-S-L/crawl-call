// The plan, in RealityKit. Everything that decides *where* a module goes is in
// `ScenePlan`, which a test can read; this file only turns metres into entities.
//
// How the result is lit and seen is not here but in `View/`: the map is what the
// arena is, the camera and the light are how it is looked at.
//
// Colour comes from the kit's legend, not from here: what a module looks like is a
// property of the kit a map is assembled from (FR-MAP-100).
//
// implements: FR-TOOL-020, FR-VIEW-140, FR-VIEW-150
import Foundation
import RealityKit

enum SceneBuilder {
    /// The whole scene: the map, the light it is read by, and the camera it is seen
    /// through, with every model told which ambient light to receive.
    ///
    /// What may be seen through comes out beside the scene because it changes while
    /// the match runs (FR-VIEW-140, FR-VIEW-150), and the thing that knows where the
    /// snake and the camera are is the match, not the builder.
    @MainActor
    static func scene(for plan: ScenePlan, pitchDegrees: Double) -> (root: Entity, seeThrough: SeeThrough) {
        let root = Entity()
        root.name = "scene"
        let ambient = SceneView.ambient(for: plan)
        let (map, seeThrough) = entity(for: plan)
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
        return (root, seeThrough)
    }

    /// One entity holding the whole map, so the caller can add or drop it in one move,
    /// and the same modules with what the see-through rules need to judge them.
    @MainActor
    static func entity(for plan: ScenePlan) -> (root: Entity, seeThrough: SeeThrough) {
        let root = Entity()
        root.name = "map"
        var modules: [SeeThrough.Module] = []
        // A map is hundreds of cells and a kit is a handful of module types, so both
        // looks are made once per type and shared. Making a material per piece was
        // the suite's largest cost: its test phase ran in 5.6 s with one look built
        // per piece and in 1.3 s with two looks built per type.
        var looks: [String: (solid: [any Material], clear: [any Material])] = [:]
        for piece in plan.pieces where piece.size.x > 0 && piece.size.y > 0 && piece.size.z > 0 {
            let mesh = MeshResource.generateBox(width: Float(piece.size.x),
                                                height: Float(piece.size.y),
                                                depth: Float(piece.size.z))
            // What a module looks like is the view's business, solid or see-through
            // alike; what colour it is comes from the kit's legend (FR-MAP-100).
            let look = looks[piece.module] ?? (solid: [SeeThrough.solid(colour: piece.colour)],
                                               clear: [SeeThrough.clear(colour: piece.colour)])
            looks[piece.module] = look
            let model = ModelEntity(mesh: mesh, materials: look.solid)
            model.name = piece.module
            model.position = SIMD3(Float(piece.centre.x), Float(piece.centre.y), Float(piece.centre.z))
            root.addChild(model)
            modules.append(SeeThrough.Module(model: model, level: piece.level,
                                             centre: piece.centre, size: piece.size,
                                             solid: look.solid, clear: look.clear))
        }
        return (root, SeeThrough(modules))
    }

}
