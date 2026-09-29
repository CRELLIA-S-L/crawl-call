// A living bot swallowed from the top down (FR-VIEW-320): the head rears over the bot
// and tips mouth-down, rising and lowering over its time rather than at once, its eyes
// staying on it, and comes down over the bot, which stands where it stands and is cut
// away at the mouth, its boots last. Geometry is compared within a tolerance, never for
// equality (`specs/50-verification.md`).
//
// verifies: FR-VIEW-320
import RealityKit
import simd
import XCTest
@testable import CrawlCall

final class SwallowTests: XCTestCase {
    private let frame = 1.0 / 60
    private let height = 1.0

    func testTheHeadRearsOverTheBotOverItsTimeAndComesDownAfter() {
        var pose = SwallowPose()
        let ground = SIMD3(1.0, 0, 1.0)
        let prey = SIMD3(1.5, 0, 1.0)
        XCTAssertEqual(pose.head(from: ground), ground, "reared with nothing being eaten")
        XCTAssertEqual(pose.tip, 0, accuracy: 1e-12)

        var heights: [Double] = []
        for _ in 0..<60 {
            pose.step(seconds: frame, eatingAlive: prey, height: height)
            heights.append(pose.head(from: ground).y)
        }
        // Rising, never at once, and all the way up in its time.
        XCTAssertLessThan(heights.first ?? .infinity, (height - Swallowing.mouthSink) * 0.1, "the head jumped up")
        for (a, b) in zip(heights, heights.dropFirst()) { XCTAssertGreaterThanOrEqual(b, a - 1e-12) }
        let up = pose.head(from: ground)
        XCTAssertEqual(up.x, prey.x, accuracy: 1e-9, "the head is not over the bot")
        XCTAssertEqual(up.y, height - Swallowing.mouthSink, accuracy: 1e-9)
        XCTAssertEqual(pose.tip, Swallowing.tipDegrees * .pi / 180, accuracy: 1e-9)
        XCTAssertLessThan(pose.tip, .pi / 2, "tipped all the way down, and the eyes are gone")

        // The meal over and the bot gone, the head comes down to where it lies, in its time.
        var down = 0
        while pose.rear > 0 && down < 600 {
            let before = pose.head(from: ground).y
            pose.step(seconds: frame, eatingAlive: nil, height: height)
            XCTAssertLessThanOrEqual(pose.head(from: ground).y, before + 1e-12)
            down += 1
        }
        XCTAssertEqual(Double(down) * frame, Swallowing.rearSeconds, accuracy: frame * 1.5)
        XCTAssertEqual(pose.head(from: ground), ground)
        XCTAssertNil(pose.over)
    }

    @MainActor
    func testTheEyesLookOutOverTheBotAndNotBackAlongTheBody() throws {
        // The worst case found on the phone: the head last moved towards where its neck
        // will be, so tipping it forward the way it faced put its eyes on its back.
        let shipped = try Launch.world().get()
        let tuning = shipped.configurations.tuning
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n..........\n..........\n..........\n",
                                      kit: shipped.kit)
        let floor = Surfaces(graph: NavigationGraph.derive(from: map, stepHeight: tuning.stepHeight),
                             kit: shipped.kit, tuning: tuning, map: map)
        var snake = Snake(head: SIMD3(3.0, 0, 0.5), floor: 0, segments: 4, segmentSpacing: tuning.bodyRadius * 2)
        snake.advance(direction: SIMD2(-1, 0), speed: 3, seconds: 0.3, over: floor)
        let prey = snake.head + SIMD3(0.6, 0, 0)

        var pose = SwallowPose()
        for _ in 0..<30 { pose.step(seconds: frame, eatingAlive: prey, height: height) }
        let entity = SnakeEntity.make(radius: tuning.bodyRadius, segments: snake.tail.count)
        SnakeEntity.update(entity, from: snake, radius: tuning.bodyRadius, swallow: pose)
        let head = try XCTUnwrap(entity.children.first { $0.name == EntityName.head })
        let eyes = head.children.filter { $0.name == EntityName.leftEye || $0.name == EntityName.rightEye }
        XCTAssertFalse(eyes.isEmpty)
        // The head seen is the body's end, round its line lifted by its radius.
        let lift = tuning.bodyRadius * SnakeShape.headShare
        let centre = SIMD3<Float>(pose.head(from: snake.head) + SIMD3(0, lift, 0))
        for eye in eyes {
            let at = eye.position(relativeTo: nil)
            // On the head, as far out from its centre as on a snake lying still, and not
            // off in the air beside it.
            XCTAssertEqual(Double(simd_distance(at, centre)), lift * SnakeEyes.out, accuracy: 1e-3,
                           "the eyes came away from the head")
            // Towards the bot, away from the neck, which runs down to the snake's head in
            // the match on the other side.
            XCTAssertGreaterThan(at.x, centre.x, "the eyes slid onto the snake's back")
        }
    }

    @MainActor
    func testTheEyesSitOnTheHeadOfASnakeLyingStill() throws {
        // The same measure, with nothing reared: what the one above compares against.
        let tuning = try Launch.world().get().configurations.tuning
        let snake = Snake(head: SIMD3(1.0, 0, 1.0), floor: 0, segments: 4, segmentSpacing: tuning.bodyRadius * 2)
        let entity = SnakeEntity.make(radius: tuning.bodyRadius, segments: snake.tail.count)
        SnakeEntity.update(entity, from: snake, radius: tuning.bodyRadius)
        let head = try XCTUnwrap(entity.children.first { $0.name == EntityName.head })
        let lift = tuning.bodyRadius * SnakeShape.headShare
        let centre = SIMD3<Float>(snake.head + SIMD3(0, lift, 0))
        XCTAssertEqual(Double(simd_distance(head.position(relativeTo: nil), SIMD3<Float>(snake.head))), 0, accuracy: 1e-5,
                       "lying still, the head is not where the match has it")
        for eye in head.children where eye.name == EntityName.leftEye || eye.name == EntityName.rightEye {
            XCTAssertEqual(Double(simd_distance(eye.position(relativeTo: nil), centre)), lift * SnakeEyes.out,
                           accuracy: 1e-3)
        }
    }

    @MainActor
    func testTheBotIsCutAtTheMouthNotSquashedAndDrawnWholeAgainAfter() throws {
        let world = try Launch.world().get()
        let bots = Squads.spawn(in: world, snakeStart: try XCTUnwrap(Game.firstStart(in: world)))
        let prey = try XCTUnwrap(bots.first)
        let figures = BotEntity.make(for: bots, height: height)
        let body = try XCTUnwrap(figures.children.first { $0.name == EntityName.numbered(EntityName.bot, prey.id) })
        func parts(_ entity: Entity) -> [ModelEntity] {
            entity.children.flatMap { child in ((child as? ModelEntity).map { [$0] } ?? []) + parts(child) }
        }
        let before = parts(body).flatMap { $0.model?.materials ?? [] }
        XCTAssertFalse(before.isEmpty)
        XCTAssertTrue(before.allSatisfy { !($0 is CustomMaterial) }, "cut before any meal")

        // Half gone: as big as it was, where it stood, and cut at half its height.
        BotEntity.slurp(figures, prey: prey.id, feet: prey.position, height: height, left: 0.5)
        for axis in [body.scale.x, body.scale.y, body.scale.z] { XCTAssertEqual(Double(axis), 1, accuracy: 1e-9, "squashed") }
        let cuts = parts(body).flatMap { $0.model?.materials ?? [] }.compactMap { $0 as? CustomMaterial }
        XCTAssertEqual(cuts.count, before.count, "a part of the figure was left whole")
        for cut in cuts {
            XCTAssertEqual(Double(cut.custom.value.x), prey.position.y + height * 0.5, accuracy: 1e-5)
            XCTAssertNotNil(cut.opacityThreshold, "what is cut away would be drawn clear, not thrown out")
        }
        // Further in, the cut comes down with the head.
        BotEntity.slurp(figures, prey: prey.id, feet: prey.position, height: height, left: 0.2)
        let lower = parts(body).flatMap { $0.model?.materials ?? [] }.compactMap { $0 as? CustomMaterial }
        XCTAssertEqual(Double(try XCTUnwrap(lower.first).custom.value.x), prey.position.y + height * 0.2, accuracy: 1e-5)

        // No longer the prey — a new match — it is drawn whole, as it was.
        BotEntity.update(figures, from: bots, eaten: nil)
        let after = parts(body).flatMap { $0.model?.materials ?? [] }
        XCTAssertEqual(after.count, before.count)
        XCTAssertTrue(after.allSatisfy { !($0 is CustomMaterial) }, "still cut in the next match")
    }

    func testTheBotStaysWhereItStandsAndShowsLessUnderTheHeadBootsLast() {
        let feet = SIMD3(2.0, 0, 3.0)
        let whole = SwallowPose.prey(at: feet, height: height, gone: 0)
        XCTAssertEqual(whole.height, 1, accuracy: 1e-12, "cut short before the first bite")
        var showing = whole.height
        for step in 1...10 {
            let pose = SwallowPose.prey(at: feet, height: height, gone: Double(step) / 10)
            XCTAssertEqual(pose.position, feet, "the bot moved; the head is what comes down")
            XCTAssertLessThanOrEqual(pose.height, showing + 1e-12)
            showing = pose.height
        }
        XCTAssertEqual(showing, Swallowing.smallest, accuracy: 1e-12, "the boots vanished before the meal was over")
    }

    func testTheHeadComesDownOverTheBotAsItGoesIn() {
        let ground = SIMD3(1.0, 0, 1.0)
        let prey = SIMD3(1.5, 0, 1.0)
        var pose = SwallowPose()
        for _ in 0..<30 { pose.step(seconds: frame, eatingAlive: prey, height: height, gone: 0) }
        XCTAssertEqual(pose.head(from: ground).y, height - Swallowing.mouthSink, accuracy: 1e-9,
                       "at the first bite the head's mouth is not at the bot's top")
        var last = pose.head(from: ground).y
        for step in 1...10 {
            let gone = Double(step) / 10
            pose.step(seconds: frame, eatingAlive: prey, height: height, gone: gone)
            let head = pose.head(from: ground)
            // Always just over what is still showing of the bot, and lower as it goes.
            let showing = SwallowPose.prey(at: prey, height: height, gone: gone).height
            XCTAssertEqual(head.y, height * showing - Swallowing.mouthSink, accuracy: 1e-9)
            XCTAssertLessThanOrEqual(head.y, last + 1e-12, "the head went up")
            XCTAssertEqual(head.x, prey.x, accuracy: 1e-9)
            last = head.y
        }
        XCTAssertLessThan(last, height * 0.5, "the head did not come down over the bot")
    }
}
