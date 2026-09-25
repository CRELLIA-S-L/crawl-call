// A meal is a swelling that travels down the body (FR-VIEW-280): it grows behind the
// head as the prey goes in, then travels down the body and is gone past the tail's
// end; the body swells round it, and no more triangles are drawn for it.
//
// verifies: FR-VIEW-280
import RealityKit
import simd
import XCTest
@testable import CrawlCall

final class DigestionTests: XCTestCase {
    private let frame = 1.0 / 60

    func testTheSwellingGrowsBehindTheHeadAsThePreyGoesIn() throws {
        var digestion = Digestion()
        for share in [0.1, 0.4, 0.8] {
            digestion.step(seconds: frame, swallowed: share, length: 3)
            let lump = try XCTUnwrap(digestion.lumps.first)
            XCTAssertEqual(digestion.lumps.count, 1)
            XCTAssertEqual(lump.size, share, accuracy: 1e-12)
            XCTAssertEqual(lump.along, SnakeLump.behindHead, accuracy: 1e-12, "the swelling left the head mid-meal")
        }
    }

    func testOnceTheMealIsOverTheSwellingTravelsDownAndIsGonePastTheTail() throws {
        var digestion = Digestion()
        digestion.step(seconds: frame, swallowed: 0.9, length: 3)
        var last = SnakeLump.behindHead
        var frames = 0
        while !digestion.lumps.isEmpty && frames < 600 {
            digestion.step(seconds: frame, swallowed: nil, length: 3)
            if let lump = digestion.lumps.first {
                XCTAssertEqual(lump.size, 1, accuracy: 1e-12, "the meal shrank once it was in")
                XCTAssertGreaterThan(lump.along, last)
                last = lump.along
            }
            frames += 1
        }
        XCTAssertTrue(digestion.lumps.isEmpty, "the swelling never left the body")
        // It took as long as the body at the swelling's pace, give or take its width.
        let seconds = Double(frames) * frame
        XCTAssertEqual(seconds, (3 + 2 * SnakeLump.width - SnakeLump.behindHead) / SnakeLump.speed, accuracy: 0.05)
    }

    func testASecondMealTravelsBehindTheFirst() throws {
        var digestion = Digestion()
        digestion.step(seconds: frame, swallowed: 1, length: 4)
        for _ in 0..<30 { digestion.step(seconds: frame, swallowed: nil, length: 4) }
        digestion.step(seconds: frame, swallowed: 0.3, length: 4)
        XCTAssertEqual(digestion.lumps.count, 2)
        let first = try element(0, of: digestion.lumps), second = try element(1, of: digestion.lumps)
        XCTAssertGreaterThan(first.along, second.along, "the first meal did not stay ahead")
        XCTAssertEqual(second.along, SnakeLump.behindHead, accuracy: 1e-12)
    }

    func testTheBodySwellsRoundTheMealAndNowhereElse() throws {
        let tail = (1...8).map { SIMD3(-Double($0) * 0.6, 0, 0) }
        let plain = SnakeBody.tube(head: .zero, tail: tail, radius: 0.3)
        let fed = SnakeBody.tube(head: .zero, tail: tail, radius: 0.3, lumps: [.init(along: 2.4, size: 1)])
        XCTAssertEqual(fed.triangles, plain.triangles, "the swelling added triangles")
        // At the swelling's middle the body is wider by the swell; far from it, as it was.
        XCTAssertEqual(SnakeBody.swelling(at: 2.4, by: [.init(along: 2.4, size: 1)]), 1 + SnakeLump.swell, accuracy: 1e-12)
        XCTAssertEqual(SnakeBody.swelling(at: 0.2, by: [.init(along: 2.4, size: 1)]), 1, accuracy: 1e-6)
        XCTAssertEqual(SnakeBody.swelling(at: 2.4, by: []), 1)
        let widest = try XCTUnwrap(zip(fed.positions, plain.positions).map { simd_distance($0, $1) }.max())
        XCTAssertGreaterThan(widest, 0.1, "the body did not swell")
        XCTAssertEqual(try element(0, of: fed.positions).x, try element(0, of: plain.positions).x, accuracy: 1e-5,
                       "the head moved for a swelling behind it")
    }

    @MainActor
    func testTheScreenDrawsTheSwellingItIsGiven() throws {
        // The body on screen stands taller with a meal in it than without.
        let snake = Snake(head: .zero, floor: 0, segments: 4, segmentSpacing: 0.6)
        let entity = SnakeEntity.make(radius: 0.3, segments: 4)
        func top() throws -> Float {
            let body = try XCTUnwrap(entity.children.first { $0.name == "body" } as? ModelEntity)
            let mesh = try XCTUnwrap(body.model?.mesh.lowLevelMesh)
            return try XCTUnwrap(mesh.parts.first).bounds.max.y
        }
        SnakeEntity.update(entity, from: snake, radius: 0.3)
        let plain = try top()
        SnakeEntity.update(entity, from: snake, radius: 0.3, lumps: [.init(along: 0.2, size: 1)])
        XCTAssertGreaterThan(try top(), plain + 0.05, "the screen did not draw the swelling")
    }
}
