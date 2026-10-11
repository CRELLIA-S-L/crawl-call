// A drawn box has rounded edges and stays cheap (FR-VIEW-240): it is the size it was
// asked for, no corner of the square box is left in it, and it is drawn with no more
// than 400 triangles — the ceiling that keeps RealityKit's own rounded box, 13 068
// triangles at any size, out of the game (ADR-0037).
//
// file verifies: FR-VIEW-240
import RealityKit
import XCTest
@testable import CrawlCall

@MainActor
final class RoundedBoxTests: XCTestCase {
    private static let ceiling = 400
    /// A square box, the one thing a rounded box must not be drawn as.
    private static let squareBox = 12
    private static let tolerance: Float = 1e-4

    /// A module, a partition of 0.1 m, a shot's bar, a bird's wing.
    private static let sizes: [SIMD3<Float>] = [
        SIMD3(1, 1, 1), SIMD3(1, 3, 0.1), SIMD3(0.02, 0.02, 1), SIMD3(0.8, 0.04, 0.35),
    ]

    private func triangles(_ mesh: MeshResource) -> Int {
        mesh.contents.models.reduce(0) { sum, model in
            model.parts.reduce(sum) { $0 + ($1.triangleIndices?.count ?? 0) / 3 }
        }
    }

    private func positions(_ mesh: MeshResource) -> [SIMD3<Float>] {
        mesh.contents.models.flatMap { $0.parts.flatMap { $0.positions.elements } }
    }

    private func models(under entity: Entity) -> [ModelEntity] {
        let own = (entity as? ModelEntity).map { [$0] } ?? []
        return own + entity.children.flatMap(models(under:))
    }

    func testARoundedBoxIsTheSizeItWasAskedFor() {
        for size in Self.sizes {
            let bounds = MeshResource.roundedBox(size).bounds
            for axis in 0..<3 {
                XCTAssertEqual(bounds.extents[axis], size[axis], accuracy: Self.tolerance, "\(size), axis \(axis)")
                XCTAssertEqual(bounds.center[axis], 0, accuracy: Self.tolerance, "\(size), axis \(axis)")
            }
        }
    }

    func testNoCornerOfTheSquareBoxIsLeft() {
        for size in Self.sizes {
            let half = size / 2 - Self.tolerance
            let corners = positions(.roundedBox(size)).filter { all(abs($0) .>= half) }
            XCTAssertTrue(corners.isEmpty, "\(size): \(corners.count) vertices stand at a square corner")
        }
    }

    func testARoundedBoxIsDrawnWithNoMoreThanTheCeiling() {
        for size in Self.sizes {
            let count = triangles(.roundedBox(size))
            XCTAssertGreaterThan(count, Self.squareBox, "\(size)")
            XCTAssertLessThanOrEqual(count, Self.ceiling, "\(size)")
        }
    }

    func testEveryModuleDrawnAsABoxIsRounded() throws {
        let world = try Launch.world(map: "room").get()
        // The ground slabs are drawn joined, one mesh a module (ADR-0047); every other
        // piece is an entity of its own, in the plan's order.
        let slabs = Set(world.plan.groundSlabs)
        let pieces = world.plan.pieces.enumerated().filter { $0.element.size.min() > .zero && !slabs.contains($0.offset) }.map(\.element)
        let map = SceneBuilder.entity(for: world.plan).root
        let joined = map.children.filter { $0.name.hasPrefix(EntityName.slabsPrefix) }
        let single = map.children.filter { !$0.name.hasPrefix(EntityName.slabsPrefix) }
        XCTAssertEqual(single.count, pieces.count)
        let boxes = zip(pieces, single).filter { $0.0.figure == .box }
        XCTAssertFalse(boxes.isEmpty, "the room is built of boxes")
        for (piece, entity) in boxes {
            let mesh = try XCTUnwrap((entity as? ModelEntity)?.model?.mesh)
            let count = triangles(mesh)
            XCTAssertGreaterThan(count, Self.squareBox, piece.module)
            XCTAssertLessThanOrEqual(count, Self.ceiling, piece.module)
        }
        // A joined mesh is its slabs' rounded boxes and nothing else: each of them
        // rounded and under the ceiling, their triangles summing to the mesh's.
        XCTAssertFalse(slabs.isEmpty, "the room has no ground slabs, so the test proves nothing about them")
        for entity in joined {
            let module = String(entity.name.dropFirst(EntityName.slabsPrefix.count))
            let own = slabs.map { world.plan.pieces[$0] }.filter { $0.module == module }
            XCTAssertFalse(own.isEmpty, entity.name)
            var expected = 0
            for slab in own {
                let count = triangles(MeshResource.roundedBox(SIMD3<Float>(slab.size)))
                XCTAssertGreaterThan(count, Self.squareBox, module)
                XCTAssertLessThanOrEqual(count, Self.ceiling, module)
                expected += count
            }
            let mesh = try XCTUnwrap((entity as? ModelEntity)?.model?.mesh)
            XCTAssertEqual(triangles(mesh), expected, module)
        }
    }

    func testShotsAndBirdsAreRounded() throws {
        let camera = CameraRange(pitches: 50...60, fieldOfView: 50, distance: 13.2, widestAspect: 2, pitch: 55)
        let birds = Birds(interval: 10, count: 1, speed: 5, size: 0.4, wingbeats: 2, colour: SIMD3(1, 1, 1),
                          height: 6, camera: camera, seen: 4)
        let drawn = models(under: ShotEntity.make(for: []))
            + models(under: SceneryBuilder.flock(birds, ambient: Entity()))
        XCTAssertFalse(drawn.isEmpty)
        for model in drawn {
            let mesh = try XCTUnwrap(model.model?.mesh)
            let count = triangles(mesh)
            XCTAssertGreaterThan(count, Self.squareBox, model.name)
            XCTAssertLessThanOrEqual(count, Self.ceiling, model.name)
        }
    }
}
