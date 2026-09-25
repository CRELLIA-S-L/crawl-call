// Scenery, in RealityKit. Everything that decides where a part goes is in the setting's
// layout, which a test can read; this turns parts into entities, paints the sky and
// moves the birds. Nothing built here joins the map's entity or `SeeThrough`: scenery
// is for the eye only (FR-MAP-130).
//
// implements: FR-GREENHOLM-010, FR-GREENHOLM-020, FR-GREENHOLM-030, FR-MAP-130, FR-TOOL-200, FR-MAP-200, FR-VIEW-240, FR-GREENHOLM-060, FR-GREENHOLM-070, FR-MAP-270, FR-MAP-280
import CoreGraphics
import Foundation
import Metal
import RealityKit
import UIKit

enum SceneryBuilder {
    /// What the match view needs of a setting once its scenery is in the scene: the sky
    /// to draw behind it, and the flock to move with the birds' schedule.
    struct Built {
        let sky: EnvironmentResource?
        let flock: Entity?
        let birds: Birds?
    }

    /// Lays out the world's setting for a camera that can take any frame up to the
    /// widest, and adds its scenery to the scene beside the map. A failure here is not
    /// something the system does at run time for a setting the launch has read — the
    /// launch has already refused a camera that sees the horizon — and would leave the
    /// scene wrong in a way nothing could hide, so it stops the app with its line.
    @MainActor
    static func world(for world: World, widestAspect: Double, in scene: Entity) -> Built {
        let camera = CameraRange(view: world.configurations.view, plan: world.plan, widestAspect: widestAspect)
        guard let ambient = scene.children.first(where: { $0.name == EntityName.ambient }) else {
            preconditionFailure(String(describing: SceneryError.noAmbientLight))
        }
        do {
            let scenery = try world.setting.scenery(around: world.plan, camera: camera)
            let root = entity(for: scenery, ambient: ambient)
            scene.addChild(root)
            return Built(sky: try scenery.sky.map(skyResource),
                         flock: root.children.first { $0.name == EntityName.birds },
                         birds: scenery.birds)
        } catch {
            preconditionFailure(String(describing: error))
        }
    }

    /// One entity holding every part and the birds, each lit by the scene's ambient
    /// light like the arena (FR-VIEW-130). A primitive's mesh is made once, at unit
    /// size, and a colour's material once, and both are shared by every part.
    @MainActor
    static func entity(for scenery: Scenery, ambient: Entity) -> Entity {
        let root = Entity()
        root.name = EntityName.scenery
        var meshes: [Scenery.Part.Shape: MeshResource] = [:]
        var materials: [SIMD3<Double>: PhysicallyBasedMaterial] = [:]
        // Water is glossy where everything else is matt (FR-GREENHOLM-060), so its
        // materials are kept apart even where a colour is the same.
        var waters: [SIMD3<Double>: any Material] = [:]
        var floors: [SIMD3<Double>: any Material] = [:]
        func material(_ layer: Scenery.Part.Layer, _ colour: SIMD3<Double>) -> any Material {
            switch layer {
            case .ground:
                let made = materials[colour] ?? matt(colour)
                materials[colour] = made
                return made
            case .water:
                let made = waters[colour] ?? water(colour, scenery: scenery)
                waters[colour] = made
                return made
            case .floor:
                let made = floors[colour] ?? floor(colour, scenery: scenery)
                floors[colour] = made
                return made
            }
        }
        for part in scenery.parts where part.size.min() > .zero {
            let model: ModelEntity
            switch part.layer {
            case .ground:
                let mesh = meshes[part.shape] ?? unitMesh(part.shape)
                meshes[part.shape] = mesh
                model = ModelEntity(mesh: mesh, materials: [material(part.layer, part.colour)])
                model.scale = SIMD3(Float(part.size.x), Float(part.size.y), Float(part.size.z))
                model.position = SIMD3(Float(part.centre.x), Float(part.centre.y), Float(part.centre.z))
            case .water, .floor:
                // By its top alone: the water can be seen through (FR-MAP-280), and a
                // slab's sides would show through it where two slabs meet. The floor
                // beyond the grid is at its full depth.
                let share = part.layer == .floor ? Fraction.whole : Fraction.none
                let top = Outline.level(GroundRect(lowest: SIMD2(part.lowest.x, part.lowest.z),
                                                   highest: SIMD2(part.highest.x, part.highest.z)),
                                        height: part.top, share: share)
                guard let mesh = try? meshResource(top) else {
                    preconditionFailure(String(describing: SceneryError.surfaceNotBuilt))
                }
                model = ModelEntity(mesh: mesh, materials: [material(part.layer, part.colour)])
            }
            model.name = EntityName.sceneryPart
            model.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ambient))
            root.addChild(model)
        }
        for surface in scenery.surfaces where !surface.mesh.isEmpty {
            guard let mesh = try? meshResource(surface.mesh) else {
                preconditionFailure(String(describing: SceneryError.surfaceNotBuilt))
            }
            // Walls and water are seen from either side as the camera goes round them.
            let material = seenFromEitherSide(material(surface.layer, surface.colour))
            let model = ModelEntity(mesh: mesh, materials: [material])
            model.name = EntityName.sceneryPart
            model.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ambient))
            root.addChild(model)
        }
        if let birds = scenery.birds {
            root.addChild(flock(birds, ambient: ambient))
        }
        return root
    }

    /// A surface's triangles as RealityKit takes them.
    @MainActor
    static func meshResource(_ mesh: Mesh) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: EntityName.sceneryPart)
        descriptor.positions = MeshBuffers.Positions(mesh.positions.map { SIMD3<Float>($0) })
        descriptor.normals = MeshBuffers.Normals(mesh.normals.map { SIMD3<Float>($0) })
        // A tangent frame at every vertex, so that a surface shader can tilt the
        // normal — the water's waves do (FR-GREENHOLM-070, ADR-0038).
        let frames = mesh.normals.map(tangentFrame)
        descriptor.tangents = MeshBuffers.Tangents(frames.map(\.tangent))
        descriptor.bitangents = MeshBuffers.Tangents(frames.map(\.bitangent))
        // How far down the floor's slope, for the floor shader to colour it by
        // (FR-MAP-270); nothing else carries it.
        if !mesh.shares.isEmpty, mesh.shares.count == mesh.positions.count {
            descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(
                mesh.shares.map { SIMD2(Float($0), Float(Fraction.none)) })
        }
        descriptor.primitives = .triangles(mesh.indices)
        return try MeshResource.generate(from: [descriptor])
    }

    /// Two directions along a surface with this normal, at right angles to it and to
    /// each other: x flattened onto the surface, or z where the surface faces along x.
    static func tangentFrame(_ normal: SIMD3<Double>) -> (tangent: SIMD3<Float>, bitangent: SIMD3<Float>) {
        let n = simd_normalize(normal)
        let across = abs(n.x) < TangentFrame.facingAlong ? SIMD3<Double>(1, 0, 0) : SIMD3<Double>(0, 0, 1)
        let tangent = simd_normalize(across - n * simd_dot(across, n))
        return (SIMD3<Float>(tangent), SIMD3<Float>(simd_cross(n, tangent)))
    }

    /// A mesh of the shape at unit size: one metre across and one high. Not rounded
    /// (FR-VIEW-240): the parts are slabs of water laid edge to edge, and a rounded
    /// edge shows as a seam where two meet.
    @MainActor
    static func unitMesh(_ shape: Scenery.Part.Shape) -> MeshResource {
        switch shape {
        case .box: return .generateBox(size: SceneryShape.unit)
        }
    }

    /// Water: glossy (FR-GREENHOLM-060), partly transparent (FR-MAP-280), with waves
    /// moving across it through the water shader (FR-GREENHOLM-070, ADR-0038); glossy
    /// and still where Metal or the function is not there.
    static func water(_ colour: SIMD3<Double>, scenery: Scenery) -> any Material {
        var glossy = matt(colour, roughness: scenery.waterRoughness)
        glossy.specular = .init(floatLiteral: Float(scenery.waterSpecular))
        glossy.blending = .transparent(opacity: .init(floatLiteral: Float(scenery.waterOpacity)))
        guard let library = shaderLibrary else { return glossy }
        let shader = CustomMaterial.SurfaceShader(named: Resource.waterShader, in: library)
        guard var rippled = try? CustomMaterial(from: glossy, surfaceShader: shader) else { return glossy }
        rippled.custom.value = SIMD4(Float(scenery.ripple.wavelength), Float(scenery.ripple.speedShare),
                                     Float(scenery.ripple.strength), Float(scenery.ripple.slope))
        // Transparent, at the water's opacity (FR-MAP-280). A custom material drops the
        // opacity its blending is given and reads back whole, so the shader sets the
        // opacity itself, from the clearcoat's roughness: the water has no clearcoat,
        // and that value reaches the shader as it was set (ADR-0039).
        rippled.blending = .transparent(opacity: .init(floatLiteral: Float(Fraction.whole)))
        rippled.clearcoat = .init(floatLiteral: Float(Fraction.none))
        rippled.clearcoatRoughness = .init(floatLiteral: Float(scenery.waterOpacity))
        return rippled
    }

    /// The floor under the water (FR-MAP-270): matt, from `colour` at its edge towards
    /// the scenery's floor colour at depth, by how far down its slope each point lies;
    /// the colour at its edge alone where Metal or the function is not there.
    static func floor(_ colour: SIMD3<Double>, scenery: Scenery) -> any Material {
        let matt = matt(colour)
        guard let library = shaderLibrary else { return matt }
        let shader = CustomMaterial.SurfaceShader(named: Resource.floorShader, in: library)
        guard var coloured = try? CustomMaterial(from: matt, surfaceShader: shader) else { return matt }
        let deep = scenery.floorColour
        coloured.custom.value = SIMD4(Float(deep.x), Float(deep.y), Float(deep.z), .zero)
        return coloured
    }
    private static let shaderLibrary: (any MTLLibrary)? = MTLCreateSystemDefaultDevice()?.makeDefaultLibrary()

    static func seenFromEitherSide(_ material: any Material) -> any Material {
        switch material {
        case var pbr as PhysicallyBasedMaterial:
            pbr.faceCulling = .none
            return pbr
        case var custom as CustomMaterial:
            custom.faceCulling = .none
            return custom
        default:
            return material
        }
    }

    static func matt(_ colour: SIMD3<Double>,
                     roughness: Double = Double(SceneryShape.roughness)) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(red: CGFloat(colour.x), green: CGFloat(colour.y),
                                                 blue: CGFloat(colour.z), alpha: Colour.opaque))
        material.roughness = .init(floatLiteral: Float(roughness))
        material.metallic = .init(floatLiteral: SceneryShape.metallic)
        return material
    }

    // MARK: - The sky (FR-GREENHOLM-020)

    /// The sky as an equirectangular picture: the zenith colour at the top, fading to
    /// the horizon colour at the middle, and the horizon colour below it, where only
    /// the water is ever seen.
    static func skyImage(_ sky: Scenery.Sky) -> CGImage? {
        let height = SkyImage.height
        let width = height * SkyImage.widthInHeights
        // `bytesPerRow` of zero lets Core Graphics choose the row length itself.
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: SkyImage.bitsPerComponent, bytesPerRow: .zero,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        let horizonRow = Double(height) * SkyImage.horizon
        for row in Int.zero..<height {
            // Core Graphics counts rows from the bottom; the picture's top is the zenith.
            let fromTop = Double(height - row) - Geometry.half
            let share = min(fromTop / horizonRow, Fraction.whole)
            let colour = sky.zenith + (sky.horizon - sky.zenith) * share
            context.setFillColor(red: colour.x, green: colour.y, blue: colour.z, alpha: Colour.opaque)
            context.fill(CGRect(x: .zero, y: row, width: width, height: Int(Fraction.whole)))
        }
        return context.makeImage()
    }

    /// The sky as the environment RealityKit draws behind the scene.
    static func skyResource(_ sky: Scenery.Sky) throws -> EnvironmentResource {
        guard let image = skyImage(sky) else { throw SceneryError.skyImageNotPainted }
        do { return try EnvironmentResource(equirectangular: image) }
        catch { throw SceneryError.skyNotGenerated(underlying: error) }
    }

    // MARK: - Birds (FR-GREENHOLM-030)

    /// The flock: a body and two wings per bird, hidden until a flight is under way.
    @MainActor
    static func flock(_ birds: Birds, ambient: Entity) -> Entity {
        let root = Entity()
        root.name = EntityName.birds
        let material = matt(birds.colour)
        let body = MeshResource.roundedBox(SIMD3(Float(BirdShape.bodyWidth), Float(BirdShape.bodyHeight),
                                                 Float(BirdShape.bodyLength)))
        let wingMesh = MeshResource.roundedBox(SIMD3(Float(BirdShape.wingSpan), Float(BirdShape.wingThickness),
                                                     Float(BirdShape.wingDepth)))
        for index in Int.zero..<birds.count {
            let bird = Entity()
            bird.name = EntityName.numbered(EntityName.bird, index)
            bird.scale = SIMD3(repeating: Float(birds.size))
            let trunk = ModelEntity(mesh: body, materials: [material])
            bird.addChild(trunk)
            for side in [Geometry.belowSide, Geometry.aboveSide] {
                // A wing hinges at the body: the hinge is an entity at the body's side,
                // and the wing hangs half its span out from it.
                let hinge = Entity()
                hinge.name = side < .zero ? EntityName.leftWing : EntityName.rightWing
                hinge.position = SIMD3(Float(side * BirdShape.bodyWidth * Geometry.half), .zero, .zero)
                let wing = ModelEntity(mesh: wingMesh, materials: [material])
                wing.position = SIMD3(Float(side * BirdShape.wingSpan * Geometry.half), .zero, .zero)
                hinge.addChild(wing)
                bird.addChild(hinge)
            }
            for model in [trunk] + bird.children.flatMap(\.children) {
                model.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ambient))
            }
            bird.isEnabled = false
            root.addChild(bird)
        }
        return root
    }

    /// The flight under way, kept from its start so that its line holds while the
    /// camera moves.
    final class Pilot {
        private(set) var flight: (number: Int, flight: Birds.Flight)?

        /// The flight under way at `time`, chosen from `focus` and `aspect` when it starts.
        func flight(of birds: Birds, at time: Double, lookingAt focus: SIMD3<Double>,
                    aspect: Double) -> Birds.Flight? {
            guard let number = birds.number(at: time) else { return nil }
            if flight?.number != number {
                flight = (number, birds.flight(number, lookingAt: focus, aspect: aspect))
            }
            return flight?.flight
        }
    }

    /// Puts the flock where the schedule has it at `time`, wings where they are in
    /// their beat, and hides it between flights. `focus` is where the match camera
    /// looks, and `aspect` its frame's width over its height.
    @MainActor
    static func move(_ flock: Entity, _ birds: Birds, at time: Double, lookingAt focus: SIMD3<Double>,
                     aspect: Double, pilot: Pilot) {
        let now = pilot.flight(of: birds, at: time, lookingAt: focus, aspect: aspect)
            .flatMap { birds.flock(at: time, on: $0) }
        let wing = SceneView.radians(birds.wing(at: time))
        for (index, bird) in flock.children.enumerated() {
            guard let now, index < now.positions.count else { bird.isEnabled = false; continue }
            bird.isEnabled = true
            let p = now.positions[index]
            bird.position = SIMD3(Float(p.x), Float(p.y), Float(p.z))
            // A bird's length lies along its z, and it flies towards -z of its own.
            bird.orientation = simd_quatf(angle: Float(atan2(-now.heading.x, -now.heading.z)), axis: Geometry.yAxis)
            for hinge in bird.children where hinge.name == EntityName.leftWing || hinge.name == EntityName.rightWing {
                let side: Float = hinge.name == EntityName.leftWing ? Float(Geometry.belowSide) : Float(Geometry.aboveSide)
                hinge.orientation = simd_quatf(angle: wing * side, axis: Geometry.zAxis)
            }
        }
    }
}

/// What building the scenery can fail at (FR-TOOL-200).
enum SceneryError: IdentifiedError {
    case noAmbientLight
    case surfaceNotBuilt
    case skyImageNotPainted
    case skyNotGenerated(underlying: Error)

    var identifier: ErrorIdentifier {
        switch self {
        case .noAmbientLight:     return .sceneryNoAmbientLight
        case .surfaceNotBuilt:    return .scenerySurfaceNotBuilt
        case .skyImageNotPainted: return .scenerySkyImageNotPainted
        case .skyNotGenerated:    return .scenerySkyNotGenerated
        }
    }

    var details: String {
        switch self {
        case .noAmbientLight:           return "the scene has no ambient light for the scenery to be lit by"
        case .surfaceNotBuilt:          return "a surface of the scenery could not be made into a mesh"
        case .skyImageNotPainted:       return "the sky's picture could not be painted"
        case .skyNotGenerated(let e):   return "the sky could not be made from its picture: \(e)"
        }
    }
}
