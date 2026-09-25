// The bots as the player sees them: one body each, put where the model has them, a
// colour that says which side it is on (FR-VIEW-060), and — while one is being eaten
// — a body going into the snake rather than blinking out (FR-VIEW-100).
//
// verifies: FR-VIEW-060, FR-VIEW-100
import RealityKit
import XCTest
@testable import CrawlCall

@MainActor
final class BotEntityTests: XCTestCase {
    private func squads() throws -> [Bot] {
        let world = try Launch.world().get()
        return Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world))).bots
    }

    func testEveryBotGetsABodyOfItsOwn() throws {
        let bots = try squads()
        let entity = BotEntity.make(for: bots, height: 1.12)
        XCTAssertEqual(entity.children.count, bots.count)
        XCTAssertEqual(Set(entity.children.map(\.name)), Set(bots.map { "bot\($0.id)" }))
    }

    func testABodyStandsOnTheFloorRatherThanInsideIt() throws {
        let bots = try squads()
        let entity = BotEntity.make(for: bots, height: 1.12)
        for bot in bots {
            let body = try XCTUnwrap(entity.children.first { $0.name == "bot\(bot.id)" })
            XCTAssertEqual(Double(body.position.y), bot.position.y, accuracy: 1e-6)
            // The figure's feet on the floor, and nothing of it below it.
            let bounds = body.visualBounds(relativeTo: nil)
            XCTAssertEqual(Double(bounds.min.y), bot.position.y, accuracy: 0.01,
                           "the \(bot.archetype) figure does not stand on the floor")
        }
    }

    func testTheFiguresAreDrawnAtTheHeightTheSceneIsGiven() throws {
        // The height is the caller's — the bot configuration's in the game — and a
        // figure drawn at a height nobody ships is that height tall.
        // Which archetypes a squad holds is not this test's business, so it compares
        // the same squads drawn at two heights: every figure grows by their ratio.
        let bots = try squads()
        let tall = BotEntity.make(for: bots, height: 2.0)
        let short = BotEntity.make(for: bots, height: 1.0)
        for bot in bots {
            let a = try XCTUnwrap(tall.children.first { $0.name == "bot\(bot.id)" })
            let b = try XCTUnwrap(short.children.first { $0.name == "bot\(bot.id)" })
            let ratio = a.visualBounds(relativeTo: a).max.y / b.visualBounds(relativeTo: b).max.y
            XCTAssertEqual(Double(ratio), 2.0, accuracy: 1e-3, "the \(bot.archetype) did not grow with its height")
        }
    }

    func testEveryPartOfEveryFigureIsLitByTheAmbientLight() throws {
        // What is drawn is the parts, so a light set on the figure's group alone
        // reaches nothing on the screen.
        let bots = try squads()
        let entity = BotEntity.make(for: bots, height: 1.12)
        let ambient = Entity()
        BotEntity.light(entity, by: ambient)
        for figure in entity.children {
            XCTAssertFalse(figure.children.isEmpty, "\(figure.name) has no parts, so this proves nothing")
            for part in figure.children {
                let light = part.components[ImageBasedLightReceiverComponent.self]
                XCTAssertTrue(light?.imageBasedLight === ambient, "a part of \(figure.name) is unlit")
            }
        }
    }

    func testABodyFollowsItsBot() throws {
        var bots = try squads()
        let entity = BotEntity.make(for: bots, height: 1.12)
        let moved = try element(0, of: bots).position + SIMD3(1.5, 0, 2.5)
        bots[try checkedIndex(0, of: bots)].position = moved
        BotEntity.update(entity, from: bots)
        let body = try XCTUnwrap(entity.children.first { $0.name == "bot\(try element(0, of: bots).id)" })
        XCTAssertEqual(Double(body.position.x), moved.x, accuracy: 1e-6)
        XCTAssertEqual(Double(body.position.z), moved.z, accuracy: 1e-6)
    }

    func testABotThatHasBeenEatenLeavesTheScreen() throws {
        // The model drops an eaten bot; a body left standing where it was swallowed
        // would say the opposite of what happened.
        let bots = try squads()
        let entity = BotEntity.make(for: bots, height: 1.12)
        let eaten = try XCTUnwrap(bots.first)
        BotEntity.update(entity, from: bots.filter { $0.id != eaten.id })

        let body = try XCTUnwrap(entity.children.first { $0.name == "bot\(eaten.id)" })
        XCTAssertFalse(body.isEnabled, "the eaten bot is still standing there")
        for other in bots where other.id != eaten.id {
            let standing = try XCTUnwrap(entity.children.first { $0.name == "bot\(other.id)" })
            XCTAssertTrue(standing.isEnabled, "bot \(other.id) went with it")
        }
    }

    func testABotBeingEatenIsDrawnGoingIntoTheSnake() throws {
        let bots = try squads()
        let entity = BotEntity.make(for: bots, height: 1.12)
        let prey = try XCTUnwrap(bots.first)
        let body = try XCTUnwrap(entity.children.first { $0.name == "bot\(prey.id)" })
        let head = prey.position + SIMD3(2, 0, 0)
        let stood = body.position

        // The first bite: barely moved, barely smaller.
        BotEntity.swallow(entity, prey: prey.id, head: head, left: 0.95)
        XCTAssertLessThan(body.scale.x, 1)
        XCTAssertGreaterThan(body.scale.x, 0.8)
        XCTAssertLessThan(abs(body.position.x - stood.x), 0.3)

        // Most of the way in: small, and nearly at the head.
        BotEntity.swallow(entity, prey: prey.id, head: head, left: 0.1)
        XCTAssertLessThan(body.scale.x, 0.3)
        XCTAssertEqual(Double(body.position.x), head.x, accuracy: 0.3)
        XCTAssertGreaterThan(body.scale.x, 0.1, "a body that shrank to nothing reads as a bug")
    }

    func testTheTwoSidesAreNotTheSameColour() {
        // "Readable at a glance" is not a thing a test can judge, but two colours
        // that are nearly the same is a thing it can refuse: a third of the range
        // apart on at least one channel.
        let red = BotEntity.colour(for: .red)
        let blue = BotEntity.colour(for: .blue)
        let apart = (0..<3).map { abs(red[$0] - blue[$0]) }.max() ?? 0
        XCTAssertGreaterThan(apart, 0.33, "the squads are \(red) and \(blue)")
    }
}
