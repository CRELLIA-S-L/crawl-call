// The plan, in RealityKit. Everything that decides *where* a module goes is in
// `ScenePlan`, which a test can read; this file only turns metres into entities.
//
// How the result is lit and seen is not here but in `View/`: the map is what the
// arena is, the camera and the light are how it is looked at.
//
// Colour comes from the kit's legend, not from here: what a module looks like is a
// property of the kit a map is assembled from (FR-MAP-100).
//
// implements: FR-TOOL-020, FR-VIEW-140, FR-VIEW-150, FR-VIEW-155, FR-MAP-210
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
    static func scene(for plan: ScenePlan, view: ViewConfiguration) -> (root: Entity, seeThrough: SeeThrough) {
        let root = Entity()
        root.name = EntityName.scene
        let ambient = SceneView.ambient(for: plan, view: view)
        let (map, seeThrough) = entity(for: plan)
        // A directional light leaves what it cannot reach unlit, and unlit is black on
        // screen — which FR-VIEW-130 forbids. The ambient light is what fills those in,
        // and it only reaches models that say they receive it.
        // A tree's trunk hangs under its crown, so the light goes to every model the
        // map holds, not only its top level.
        for model in map.children {
            model.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ambient))
            for part in model.children {
                part.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ambient))
            }
        }
        root.addChild(ambient)
        root.addChild(map)
        root.addChild(SceneView.light(for: plan, view: view))
        root.addChild(SceneView.camera(for: plan, view: view))
        return (root, seeThrough)
    }

    /// One entity holding the whole map, so the caller can add or drop it in one move,
    /// and the same modules with what the see-through rules need to judge them.
    @MainActor
    static func entity(for plan: ScenePlan) -> (root: Entity, seeThrough: SeeThrough) {
        let root = Entity()
        root.name = EntityName.map
        var modules: [SeeThrough.Module] = []
        // A map is hundreds of cells and a kit is a handful of module types, so both
        // looks are made once per type and shared. Making a material per piece was
        // the suite's largest cost: its test phase ran in 5.6 s with one look built
        // per piece and in 1.3 s with two looks built per type.
        var looks: [String: (solid: [any Material], clear: [any Material], holed: [any Material]?)] = [:]
        for piece in plan.pieces where piece.size.min() > .zero {
            let figure = Self.figure(for: piece)
            // What a module looks like is the view's business, solid or see-through
            // alike; what colour it is comes from the kit's legend (FR-MAP-100).
            let look = looks[piece.module] ?? {
                let solid = SeeThrough.solid(colour: piece.colour)
                // The third look, cut open around a point (ADR-0020); nil where the
                // shader did not load, and the module then fades whole as before.
                return (solid: [solid], clear: [SeeThrough.clear(colour: piece.colour)],
                        holed: SeeThrough.holed(from: solid).map { [$0] })
            }()
            looks[piece.module] = look
            let model = ModelEntity(mesh: figure.mesh, materials: look.solid)
            model.name = piece.module
            model.scale = figure.scale
            model.position = figure.position
            if let trunk = figure.trunk {
                let material = SeeThrough.solid(colour: plan.trunkColour)
                let part = ModelEntity(mesh: trunk.mesh, materials: [material])
                // The crown is scaled; the trunk is placed in the crown's own space.
                part.scale = trunk.scale / figure.scale
                part.position = trunk.offset / figure.scale
                model.addChild(part)
            }
            root.addChild(model)
            modules.append(SeeThrough.Module(model: model, level: piece.level,
                                             centre: piece.centre, size: piece.size,
                                             solid: look.solid, clear: look.clear,
                                             holed: look.holed))
        }
        return (root, SeeThrough(modules))
    }

    /// What a piece is drawn as: its box, or the figure its module names fitted into
    /// that box (FR-MAP-210, ADR-0034) — for a tree the crown, which the see-through
    /// cuts, with its trunk under it.
    @MainActor
    static func figure(for piece: ScenePlan.Piece)
        -> (mesh: MeshResource, scale: SIMD3<Float>, position: SIMD3<Float>,
            trunk: (mesh: MeshResource, scale: SIMD3<Float>, offset: SIMD3<Float>)?) {
        let size = SIMD3<Float>(piece.size)
        let centre = SIMD3<Float>(piece.centre)
        switch piece.figure {
        case .box:
            return (.generateBox(width: size.x, height: size.y, depth: size.z), SIMD3(repeating: ModuleFigures.unit),
                    centre, nil)
        case .shrub:
            let wide = Float(ModuleFigures.shrubWidthShare)
            return (.generateSphere(radius: ModuleFigures.unitRadius), SIMD3(size.x * wide, size.y, size.z * wide),
                    centre, nil)
        case .tree:
            let bottom = centre.y - size.y * Float(Geometry.half)
            let trunkHeight = size.y * Float(ModuleFigures.trunkShare)
            let crownHeight = size.y - trunkHeight
            let crownWidth = size.x * Float(ModuleFigures.crownWidthShare)
            let crownCentre = SIMD3(centre.x, bottom + trunkHeight + crownHeight * Float(Geometry.half), centre.z)
            let trunkWidth = size.x * Float(ModuleFigures.trunkWidthShare)
            let trunkCentre = SIMD3(centre.x, bottom + trunkHeight * Float(Geometry.half), centre.z)
            return (.generateCone(height: ModuleFigures.unit, radius: ModuleFigures.unitRadius),
                    SIMD3(crownWidth, crownHeight, crownWidth), crownCentre,
                    (.generateCylinder(height: ModuleFigures.unit, radius: ModuleFigures.unitRadius),
                     SIMD3(trunkWidth, trunkHeight, trunkWidth), trunkCentre - crownCentre))
        }
    }

}
