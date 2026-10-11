// A walking bot steps (FR-VIEW-290): the walk comes on as the bot moves and dies away
// as it stops, beats with the ground covered and not with the clock, and poses the
// figure — lifted, rocking, legs swinging against each other — on screen.
//
// file verifies: FR-VIEW-290
import RealityKit
import XCTest
@testable import CrawlCall

final class GaitTests: XCTestCase {
    private let frame = 1.0 / 60

    func testTheWalkComesOnAsTheBotMovesAndDiesAwayAsItStops() {
        var gait = Gait()
        for _ in 0..<60 { gait.step(moved: 4.5 * frame, seconds: frame) }
        XCTAssertGreaterThan(gait.amount, 0.99, "a bot running for a second is not walking")
        for _ in 0..<60 { gait.step(moved: 0, seconds: frame) }
        XCTAssertLessThan(gait.amount, 0.01, "a bot standing for a second is still walking")
        let pose = gait.pose
        XCTAssertEqual(pose.lift, 0, accuracy: 0.001)
        XCTAssertEqual(pose.swing, 0, accuracy: 0.01)
    }

    func testTheBeatIsTheGroundCoveredNotTheClock() {
        // The same metres make the same stride whether covered fast or slow; time
        // standing still makes none.
        var fast = Gait(), slow = Gait()
        for _ in 0..<10 { fast.step(moved: 0.1, seconds: frame) }
        for _ in 0..<40 { slow.step(moved: 0.025, seconds: frame) }
        XCTAssertEqual(fast.phase, slow.phase, accuracy: 1e-9)
        XCTAssertEqual(fast.phase, 1.0 / BotGait.stride * 2 * .pi, accuracy: 1e-9)
        var standing = fast
        for _ in 0..<30 { standing.step(moved: 0, seconds: frame) }
        XCTAssertEqual(standing.phase, fast.phase, accuracy: 1e-12, "the stride went on while the bot stood")
    }

    @MainActor
    func testTheFigureStepsOnScreen() throws {
        let world = try Launch.world().get()
        let height = world.configurations.bot.figureHeight
        let bot = try XCTUnwrap(Bot(id: 0, squad: .red, archetype: .assault, at: .zero, floor: 0,
                                    configuration: world.configurations.bot))
        let entity = BotEntity.make(for: [bot], height: height)
        let figure = try XCTUnwrap(entity.children.first)
        let left = try XCTUnwrap(figure.children.first { $0.name == "leftHip" })
        let right = try XCTUnwrap(figure.children.first { $0.name == "rightHip" })
        XCTAssertTrue(left.children.contains { $0.name == "leftLeg" }, "the left leg does not hang from its hip")
        XCTAssertTrue(right.children.contains { $0.name == "rightLeg" })

        // A quarter of a stride into a full walk: lifted, and the legs swung apart.
        var gait = Gait()
        for _ in 0..<60 { gait.step(moved: BotGait.stride / 4 / 60, seconds: frame) }
        BotEntity.update(entity, from: [bot], gaits: [bot.id: gait])
        XCTAssertGreaterThan(figure.position.y, 0.01, "the figure is not lifted at the step")
        let leftFoot = left.orientation.act(SIMD3<Float>(0, -1, 0))
        let rightFoot = right.orientation.act(SIMD3<Float>(0, -1, 0))
        XCTAssertLessThan(leftFoot.z * rightFoot.z, 0, "the legs do not swing against each other")

        // Standing: straight legs, on the ground.
        BotEntity.update(entity, from: [bot])
        XCTAssertEqual(figure.position.y, 0, accuracy: 1e-6)
        XCTAssertEqual(left.orientation.act(SIMD3<Float>(0, -1, 0)).z, 0, accuracy: 1e-6)
    }

    @MainActor
    func testEveryPartOfTheFigureIsLitLegsIncluded() throws {
        let world = try Launch.world().get()
        let bot = try XCTUnwrap(Bot(id: 0, squad: .red, archetype: .assault, at: .zero, floor: 0,
                                    configuration: world.configurations.bot))
        let entity = BotEntity.make(for: [bot], height: world.configurations.bot.figureHeight)
        BotEntity.light(entity, by: Entity())
        func models(_ e: Entity) -> [ModelEntity] { ((e as? ModelEntity).map { [$0] } ?? []) + e.children.flatMap(models) }
        let parts = models(entity)
        XCTAssertTrue(parts.contains { $0.name == "leftLeg" })
        XCTAssertTrue(parts.allSatisfy { $0.components.has(ImageBasedLightReceiverComponent.self) }, "a part is left unlit")
    }
}
