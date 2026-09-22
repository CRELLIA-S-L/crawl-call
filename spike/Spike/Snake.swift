// Spike check 1 — the snake: a head steered by the joystick through RealityKit's
// character controller (ramps, steps and drops come from the geometry), a tail of
// position samples behind it, and a tube mesh rebuilt every frame through LowLevelMesh.
// Throwaway code (spike/README.md).
import RealityKit
import Metal
import UIKit

struct SnakeComponent: Component {
    var speed: Float = 2.5
    var verticalVelocity: Float = 0
    var samples: [SIMD3<Float>] = []     // tail positions (foot level), newest last
    var maxSegments = 40
    var spacing: Float = 0.25
    var radius: Float = 0.3
}

/// The player's held direction, written by the joystick, read by SnakeSystem.
@MainActor
final class SnakeInput {
    static let shared = SnakeInput()
    var direction = SIMD2<Float>(0, 0)   // screen-space: x right, y up; zero when not held
}

/// Owns the LowLevelMesh the tail is drawn with.
@MainActor
final class TailMesh {
    static let ring = 8
    let capacitySamples: Int
    let mesh: LowLevelMesh
    let entity: ModelEntity

    init(capacitySamples: Int) throws {
        self.capacitySamples = capacitySamples
        let stride = MemoryLayout<Float>.size * 6  // position xyz + normal xyz, packed
        var desc = LowLevelMesh.Descriptor()
        desc.vertexCapacity = capacitySamples * Self.ring
        desc.indexCapacity = (capacitySamples - 1) * Self.ring * 6
        desc.vertexAttributes = [
            .init(semantic: .position, format: .float3, offset: 0),
            .init(semantic: .normal, format: .float3, offset: 12),
        ]
        desc.vertexLayouts = [.init(bufferIndex: 0, bufferStride: stride)]
        mesh = try LowLevelMesh(descriptor: desc)
        let resource = try MeshResource(from: mesh)
        var material = SimpleMaterial(color: UIColor(red: 0.95, green: 0.42, blue: 0.06, alpha: 1), isMetallic: false)
        material.roughness = 0.6
        entity = ModelEntity(mesh: resource, materials: [material])
        entity.name = "tail"
    }

    /// Rebuilds the tube along `samples` (oldest first) ending at `head`.
    func update(samples: [SIMD3<Float>], head: SIMD3<Float>, radius: Float) {
        var pts = samples
        pts.append(head)
        if pts.count > capacitySamples { pts.removeFirst(pts.count - capacitySamples) }
        let n = pts.count
        guard n >= 2 else {
            mesh.parts.removeAll()
            return
        }
        let ring = Self.ring
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)

        mesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
            let f = raw.bindMemory(to: Float.self)
            for i in 0..<n {
                let p = pts[i]
                let prev = pts[max(i - 1, 0)]
                let next = pts[min(i + 1, n - 1)]
                var t = next - prev
                if simd_length(t) < 1e-4 { t = [1, 0, 0] }
                t = simd_normalize(t)
                // A frame around the tangent; keep "up" away from the tangent.
                var up = SIMD3<Float>(0, 1, 0)
                if abs(simd_dot(up, t)) > 0.95 { up = [0, 0, 1] }
                let side = simd_normalize(simd_cross(t, up))
                let upv = simd_cross(side, t)
                // Taper the last three samples of the tail end (oldest) to a point.
                let taper: Float = i < 3 ? Float(i + 1) / 4 : 1
                let r = radius * taper
                for k in 0..<ring {
                    let a = Float(k) / Float(ring) * 2 * .pi
                    let nrm = cos(a) * side + sin(a) * upv
                    // Lift the tube so it sits on the surface rather than half inside it.
                    let v = p + nrm * r + SIMD3<Float>(0, radius, 0)
                    let base = (i * ring + k) * 6
                    f[base] = v.x; f[base + 1] = v.y; f[base + 2] = v.z
                    f[base + 3] = nrm.x; f[base + 4] = nrm.y; f[base + 5] = nrm.z
                    lo = simd_min(lo, v); hi = simd_max(hi, v)
                }
            }
        }
        let indexCount = (n - 1) * ring * 6
        mesh.withUnsafeMutableIndices { raw in
            let idx = raw.bindMemory(to: UInt32.self)
            var w = 0
            for i in 0..<(n - 1) {
                for k in 0..<ring {
                    let k1 = (k + 1) % ring
                    let a = UInt32(i * ring + k), b = UInt32(i * ring + k1)
                    let c = UInt32((i + 1) * ring + k), d = UInt32((i + 1) * ring + k1)
                    idx[w] = a; idx[w + 1] = c; idx[w + 2] = b
                    idx[w + 3] = b; idx[w + 4] = c; idx[w + 5] = d
                    w += 6
                }
            }
        }
        mesh.parts.replaceAll([
            LowLevelMesh.Part(indexOffset: 0, indexCount: indexCount, topology: .triangle,
                              materialIndex: 0, bounds: BoundingBox(min: lo, max: hi)),
        ])
    }
}

@MainActor
final class SnakeSystem: System {
    static let query = EntityQuery(where: .has(SnakeComponent.self))
    static var tail: TailMesh?

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        for head in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var s = head.components[SnakeComponent.self] else { continue }
            step(head: head, snake: &s, dt: dt)
            head.components.set(s)
        }
    }

    private func step(head: Entity, snake s: inout SnakeComponent, dt: Float) {
        Autopilot.shared.steer(headFoot: head.position - SIMD3<Float>(0, s.radius, 0), dt: dt)
        // Screen up is world -z, screen right is world +x for the fixed camera.
        let d = SnakeInput.shared.direction
        var move = SIMD3<Float>(d.x, 0, -d.y)
        if simd_length(move) > 1 { move = simd_normalize(move) }
        move *= s.speed * dt
        // Gravity through the controller: fall when not on the ground.
        let onGround = head.characterControllerState?.isOnGround ?? false
        s.verticalVelocity = onGround ? -0.5 : s.verticalVelocity - 9.8 * dt
        move.y = s.verticalVelocity * dt
        _ = head.moveCharacter(by: move, deltaTime: dt, relativeTo: nil)
        if simd_length(SIMD2<Float>(move.x, move.z)) > 1e-4 {
            let yaw = atan2(move.x, move.z)
            head.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        }

        // Tail samples at fixed spacing along the head's actual path, at foot level.
        let pos = head.position - SIMD3<Float>(0, s.radius, 0)
        if let last = s.samples.last {
            var gap = simd_length(pos - last)
            var from = last
            while gap >= s.spacing {
                from += simd_normalize(pos - from) * s.spacing
                s.samples.append(from)
                gap -= s.spacing
            }
        } else {
            s.samples.append(pos)
        }
        if s.samples.count > s.maxSegments { s.samples.removeFirst(s.samples.count - s.maxSegments) }

        Self.tail?.update(samples: s.samples, head: pos, radius: s.radius)
    }
}
