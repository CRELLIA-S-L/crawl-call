// Spike check 1 — the snake: a head that walks navigation-mesh paths (tap to go),
// a tail of position samples behind it, and a tube mesh rebuilt every frame
// through LowLevelMesh. Throwaway code (spike/README.md).
import RealityKit
import Metal
import UIKit

struct SnakeComponent: Component {
    var controller: NavigationController?
    var path: [SIMD3<Float>] = []
    var nextNode = 0
    var waitingForPath = false
    var speed: Float = 2.5
    var samples: [SIMD3<Float>] = []     // tail positions, newest last
    var maxSegments = 40
    var spacing: Float = 0.25
    var radius: Float = 0.3
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
        // Path arrives asynchronously after requestPath; copy it once it succeeds.
        if s.waitingForPath, let c = s.controller {
            switch c.pathfindStatus {
            case .succeeded:
                s.path = c.currentPath.map(\.position)
                s.nextNode = 0
                s.waitingForPath = false
                let ys = s.path.map { String(format: "%.1f", $0.y) }.joined(separator: " ")
                Telemetry.shared.note("path \(s.path.count) nodes, y: \(ys)")
            case .failed:
                s.waitingForPath = false
                Telemetry.shared.note("path failed")
            default:
                break
            }
        }
        // Follow the path: the head sits on the mesh surface; the visual is lifted by its radius.
        var pos = head.position - SIMD3<Float>(0, s.radius, 0)
        var budget = s.speed * dt
        while budget > 0, s.nextNode < s.path.count {
            let target = s.path[s.nextNode]
            let d = target - pos
            let dist = simd_length(d)
            if dist <= budget {
                pos = target
                budget -= dist
                s.nextNode += 1
            } else {
                pos += d / dist * budget
                budget = 0
            }
        }
        head.position = pos + SIMD3<Float>(0, s.radius, 0)

        // Tail samples at fixed spacing along the head's actual path.
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
