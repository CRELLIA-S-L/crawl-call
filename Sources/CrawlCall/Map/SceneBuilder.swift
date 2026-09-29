// The plan, in RealityKit. Everything that decides *where* a module goes is in
// `ScenePlan`, which a test can read; this file only turns metres into entities.
//
// How the result is lit and seen is not here but in `View/`: the map is what the
// arena is, the camera and the light are how it is looked at.
//
// Colour comes from the kit's legend, not from here: what a module looks like is a
// property of the kit a map is assembled from (FR-MAP-100).
//
// implements: FR-TOOL-020, FR-VIEW-140, FR-VIEW-150, FR-VIEW-155, FR-MAP-210, FR-VIEW-240
import Foundation
import RealityKit
import struct SwiftUI.Path

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
        // So are the rounded boxes: a map's modules come in a handful of sizes (FR-VIEW-240).
        var boxes: [SIMD3<Float>: MeshResource] = [:]
        // The ground slabs go into one mesh per module rather than an entity each: the
        // renderer draws every entity several times a frame, and six hundred slabs that
        // never change were most of the frame's draws (ADR-0047).
        let slabs = Set(plan.groundSlabs)
        var merged: [String: (colour: SIMD3<Double>, parts: [(mesh: MeshResource, at: SIMD3<Float>)])] = [:]
        for (index, piece) in plan.pieces.enumerated() where piece.size.min() > .zero {
            let figure = Self.figure(for: piece, boxes: &boxes)
            if slabs.contains(index) {
                merged[piece.module, default: (piece.colour, [])].parts.append((figure.mesh, figure.position))
                continue
            }
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
        for module in merged.keys.sorted() {
            guard let group = merged[module] else { continue }
            guard let mesh = try? joined(group.parts) else {
                preconditionFailure(String(describing: SceneBuilderError.slabsNotJoined))
            }
            let model = ModelEntity(mesh: mesh, materials: [SeeThrough.solid(colour: group.colour)])
            model.name = EntityName.slabs(module)
            root.addChild(model)
        }
        return (root, SeeThrough(modules))
    }

    /// Many meshes as one: each part's triangles moved to where it stands.
    @MainActor
    static func joined(_ parts: [(mesh: MeshResource, at: SIMD3<Float>)]) throws -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for part in parts {
            for model in part.mesh.contents.models {
                for piece in model.parts {
                    let base = UInt32(positions.count)
                    positions += piece.positions.elements.map { $0 + part.at }
                    normals += piece.normals?.elements ?? []
                    indices += (piece.triangleIndices?.elements ?? []).map { $0 + base }
                }
            }
        }
        var descriptor = MeshDescriptor(name: EntityName.map)
        descriptor.positions = MeshBuffers.Positions(positions)
        if normals.count == positions.count { descriptor.normals = MeshBuffers.Normals(normals) }
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }

    /// What a piece is drawn as: its box, or the figure its module names fitted into
    /// that box (FR-MAP-210, ADR-0034) — for a tree the crown, which the see-through
    /// cuts, with its trunk under it.
    @MainActor
    static func figure(for piece: ScenePlan.Piece, boxes: inout [SIMD3<Float>: MeshResource])
        -> (mesh: MeshResource, scale: SIMD3<Float>, position: SIMD3<Float>,
            trunk: (mesh: MeshResource, scale: SIMD3<Float>, offset: SIMD3<Float>)?) {
        let size = SIMD3<Float>(piece.size)
        let centre = SIMD3<Float>(piece.centre)
        switch piece.figure {
        case .box:
            let box = boxes[size] ?? .roundedBox(size)
            boxes[size] = box
            return (box, SIMD3(repeating: ModuleFigures.unit),
                    centre, nil)
        case .shrub:
            let wide = Float(ModuleFigures.shrubWidthShare)
            // Of the game's own sphere: RealityKit's is 8064 triangles at any size (ADR-0046).
            let sphere = LowPolySphere.mesh(radius: ModuleFigures.unitRadius, rings: LowPoly.shrubRings,
                                            segments: LowPoly.shrubSegments)
                ?? .generateSphere(radius: ModuleFigures.unitRadius)
            return (sphere, SIMD3(size.x * wide, size.y, size.z * wide),
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

extension MeshResource {
    /// A box of this size with its edges rounded (FR-VIEW-240, ADR-0037). Made at its own size, not
    /// scaled to it, since a scale that is not the same on every axis would stretch
    /// the rounding.
    ///
    /// A rounded rectangle across x and y, extruded along z with rounded rims: the
    /// rims add the radius at each end, so the extrusion is shorter by two of them.
    /// Where RealityKit cannot extrude it, the box is drawn with square edges.
    ///
    /// A caller that draws its own rounding — a bot's figure (FR-VIEW-070) — gives the
    /// radius and how many segments round each edge; the map's modules take the
    /// shared ones (FR-VIEW-240).
    @MainActor
    static func roundedBox(_ size: SIMD3<Float>, corner asked: Float? = nil,
                           segments: Int = Rounding.segments) -> MeshResource {
        let corner = asked.map { min($0, size.min() * LowPoly.figureCornerShare) }
            ?? min(Rounding.radius, size.min() * Rounding.smallestSideShare)
        let rect = CGRect(x: -CGFloat(size.x) / 2, y: -CGFloat(size.y) / 2,
                          width: CGFloat(size.x), height: CGFloat(size.y))
        var options = MeshResource.ShapeExtrusionOptions()
        options.extrusionMethod = .linear(depth: size.z - 2 * corner)
        options.chamferRadius = corner
        options.boundaryResolution = .uniformSegmentsPerSpan(segmentCount: segments)
        options.chamferResolution = .uniformSegmentsPerSpan(segmentCount: segments)
        let outline = Path(roundedRect: rect, cornerRadius: CGFloat(corner), style: .circular)
        guard let mesh = try? MeshResource(extruding: outline, extrusionOptions: options) else {
            return .generateBox(size: size)
        }
        return mesh
    }
}

/// What building the map's entities can fail at.
enum SceneBuilderError: IdentifiedError {
    case slabsNotJoined

    var identifier: ErrorIdentifier {
        switch self {
        case .slabsNotJoined: return .sceneSlabsNotJoined
        }
    }

    var details: String {
        switch self {
        case .slabsNotJoined: return "the ground slabs could not be joined into one mesh"
        }
    }
}
