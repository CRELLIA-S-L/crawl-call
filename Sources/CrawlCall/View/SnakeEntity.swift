// The snake on screen: one smooth body through the head and every point the tail lays
// down (FR-VIEW-250), rebuilt every frame from where the model says they are. The
// model is in `Snake` and the shape in `SnakeBody`; nothing here decides anything
// about motion or form.
//
// The body is a `LowLevelMesh` whose buffers are written in place each frame, as the
// spike's was (ADR-0001), and made again only when the snake has grown past what it
// holds. A head entity stays where the head is, for what hangs on the head.
//
// Its skin is green and spotted (FR-VIEW-270), painted by `SnakeSkin.metal`.
//
// implements: FR-SNAKE-010, FR-SNAKE-020, FR-VIEW-250, FR-VIEW-260, FR-VIEW-270, FR-VIEW-280, FR-VIEW-310, FR-VIEW-320, FR-VIEW-330, FR-SNAKE-055
import Foundation
import Metal
import RealityKit
import UIKit

enum SnakeEntity {

    /// One vertex as the body's buffer holds it: position, normal, and where it lies
    /// on the body.
    private struct Vertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
        var surface: SIMD2<Float>
    }

    /// The head's entity, and the body for a tail of `segments` points.
    @MainActor
    static func make(radius: Double, segments: Int) -> Entity {
        let root = Entity()
        root.name = EntityName.snake
        let head = Entity()
        head.name = EntityName.head
        for eye in eyes(radius: radius) { head.addChild(eye) }
        root.addChild(head)
        if let body = body(forPoints: segments + SnakeShape.neckPoints, radius: radius) {
            root.addChild(body)
        }
        return root
    }

    /// Puts the head where the model has it and lays the body along the head and the
    /// tail. A body too small for the tail is made again at the tail's length, so that
    /// a snake that has eaten is drawn as long as it is (FR-VIEW-250).
    @MainActor
    static func update(_ entity: Entity, from snake: Snake, radius: Double, lumps: [Digestion.Lump] = [],
                       lunge: LungePose = LungePose(), swallow: SwallowPose = SwallowPose(),
                       sway: SnakeBody.Sway = .none) {
        guard let head = entity.children.first(where: { $0.name == EntityName.head }) else { return }
        // Reared over a living bot it is swallowing, or where the match has it
        // (FR-VIEW-320).
        let drawn = swallow.head(from: snake.drawnHead)
        // What lights the head lights its eyes: the app lights the snake's own parts, and
        // the eyes hang on the head (FR-VIEW-130).
        if let light = head.components[ImageBasedLightReceiverComponent.self] {
            for eye in head.children {
                for part in [eye] + Array(eye.children) where !part.components.has(ImageBasedLightReceiverComponent.self) {
                    part.components.set(light)
                }
            }
        }
        // The way the head faces, level, as an angle round the vertical: the way it last
        // moved, from the first point of the tail to it. Where that is no way at all —
        // nothing behind it yet, or straight down a drop — as it faced before, read off
        // the head without the tip a meal gives it (FR-VIEW-260).
        let before = head.orientation.act(SIMD3<Float>(0, 0, 1))
        var yaw = atan2(Double(before.x), Double(before.z))
        // Whether the way was read afresh rather than kept from the frame before, which
        // already has the sway's turn in it (FR-VIEW-330).
        var fresh = false
        if let behind = snake.tail.first {
            let way = SIMD2(snake.head.x - behind.x, snake.head.z - behind.z)
            if simd_length(way) > SnakeShape.samePoint {
                yaw = atan2(way.x, way.y)
                fresh = true
            }
        }
        // A lunge turns the head to its prey, and squashes and stretches it along the
        // way it faces (FR-VIEW-310).
        if let aim = lunge.aim {
            let way = SIMD2(aim.x - snake.head.x, aim.z - snake.head.z)
            if simd_length(way) > SnakeShape.samePoint {
                yaw = atan2(way.x, way.y)
                fresh = true
            }
        }
        // Reared over the bot it swallows (FR-VIEW-320), it turns as it rises to face away
        // from its neck, over the bot, and the neck bends over behind it, so that the end
        // of the body the head is comes down on the bot mouth-first and the eyes on top
        // of it stay on top of it.
        var neck: [SIMD3<Double>] = []
        if simd_distance(drawn, snake.head) > SnakeShape.samePoint {
            if let over = swallow.over {
                let away = SIMD2(over.x - snake.head.x, over.z - snake.head.z)
                if simd_length(away) > SnakeShape.samePoint {
                    let turn = atan2(sin(atan2(away.x, away.y) - yaw), cos(atan2(away.x, away.y) - yaw))
                    yaw += turn * swallow.eased
                }
            }
            let back = SIMD3(-sin(yaw), .zero, -cos(yaw))
            let bend = (back * cos(swallow.tip) + SIMD3(.zero, Fraction.whole, .zero) * sin(swallow.tip))
                * Swallowing.neckBend * swallow.eased
            if simd_length(bend) > SnakeShape.samePoint { neck.append(drawn + bend) }
            neck.append(snake.drawnHead)
        }
        // Swaying, the head goes to the side with the body's end and points along it
        // (FR-VIEW-330): shifted as the line is at the head, and turned by how the shift
        // changes going forward — turned only where the way was read afresh, since a way
        // kept from the frame before was turned then, and turning it again every frame
        // spun a snake that had not moved yet where it stood.
        let back = SIMD3(-sin(yaw), .zero, -cos(yaw))
        let side = SnakeBody.side(of: back)
        let swayed = drawn + side * sway.shift(behind: .zero)
        if fresh {
            let facing = SIMD3(sin(yaw), .zero, cos(yaw)) + side * sway.slopeAtHead
            yaw = atan2(facing.x, facing.z)
        }
        let orientation = simd_quatf(angle: Float(yaw), axis: SIMD3(0, 1, 0))
            * simd_quatf(angle: Float(swallow.tip), axis: SIMD3(1, 0, 0))
        head.orientation = orientation
        head.scale = SIMD3(Float(lunge.across), Float(lunge.across), Float(lunge.along))
        // The head's own centre on the body's end, whichever way it is tipped: the body is
        // drawn round its line lifted by its radius (`SnakeBody.tube`), and the eyes hang
        // that radius up from the entity in its own frame.
        let lift = radius * SnakeShape.headShare
        let centre = SIMD3<Float>(swayed + SIMD3(.zero, lift, .zero))
        head.position = centre - orientation.act(SIMD3(0, Float(lift) * Float(lunge.across), 0))
        let shape = SnakeBody.tube(head: drawn, tail: neck + snake.tail, radius: radius, lumps: lumps, sway: sway)

        var model = entity.children.first { $0.name == EntityName.body } as? ModelEntity
        if let mesh = model?.model?.mesh.lowLevelMesh,
           mesh.vertexCapacity < shape.positions.count || mesh.indexCapacity < shape.indices.count {
            model?.removeFromParent()
            model = nil
        }
        // Points to spare, for the neck of a head reared over its meal, so that a meal
        // does not make the body again (FR-VIEW-320).
        if model == nil, let made = body(forPoints: snake.tail.count + SnakeShape.neckPoints, radius: radius) {
            // Whatever lights the head lights the new body, as it lit the old one: the
            // app gives the scene's light to every part of the snake it is handed.
            if let light = head.components[ImageBasedLightReceiverComponent.self] {
                made.components.set(light)
            }
            entity.addChild(made)
            model = made
        }
        guard let mesh = model?.model?.mesh.lowLevelMesh else { return }
        write(shape, into: mesh)
    }

    /// Two eyes on top of the head, in its own frame, where +z is the way it faces:
    /// white, each with a dark pupil on its front, all of a sphere of the game's own
    /// (FR-VIEW-260, Q-450).
    @MainActor
    private static func eyes(radius: Double) -> [Entity] {
        let head = radius * SnakeShape.headShare
        let size = head * SnakeEyes.size
        guard let eye = LowPolySphere.mesh(radius: Float(size), rings: SnakeEyes.rings, segments: SnakeEyes.segments),
              let pupil = LowPolySphere.mesh(radius: Float(size * SnakeEyes.pupilSize), rings: SnakeEyes.rings,
                                             segments: SnakeEyes.segments) else { return [] }
        let centre = SIMD3(0, head, 0)
        return [(EntityName.leftEye, -1.0), (EntityName.rightEye, 1.0)].map { name, side in
            let way = simd_normalize(SIMD3(side * SnakeEyes.side, SnakeEyes.up, SnakeEyes.forward))
            let white = ModelEntity(mesh: eye, materials: [shiny(SnakeEyes.white)])
            white.name = name
            white.position = SIMD3<Float>(centre + way * (head * SnakeEyes.out))
            let dark = ModelEntity(mesh: pupil, materials: [shiny(SnakeEyes.pupil)])
            dark.name = EntityName.pupil
            // On the front of the eye, looking the way the head faces.
            dark.position = SIMD3<Float>(simd_normalize(SIMD3(.zero, SnakeEyes.up * Geometry.half, Fraction.whole))
                                         * (size * SnakeEyes.pupilOut))
            white.addChild(dark)
            return white
        }
    }

    private static func shiny(_ colour: SIMD3<Double>) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(red: colour.x, green: colour.y, blue: colour.z, alpha: 1))
        material.roughness = .init(floatLiteral: SnakeEyes.roughness)
        material.metallic = .init(floatLiteral: .zero)
        return material
    }

    /// A model whose mesh holds a body through a tail of `points`, and some room to grow.
    @MainActor
    private static func body(forPoints points: Int, radius: Double) -> ModelEntity? {
        let room = points + SnakeBodyBuffer.spare
        let rings = SnakeBodyBuffer.rings(forPoints: room)
        let columns = SnakeShape.sides + 1
        var descriptor = LowLevelMesh.Descriptor()
        descriptor.vertexCapacity = rings * columns
        descriptor.indexCapacity = max(rings - 1, .zero) * SnakeShape.sides * Square.triangle * 2
        descriptor.vertexAttributes = [
            .init(semantic: .position, format: .float3, offset: MemoryLayout<Vertex>.offset(of: \.position) ?? .zero),
            .init(semantic: .normal, format: .float3, offset: MemoryLayout<Vertex>.offset(of: \.normal) ?? .zero),
            .init(semantic: .uv0, format: .float2, offset: MemoryLayout<Vertex>.offset(of: \.surface) ?? .zero),
        ]
        descriptor.vertexLayouts = [.init(bufferIndex: .zero, bufferStride: MemoryLayout<Vertex>.stride)]
        descriptor.indexType = .uint32
        guard let mesh = try? LowLevelMesh(descriptor: descriptor),
              let resource = try? MeshResource(from: mesh) else { return nil }
        let model = ModelEntity(mesh: resource, materials: [skin(radius: radius)])
        model.name = EntityName.body
        return model
    }

    /// The body's skin (FR-VIEW-270): green, paler along the belly, with darker spots
    /// laid out on the body by the skin shader; the green alone where Metal or the
    /// function is not there.
    @MainActor
    static func skin(radius: Double) -> any Material {
        var green = PhysicallyBasedMaterial()
        green.baseColor = .init(tint: UIColor(red: SnakeSkin.green.x, green: SnakeSkin.green.y,
                                              blue: SnakeSkin.green.z, alpha: 1))
        green.roughness = .init(floatLiteral: SnakeSkin.roughness)
        green.metallic = .init(floatLiteral: .zero)
        guard let library = shaderLibrary,
              var skin = try? CustomMaterial(from: green, surfaceShader: .init(named: Resource.skinShader, in: library))
        else { return green }
        skin.custom.value = SIMD4(Float(SnakeSkin.spots.x), Float(SnakeSkin.spots.y), Float(SnakeSkin.spots.z),
                                  Float(radius))
        return skin
    }
    private static let shaderLibrary: (any MTLLibrary)? = MTLCreateSystemDefaultDevice()?.makeDefaultLibrary()

    @MainActor
    private static func write(_ shape: SnakeBody, into mesh: LowLevelMesh) {
        var lowest = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var highest = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        mesh.replaceUnsafeMutableBytes(bufferIndex: .zero) { raw in
            let vertices = raw.bindMemory(to: Vertex.self)
            for index in shape.positions.indices where index < vertices.count {
                vertices[index] = Vertex(position: shape.positions[index], normal: shape.normals[index],
                                         surface: shape.surface[index])
                lowest = simd_min(lowest, shape.positions[index])
                highest = simd_max(highest, shape.positions[index])
            }
        }
        mesh.replaceUnsafeMutableIndices { raw in
            let indices = raw.bindMemory(to: UInt32.self)
            for index in shape.indices.indices where index < indices.count {
                indices[index] = shape.indices[index]
            }
        }
        let count = min(shape.indices.count, mesh.indexCapacity)
        mesh.parts.replaceAll(count > .zero
            ? [LowLevelMesh.Part(indexOffset: .zero, indexCount: count, topology: .triangle,
                                 materialIndex: .zero, bounds: BoundingBox(min: lowest, max: highest))]
            : [])
    }
}

/// How the body's buffer is sized (FR-VIEW-250): for the tail it has now and some
/// points more, so that eating does not remake it every time.
enum SnakeBodyBuffer {
    static let spare = 16

    /// The rings a body through a tail of `points` takes: the rings between the head
    /// and each point, the head's own, and the rounding at each end.
    static func rings(forPoints points: Int) -> Int {
        points * SnakeShape.ringsBetweenPoints + 1 + SnakeShape.endRings * 2
    }
}
