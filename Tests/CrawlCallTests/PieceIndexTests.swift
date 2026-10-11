// The piece index narrows what a sight test looks at and must never change its answer
// (ADR-0028): every line asked through the index is answered as the whole plan would
// answer it, and every piece that touches a box is among its candidates.
//
// file verifies: FR-BOT-050, FR-BOT-118
import XCTest
@testable import CrawlCall

final class PieceIndexTests: XCTestCase {
    /// The sight test as it was before the index: every piece of the plan, one by one.
    private func clearByEveryPiece(from eye: SIMD3<Double>, to point: SIMD3<Double>, through plan: ScenePlan) -> Bool {
        let low = SIMD3(min(eye.x, point.x), min(eye.y, point.y), min(eye.z, point.z))
        let high = SIMD3(max(eye.x, point.x), max(eye.y, point.y), max(eye.z, point.z))
        for piece in plan.pieces where piece.size.min() > 0 {
            let half = piece.size / 2
            if piece.centre.x + half.x < low.x || piece.centre.x - half.x > high.x { continue }
            if piece.centre.y + half.y < low.y || piece.centre.y - half.y > high.y { continue }
            if piece.centre.z + half.z < low.z || piece.centre.z - half.z > high.z { continue }
            if Sight.blocks(centre: piece.centre, size: piece.size, from: eye, to: point, margin: 0) { return false }
        }
        return true
    }

    func testEveryLineIsAnsweredAsTheWholePlanWouldAnswerIt() throws {
        let world = try Launch.world().get()
        let cell = world.configurations.tuning.navigationGraphCellSize
        // Every fourth walkable cell on every floor, at a body's height and at a bot's
        // eyes, each to each: short lines and lines across the whole map, lines along a
        // wall and through one.
        let cells = world.graph.nodes.sorted { ($0.floor, $0.z, $0.x) < ($1.floor, $1.z, $1.x) }
            .enumerated().filter { $0.offset % 4 == 0 }.map(\.element)
        let points = cells.flatMap { node -> [SIMD3<Double>] in
            let ground = SIMD3(Double(node.x) * cell, Double(node.floor) * world.plan.floorHeight, Double(node.z) * cell)
            return [ground + SIMD3(0, 0.3, 0), ground + SIMD3(0, world.configurations.bot.eyeHeight, 0)]
        }
        var asked = 0, blocked = 0
        for (i, a) in points.enumerated() {
            for b in points[(i + 1)...] {
                let indexed = Sight.isClear(from: a, to: b, through: world.plan)
                XCTAssertEqual(indexed, clearByEveryPiece(from: a, to: b, through: world.plan), "\(a) → \(b)")
                asked += 1
                if !indexed { blocked += 1 }
            }
        }
        // Both answers were given, many times: a test of lines that all pass, or all
        // stop, would not tell the index from a constant.
        XCTAssertGreaterThan(asked, 1000)
        XCTAssertGreaterThan(blocked, asked / 10)
        XCTAssertLessThan(blocked, asked - asked / 10)
    }

    func testEveryPieceThatTouchesABoxIsACandidate() throws {
        let world = try Launch.world().get()
        let plan = world.plan
        // Boxes of every size, including ones whose edge lies exactly on a piece's edge.
        let bounds = plan.bounds
        var boxes: [(SIMD3<Double>, SIMD3<Double>)] = []
        for x in stride(from: bounds.lowest.x, through: bounds.highest.x, by: 1.25) {
            for z in stride(from: bounds.lowest.z, through: bounds.highest.z, by: 1.25) {
                for extent in [0.0, 0.25, 2.0, 7.5] {
                    boxes.append((SIMD3(x, bounds.lowest.y, z), SIMD3(x + extent, bounds.highest.y, z + extent)))
                }
            }
        }
        for (low, high) in boxes {
            let candidates = Set(plan.index.candidates(low: low, high: high))
            for (i, piece) in plan.pieces.enumerated() where piece.size.min() > 0 {
                let half = piece.size / 2
                let touches = !(piece.centre.x + half.x < low.x || piece.centre.x - half.x > high.x
                                || piece.centre.z + half.z < low.z || piece.centre.z - half.z > high.z)
                if touches { XCTAssertTrue(candidates.contains(i), "piece \(i) touches \(low)…\(high) and was left out") }
            }
        }
    }

    func testABoxTheGridCannotHoldIsAnsweredWithEveryPiece() throws {
        // Not a number, and wider than the map by far: the scan before the index
        // answered both, so the index must not trap on either.
        let plan = try Launch.world().get().plan
        let every = Array(0..<plan.pieces.count)
        XCTAssertEqual(plan.index.candidates(low: SIMD3(.nan, 0, 0), high: SIMD3(1, 0, 1)), every)
        XCTAssertEqual(plan.index.candidates(low: SIMD3(0, 0, 0), high: SIMD3(.infinity, 0, 1)), every)
        XCTAssertEqual(plan.index.candidates(low: SIMD3(-1e18, 0, -1e18), high: SIMD3(1e18, 0, 1e18)), every)
        // A sight test given such a line answers rather than traps; which answer is
        // the scan's business, as it was before the index.
        _ = Sight.isClear(from: SIMD3(.nan, 1, 0), to: SIMD3(0, 1, 0), through: plan)
    }

    func testAPlanWithNoCellSizeHandsBackEveryPiece() {
        let piece = ScenePlan.Piece(module: "wall", size: SIMD3(1, 1, 1), centre: .zero, colour: .zero, level: 0)
        let plan = ScenePlan(pieces: [piece, piece], cellSize: 0, floorHeight: 3)
        XCTAssertEqual(plan.index.candidates(low: SIMD3(50, 0, 50), high: SIMD3(51, 0, 51)), [0, 1])
    }
}
