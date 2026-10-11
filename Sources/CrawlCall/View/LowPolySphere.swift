// A sphere of the game's own, with as many faces as it is asked for: RealityKit's
// generated sphere is 8064 triangles at any size (Q-450), which is a great deal for an
// eye a few centimetres across (FR-VIEW-260).
//
// file implements: FR-VIEW-260
import Foundation
import RealityKit

enum LowPolySphere {
    /// The triangles a sphere of `rings` bands and `segments` faces round takes: two
    /// a face, less one a face in the band at each pole, which closes to a point.
    static func triangles(rings: Int, segments: Int) -> Int {
        segments * (rings - 2) * 2 + segments * 2
    }

    /// A sphere of `radius` round the origin: `rings` bands from pole to pole and
    /// `segments` faces round each, with normals out from the centre.
    @MainActor
    static func mesh(radius: Float, rings: Int, segments: Int) -> MeshResource? {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        for ring in 0...rings {
            let polar = Float(ring) / Float(rings) * .pi
            for segment in 0...segments {
                let around = Float(segment) / Float(segments) * 2 * .pi
                let normal = SIMD3(sin(polar) * cos(around), cos(polar), sin(polar) * sin(around))
                normals.append(normal)
                positions.append(normal * radius)
            }
        }
        var indices: [UInt32] = []
        let columns = segments + 1
        for ring in 0..<rings {
            for segment in 0..<segments {
                let a = UInt32(ring * columns + segment), b = a + 1
                let c = a + UInt32(columns), d = c + 1
                // The bands at the poles close to a point: one triangle a face there.
                if ring != 0 { indices += [a, b, c] }
                if ring != rings - 1 { indices += [b, d, c] }
            }
        }
        var descriptor = MeshDescriptor(name: EntityName.eye)
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [descriptor])
    }
}
