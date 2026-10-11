// The ground goes on under the water (FR-MAP-270): the floor's shape, read off the
// mesh it is drawn with, and how the shipped island lays it out to the edge of the
// frame. That the water over it can be seen through is IslandMapTests' (FR-MAP-280).
//
// file verifies: FR-MAP-270
import RealityKit
import XCTest
@testable import CrawlCall

final class SeaFloorTests: XCTestCase {
    private static let edge = 1.2, width = 3.0, top = -0.05, bottom = -1.2
    private static let sampling = 5
    private static let tolerance = 1e-9

    /// An island of three cells by two with a hollow, a basement under one of them,
    /// and a grid reaching well past the floor's slope.
    private func outline() throws -> Outline {
        let cells: Set<PieceIndex.Cell> = [
            .init(x: 0, z: 0), .init(x: 1, z: 0), .init(x: 2, z: 0), .init(x: 0, z: 1), .init(x: 2, z: 1),
        ]
        return try XCTUnwrap(Outline.around(cells, basement: [.init(x: 1, z: 0)], cellSize: 2, margin: 0.5,
                                            rounding: 1, reach: Self.edge + Self.width + 1))
    }

    private func floor(_ outline: Outline) -> Mesh {
        Outline.floor(under: outline, edge: Self.edge, width: Self.width, top: Self.top, bottom: Self.bottom,
                      stride: Self.sampling)
    }

    private func smoothstep(_ t: Double) -> Double {
        let t = min(max(t, 0), 1)
        return t * t * (3 - 2 * t)
    }

    func testTheFloorFallsFromJustUnderTheSurfaceAtTheEdgeToItsDepth() throws {
        let outline = try outline()
        let mesh = floor(outline)
        XCTAssertFalse(mesh.isEmpty)
        XCTAssertEqual(mesh.shares.count, mesh.positions.count)
        for (position, share) in zip(mesh.positions, mesh.shares) {
            // How far beyond the edge, read off the field where the vertex stands.
            let beyond = -outline.value(of: outline.signed, at: SIMD2(position.x, position.z)) - Self.edge
            XCTAssertEqual(share, smoothstep(beyond / Self.width), accuracy: Self.tolerance, "\(position)")
            XCTAssertEqual(position.y, Self.top + (Self.bottom - Self.top) * share, accuracy: Self.tolerance)
        }
        // Both ends are reached: at the edge and at the full depth.
        XCTAssertTrue(mesh.positions.contains { abs($0.y - Self.top) < Self.tolerance })
        XCTAssertTrue(mesh.positions.contains { abs($0.y - Self.bottom) < Self.tolerance })
    }

    func testTheFloorHasNoStep() throws {
        // Along any edge of the mesh the floor rises no faster than the smoothstep's
        // steepest slope, 1.5 times depth over width, allows over that edge's run: a
        // distance field changes by no more than the distance moved.
        let mesh = floor(try outline())
        let steepest = 1.5 * (Self.top - Self.bottom) / Self.width
        for triangle in stride(from: 0, to: mesh.indices.count, by: 3) {
            let corners = try (0..<3).map { try vertex(triangle + $0, of: mesh) }
            for (a, b) in [(0, 1), (1, 2), (2, 0)] {
                let run = simd_length(SIMD2(corners[a].x - corners[b].x, corners[a].z - corners[b].z))
                XCTAssertLessThanOrEqual(abs(corners[a].y - corners[b].y), steepest * run + 1e-6)
            }
        }
    }

    func testTheFloorFacesUpAndItsNormalsFollowItsSlope() throws {
        let mesh = floor(try outline())
        for triangle in stride(from: 0, to: mesh.indices.count, by: 3) {
            let a = try vertex(triangle, of: mesh), b = try vertex(triangle + 1, of: mesh)
            let c = try vertex(triangle + 2, of: mesh)
            XCTAssertGreaterThan(simd_cross(b - a, c - a).y, 0, "a square of the floor faces down")
        }
        for normal in mesh.normals {
            XCTAssertEqual(simd_length(normal), 1, accuracy: 1e-9)
            XCTAssertGreaterThan(normal.y, 0)
        }
        // Where the floor slopes, its normal leans away from the island: out and up.
        let sloping = zip(mesh.positions, mesh.normals).filter { abs($0.1.y - 1) > 1e-3 }
        XCTAssertFalse(sloping.isEmpty, "no normal follows the slope")
    }

    func testTheFloorReachesUnderTheShoreAndNeverUnderTheIsland() throws {
        let outline = try outline()
        let mesh = floor(outline)
        let spacing = outline.grid.step * Double(Self.sampling)
        var underShore = false
        let basement = outline.overBasement.map { $0 ? 1.0 : 0.0 }
        // A square of the floor is its two triangles, six indices.
        for square in stride(from: 0, to: mesh.indices.count, by: 6) {
            let corners = try (0..<6).map { try vertex(square + $0, of: mesh) }
            let values = corners.map { outline.value(of: outline.signed, at: SIMD2($0.x, $0.z)) }
            // Every square has a corner beyond the shore, give or take one square.
            XCTAssertLessThan(try XCTUnwrap(values.min()), -Self.edge + spacing + 1e-9)
            // None stands over a basement, which the island leaves open (FR-MAP-170).
            for p in corners {
                XCTAssertEqual(outline.value(of: basement, at: SIMD2(p.x, p.z)), 0,
                               "the floor stands over a basement at \(p)")
            }
            if values.contains(where: { $0 > -Self.edge }) { underShore = true }
        }
        XCTAssertTrue(underShore, "the floor stops at the shore's edge and leaves a gap under it")
    }

    func testALevelRectangleFacesUpAtItsShare() throws {
        let rect = GroundRect(lowest: SIMD2(-3, 1), highest: SIMD2(4, 6))
        let mesh = Outline.level(rect, height: -1.2, share: 1)
        XCTAssertEqual(mesh.indices.count, 6)
        XCTAssertEqual(mesh.shares, [Double](repeating: 1, count: mesh.positions.count))
        XCTAssertTrue(mesh.positions.allSatisfy { $0.y == -1.2 })
        XCTAssertEqual(Set(mesh.positions.map(\.x)), [-3, 4])
        XCTAssertEqual(Set(mesh.positions.map(\.z)), [1, 6])
        for triangle in [0, 3] {
            let a = try vertex(triangle, of: mesh), b = try vertex(triangle + 1, of: mesh)
            let c = try vertex(triangle + 2, of: mesh)
            XCTAssertGreaterThan(simd_cross(b - a, c - a).y, 0)
        }
    }

    @MainActor
    func testAFloorMeshCarriesItsShareAndATangentFrame() throws {
        let mesh = floor(try outline())
        let resource = try SceneryBuilder.meshResource(mesh)
        let part = try XCTUnwrap(resource.contents.models.first?.parts.first)
        let coordinates = try XCTUnwrap(part.textureCoordinates?.elements)
        XCTAssertEqual(coordinates.count, mesh.shares.count)
        for (coordinate, share) in zip(coordinates, mesh.shares) {
            XCTAssertEqual(Double(coordinate.x), share, accuracy: 1e-6)
        }
        XCTAssertEqual(part.tangents?.count, mesh.positions.count)
        XCTAssertEqual(part.bitangents?.count, mesh.positions.count)
        // A surface with no floor in it carries no texture coordinates.
        let level = Outline.surface(where: try outline().signed.map { -($0 + 1) }, on: try outline().grid, height: 0)
        XCTAssertNil(try SceneryBuilder.meshResource(level).contents.models.first?.parts.first?.textureCoordinates)
    }

    func testTheShippedFloorReachesEverythingTheCameraCanShowThroughTheWater() throws {
        let world = try Launch.world().get()
        guard case .greenholm(let c) = world.setting else { return XCTFail("the shipped map is on Greenholm") }
        let camera = CameraRange(view: world.configurations.view, plan: world.plan, widestAspect: 2.174)
        let s = try world.setting.scenery(around: world.plan, camera: camera)
        let depth = s.surface - c.floorDepth
        let floorParts = s.parts.filter { $0.layer == .floor }
        XCTAssertFalse(floorParts.isEmpty)
        XCTAssertTrue(floorParts.allSatisfy { abs($0.top - depth) < 1e-9 }, "the floor beyond the grid is at its depth")
        XCTAssertTrue(floorParts.allSatisfy { $0.colour == c.floorColour.rgb })
        let floorSurface = try XCTUnwrap(s.surfaces.first { $0.layer == .floor })
        XCTAssertEqual(floorSurface.colour, c.shoreColour.rgb, "the floor starts at the shore's colour")
        XCTAssertEqual(try XCTUnwrap(floorSurface.mesh.positions.map(\.y).min()), depth, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(floorSurface.mesh.positions.map(\.y).max()),
                       s.surface - IslandShape.floorUnderSurface, accuracy: 1e-9)
        // Everything the camera can show at the floor's depth is floor: the slabs
        // beyond the grid, or the grid's own floor. That is not a rectangle wider than
        // the water's: a lower plane is met further along every ray, the near edge of
        // the frame included, so it is its own rectangle.
        let covered = try XCTUnwrap(FrameCoverage.covered(arena: world.plan.bounds, camera: camera, surface: depth))
        let slabs = floorParts.map { GroundRect(lowest: SIMD2($0.lowest.x, $0.lowest.z), highest: SIMD2($0.highest.x, $0.highest.z)) }
        let grid = floorSurface.mesh.positions
        let gridRect = GroundRect(lowest: SIMD2(try XCTUnwrap(grid.map(\.x).min()), try XCTUnwrap(grid.map(\.z).min())),
                                  highest: SIMD2(try XCTUnwrap(grid.map(\.x).max()), try XCTUnwrap(grid.map(\.z).max())))
        var chooser = SplitMix(state: 29)
        for _ in 0..<2000 {
            let p = SIMD2(Double.random(in: covered.lowest.x...covered.highest.x, using: &chooser),
                          Double.random(in: covered.lowest.y...covered.highest.y, using: &chooser))
            let inSlab = slabs.contains { $0.grown(by: 1e-6).contains(p) }
            XCTAssertTrue(inSlab || gridRect.grown(by: 0.3).contains(p), "no floor at \(p)")
        }
    }
}
