// The snake is one smooth body (FR-VIEW-250): through the head and every point of the
// tail, resting on the surface, rounded at the head and narrowing to the tail's end,
// facing out, untwisted down a drop, and under its ceiling of triangles.
//
// verifies: FR-VIEW-250, FR-VIEW-260, FR-VIEW-270
import simd
import XCTest
@testable import CrawlCall

final class SnakeBodyTests: XCTestCase {
    private let radius = 0.3
    private var columns: Int { SnakeShape.sides + 1 }

    /// A tail laid along -x from a head at the origin, a body's width between points.
    private func straight(_ points: Int) -> [SIMD3<Double>] {
        (1...max(points, 1)).prefix(points).map { SIMD3(-Double($0) * 0.6, 0, 0) }
    }

    /// Each ring of the body: its centre, its radius, and the direction of its first
    /// vertex from the centre.
    private func rings(_ body: SnakeBody) throws -> [(centre: SIMD3<Double>, radius: Double, first: SIMD3<Double>)] {
        let count = body.positions.count / columns
        XCTAssertEqual(count * columns, body.positions.count, "the body is not whole rings")
        return try (0..<count).map { ring in
            let points = try (0..<SnakeShape.sides).map { try element(ring * columns + $0, of: body.positions) }
            let centre = points.reduce(SIMD3<Double>.zero) { $0 + SIMD3<Double>($1) } / Double(points.count)
            let first = SIMD3<Double>(try element(0, of: points)) - centre
            return (centre, simd_length(first), simd_length(first) > 1e-9 ? simd_normalize(first) : .zero)
        }
    }

    func testTheBodyRunsThroughTheHeadAndEveryPointOfTheTailRestingOnTheSurface() throws {
        let head = SIMD3(0.0, 0, 0)
        let tail = straight(8)
        let body = SnakeBody.tube(head: head, tail: tail, radius: radius)
        let all = try rings(body)
        for point in [head] + tail {
            // Some ring stands on the point: its centre a ring's radius above it.
            let standing = all.contains { ring in
                simd_distance(ring.centre, point + SIMD3(0, ring.radius, 0)) < 1e-4 && ring.radius > 1e-6
            }
            XCTAssertTrue(standing, "no ring rests on \(point)")
        }
        // Nothing of it below the ground it lies on.
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(body.positions.map(\.y).min()), -1e-5)
    }

    func testTheBodyIsWidestAtTheHeadAndNarrowsTowardsTheTailsEnd() throws {
        // The head wider than the body (FR-VIEW-260), the body whole behind it, and
        // narrowing towards the tail's end (FR-VIEW-250).
        let body = SnakeBody.tube(head: .zero, tail: straight(10), radius: radius)
        let all = try rings(body).filter { $0.radius > 1e-6 }
        let widest = try XCTUnwrap(all.map(\.radius).max())
        XCTAssertEqual(widest, radius * SnakeShape.headShare, accuracy: 1e-6)
        let byX = all.sorted { $0.centre.x > $1.centre.x }
        let atHead = try XCTUnwrap(byX.first { abs($0.centre.x) < 1e-6 })
        XCTAssertEqual(atHead.radius, radius * SnakeShape.headShare, accuracy: 1e-6)
        let behindHead = try XCTUnwrap(all.first { abs($0.centre.x + 1.2) < 1e-6 })
        XCTAssertEqual(behindHead.radius, radius, accuracy: 1e-6, "the body is not whole behind the head")
        let lastOnLine = try XCTUnwrap(all.filter { abs($0.centre.x + 6) < 1e-6 }.first)
        XCTAssertEqual(lastOnLine.radius, radius * SnakeShape.tipShare, accuracy: 1e-6)
        // And the narrowing never widens again on the way.
        let alongLine = all.filter { $0.centre.x <= 1e-9 && $0.centre.x >= -6 - 1e-9 }.sorted { $0.centre.x > $1.centre.x }
        for (a, b) in zip(alongLine, alongLine.dropFirst()) {
            XCTAssertLessThanOrEqual(b.radius, a.radius + 1e-9)
        }
    }

    func testEveryTriangleFacesOut() throws {
        // Out is away from the line: along the vertices' own normals. On a straight
        // tail, round a bend wider than the body, and with no tail at all. Round a bend
        // tighter than the body's radius the rings on its inside overlap and fold in,
        // inside the body where nothing sees them; that the body stays well formed there
        // is testTheBodyIsWellFormedForAnyTail's.
        let wide = (1...12).map { step -> SIMD3<Double> in
            let angle = Double(step) * 0.2
            return SIMD3(3 * sin(angle), 0, 3 * (cos(angle) - 1))
        }
        for tail in [straight(6), wide, []] {
            let body = SnakeBody.tube(head: .zero, tail: tail, radius: radius)
            var facing = 0
            for t in stride(from: 0, to: body.indices.count, by: 3) {
                let ids = try (0..<3).map { Int(try element(t + $0, of: body.indices)) }
                let a = SIMD3<Double>(try element(try element(0, of: ids), of: body.positions))
                let b = SIMD3<Double>(try element(try element(1, of: ids), of: body.positions))
                let c = SIMD3<Double>(try element(try element(2, of: ids), of: body.positions))
                let normal = try ids.map { SIMD3<Double>(try element($0, of: body.normals)) }.reduce(.zero, +)
                let face = simd_cross(b - a, c - a)
                guard simd_length(face) > 1e-10 else { continue }   // a point at an end
                XCTAssertGreaterThan(simd_dot(face, normal), 0, "a triangle faces in, tail \(tail)")
                facing += 1
            }
            XCTAssertGreaterThan(facing, 0)
        }
    }

    func testTheBodyDoesNotTwistDownADrop() throws {
        // Along the ground, straight down a ledge, and on: each ring's first vertex
        // turns only a little from the ring before.
        let tail = [SIMD3(0.6, 0, 0), SIMD3(1.2, 0, 0), SIMD3(1.2, -0.6, 0), SIMD3(1.2, -1.2, 0),
                    SIMD3(1.2, -1.8, 0), SIMD3(1.8, -1.8, 0), SIMD3(2.4, -1.8, 0)]
        let body = SnakeBody.tube(head: .zero, tail: tail, radius: radius)
        let all = try rings(body).filter { $0.radius > 1e-6 }
        for (a, b) in zip(all, all.dropFirst()) {
            XCTAssertGreaterThan(simd_dot(a.first, b.first), cos(.pi / 3), "the body twists between two rings")
        }
    }

    func testTheBodyIsWellFormedForAnyTail() {
        // No tail yet, points on top of each other, a U-turn, straight down: always
        // finite, with unit normals.
        let tails: [[SIMD3<Double>]] = [
            [], [.zero, .zero], [SIMD3(0.6, 0, 0), SIMD3(0.6, 0, 0.6), SIMD3(0, 0, 0.6)],
            [SIMD3(0, -0.6, 0), SIMD3(0, -1.2, 0)],
        ]
        for tail in tails {
            let body = SnakeBody.tube(head: .zero, tail: tail, radius: radius)
            XCTAssertFalse(body.indices.isEmpty, "no body for \(tail)")
            XCTAssertTrue(body.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
            XCTAssertTrue(body.normals.allSatisfy { abs(simd_length($0) - 1) < 1e-4 }, "normals for \(tail)")
            XCTAssertTrue(body.indices.allSatisfy { Int($0) < body.positions.count })
            XCTAssertEqual(body.normals.count, body.positions.count)
            XCTAssertEqual(body.surface.count, body.positions.count)
        }
    }

    func testTheBodyStaysUnderItsCeilingOfTriangles() {
        for points in [0, 1, 4, 20, 80] {
            let body = SnakeBody.tube(head: .zero, tail: straight(points), radius: radius)
            XCTAssertLessThanOrEqual(body.triangles, SnakeBody.ceiling(points: points), "\(points) points")
            XCTAssertLessThanOrEqual(body.triangles, 64 * points + 256, "the ceiling is not FR-VIEW-250's")
            // And the buffer the screen gives it holds it.
            XCTAssertLessThanOrEqual(body.positions.count, SnakeBodyBuffer.rings(forPoints: points) * columns)
        }
    }

    func testAPointOfTheTailKeepsItsPlaceOnTheBodyAsTheBodyBends() throws {
        // The skin is laid out by where a vertex lies on the body (FR-VIEW-270): the
        // ring standing on the n-th point of the tail is as far along the body whether
        // the tail runs straight or bends, so a spot there stays there.
        let bent = [SIMD3(-0.6, 0, 0), SIMD3(-1.2, 0, 0), SIMD3(-1.72, 0, 0.3), SIMD3(-2.24, 0, 0.6),
                    SIMD3(-2.54, 0, 1.12), SIMD3(-2.84, 0, 1.64)]
        let straightBody = SnakeBody.tube(head: .zero, tail: straight(6), radius: radius)
        let bentBody = SnakeBody.tube(head: .zero, tail: bent, radius: radius)
        func along(_ body: SnakeBody, at point: SIMD3<Double>) throws -> Double {
            let all = try rings(body)
            let index = try XCTUnwrap(all.indices.first { simd_distance(all[$0].centre, point + SIMD3(0, all[$0].radius, 0)) < 1e-4 })
            return Double(try element(index * columns, of: body.surface).x)
        }
        for k in [2, 4, 5] {
            let a = try along(straightBody, at: try element(k, of: straight(6)))
            let b = try along(bentBody, at: try element(k, of: bent))
            XCTAssertEqual(a, b, accuracy: 0.06, "point \(k) moved along the body when it bent")
        }
    }

    func testWhereAVertexLiesOnTheBodyRunsFromTheHeadToTheTail() throws {
        let body = SnakeBody.tube(head: .zero, tail: straight(6), radius: radius)
        let along = try rings(body).indices.map { Double(try element($0 * columns, of: body.surface).x) }
        for (a, b) in zip(along, along.dropFirst()) { XCTAssertGreaterThanOrEqual(b, a - 1e-6) }
        XCTAssertEqual(try XCTUnwrap(along.first), 0, accuracy: 1e-6)
        XCTAssertGreaterThan(try XCTUnwrap(along.last), 3.6)
    }
}
