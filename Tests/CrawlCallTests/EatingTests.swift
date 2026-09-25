// Eating: the time it takes (FR-SNAKE-090), that live prey takes longer than a body
// (FR-SNAKE-100), and the tail it leaves behind (FR-SNAKE-060).
//
// verifies: FR-SNAKE-060, FR-SNAKE-090, FR-SNAKE-100, FR-SNAKE-220
import XCTest
@testable import CrawlCall

final class EatingTests: XCTestCase {
    private func world() throws -> World { try Launch.world().get() }
    private func match(_ world: World) throws -> Game {
        Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
    }

    func testEveryArchetypeIsWorthSomethingToEat() throws {
        // FR-SNAKE-060 grows the tail "for that bot's archetype", so an archetype the
        // configuration does not price is a bot that can be eaten for nothing.
        let snake = try world().configurations.snake
        for kind in Archetype.allCases {
            let segments = snake.segmentsPerArchetype[kind.rawValue]
            XCTAssertNotNil(segments, "\(kind.rawValue) is not priced")
            XCTAssertGreaterThan(segments ?? 0, 0)
        }
    }

    func testABodyIsEatenOnTheClockAndLivePreyIsChewedThrough() throws {
        // The two cases are the same act and differ in what ends it (FR-SNAKE-100):
        // a body has no health and runs out of time, live prey runs out of health.
        let snake = try world().configurations.snake
        var body = Eating(prey: 0, alive: false, archetype: .assault, configuration: snake)
        XCTAssertEqual(body.left, snake.bodyEatingDuration)
        XCTAssertEqual(body.advance(seconds: 0.1), 0, "a body was bitten")
        XCTAssertFalse(body.isFinished)

        var alive = Eating(prey: 0, alive: true, archetype: .assault, configuration: snake)
        XCTAssertNil(alive.left, "live prey was put on a clock")
        XCTAssertEqual(alive.advance(seconds: 0.1), snake.eatingDamagePerSecond * 0.1, accuracy: 1e-9)
        XCTAssertFalse(alive.isFinished, "live prey ends by running out of health, not here")
    }

    func testAFatterBotIsALongerMeal() throws {
        // The heavy is the fattest target the concept §8 calls it, and that falls out
        // of the one rate rather than a number of its own.
        let world = try world()
        let snake = world.configurations.snake
        func seconds(_ kind: Archetype) throws -> Double {
            let health = try XCTUnwrap(world.configurations.bot.archetypes[kind.rawValue]).health
            return health / snake.eatingDamagePerSecond
        }
        XCTAssertGreaterThan(try seconds(.heavy), try seconds(.assault))
    }

    func testAMealIsOverWhenItsTimeIsSpentAndNotBefore() throws {
        let snake = try world().configurations.snake
        var meal = Eating(prey: 3, alive: false, archetype: .heavy, configuration: snake)
        // The duration is a whole number of frames here — 1.2 s is 72 of them — so
        // the last one is what finishes it and every one before it does not.
        let frames = Int((snake.bodyEatingDuration * 60).rounded())
        for frame in 0..<(frames - 1) {
            _ = meal.advance(seconds: 1.0 / 60)
            XCTAssertFalse(meal.isFinished, "the meal ended early, on frame \(frame)")
        }
        _ = meal.advance(seconds: 1.0 / 60)
        XCTAssertTrue(meal.isFinished, "the meal did not end on its last frame")
        XCTAssertEqual(try XCTUnwrap(meal.left), 0, accuracy: 1e-12)
    }

    func testTheHeadStaysWhereItIsWhileEating() throws {
        let world = try world()
        var game = try match(world)
        let prey = try XCTUnwrap(game.bots.first)
        game.apply(.move(direction: SIMD2(1, 0)))
        game.begin(eating: prey.id)
        let stood = game.snake.head

        for _ in 0..<30 { game.advance(seconds: 1.0 / 60) }
        XCTAssertEqual(game.snake.head, stood, "the head moved during a meal")
        XCTAssertNotNil(game.eating)

        // And it moves again once the meal is over, on the direction still held.
        for _ in 0..<180 { game.advance(seconds: 1.0 / 60) }
        XCTAssertNil(game.eating)
        XCTAssertGreaterThan(game.snake.head.x, stood.x)
    }

    func testNoMealIsBegunInTheAirOffALedge() throws {
        // A meal holds the head where it is (FR-SNAKE-090); begun mid-drop it would
        // hold it in the air, so none is (FR-SNAKE-220). Off the balcony's west edge,
        // beside the top of the flight, into the room below.
        let world = try world()
        let edge = NavigationGraph.Node(floor: 1, x: 20, z: 17)
        XCTAssertTrue(world.graph.isWalkable(edge), "the balcony's west edge moved, so the test proves nothing")
        var game = Game(world: world, start: edge)
        let prey = try XCTUnwrap(game.bots.first)
        game.apply(.move(direction: SIMD2(-1, 0)))
        var frames = 0
        while game.snake.drop == nil && frames < 120 {
            game.advance(seconds: 1.0 / 60)
            frames += 1
        }
        XCTAssertNotNil(game.snake.drop, "the head did not go off the balcony")
        game.begin(eating: prey.id)
        XCTAssertNil(game.eating, "a meal was begun in the air")
        for _ in 0..<120 where game.snake.drop != nil { game.advance(seconds: 1.0 / 60) }
        XCTAssertNil(game.snake.drop)
        game.begin(eating: prey.id)
        XCTAssertNotNil(game.eating, "no meal begins on the ground either, so the test proves nothing")
    }

    func testFinishingAMealTakesTheBotAndLengthensTheTail() throws {
        let world = try world()
        var game = try match(world)
        let prey = try XCTUnwrap(game.bots.first)
        let worth = try XCTUnwrap(world.configurations.snake.segmentsPerArchetype[prey.archetype.rawValue])
        let before = game.snake.segments
        let squads = game.bots.count

        game.begin(eating: prey.id)
        let health = try XCTUnwrap(world.configurations.bot.archetypes[prey.archetype.rawValue]).health
        let frames = Int((health / world.configurations.snake.eatingDamagePerSecond * 60).rounded(.up)) + 2
        for _ in 0..<frames { game.advance(seconds: 1.0 / 60) }
        XCTAssertNil(game.eating)
        XCTAssertEqual(game.snake.segments, before + worth)
        XCTAssertEqual(game.bots.count, squads - 1, "the eaten bot is still on the map")
        XCTAssertFalse(game.bots.contains { $0.id == prey.id })
    }

    func testOnlyOneMealAtATime() throws {
        let world = try world()
        var game = try match(world)
        let first = try XCTUnwrap(game.bots.first)
        let second = try XCTUnwrap(game.bots.last)
        XCTAssertNotEqual(first.id, second.id)
        game.begin(eating: first.id)
        game.begin(eating: second.id)
        XCTAssertEqual(game.eating?.prey, first.id, "the second bite replaced the first")
    }

    func testTheEatIntentTakesTheNearestBotTheHeadHasReached() throws {
        let world = try world()
        let tuning = world.configurations.tuning
        let reach = tuning.bodyRadius + tuning.navigationGraphCellSize / 2
        let head = SIMD3<Double>(5, 0, 5)
        func bot(_ id: Int, at offset: Double) throws -> Bot {
            try XCTUnwrap(Bot(id: id, squad: .red, archetype: .assault,
                              at: head + SIMD3(offset, 0, 0), floor: 0,
                              configuration: world.configurations.bot))
        }
        let touching = try bot(1, at: reach * 0.4)
        let atArmsLength = try bot(2, at: reach * 0.9)
        let beyond = try bot(3, at: reach * 1.5)

        XCTAssertEqual(Game.preyWithinReach(of: head, among: [beyond, atArmsLength, touching],
                                            tuning: tuning), touching.id,
                       "the nearest of those in reach is what the head takes")
        XCTAssertEqual(Game.preyWithinReach(of: head, among: [beyond, atArmsLength], tuning: tuning),
                       atArmsLength.id)
        XCTAssertNil(Game.preyWithinReach(of: head, among: [beyond], tuning: tuning),
                     "a bot beyond reach was eaten from a distance")
        XCTAssertNil(Game.preyWithinReach(of: head, among: [], tuning: tuning))
    }

    func testTheEatIntentWithNothingInReachStartsNothing() throws {
        // Where a match begins there is nobody to eat: the squads spawn away from the
        // snake, so the intent is a no-op rather than a meal out of thin air.
        var game = try match(try world())
        game.apply(.eat)
        XCTAssertNil(game.eating)
    }

    func testAMealHoldsThePreyWhereItIs() throws {
        let world = try world()
        var game = try match(world)
        let prey = try XCTUnwrap(game.bots.first)
        let stood = prey.position
        game.begin(eating: prey.id)
        for _ in 0..<30 { game.advance(seconds: 1.0 / 60) }
        let held = try XCTUnwrap(game.bots.first { $0.id == prey.id })
        XCTAssertEqual(held.position, stood, "the prey walked out of the snake's mouth")
        XCTAssertLessThan(held.health, try XCTUnwrap(world.configurations.bot.archetypes[prey.archetype.rawValue]).health)
    }

    func testABotThatIsNotThereCannotBeEaten() throws {
        let world = try world()
        var game = try match(world)
        game.begin(eating: 999)
        XCTAssertNil(game.eating)
    }

    func testTheMatchKeepsRunningWhileTheSnakeEats() throws {
        // The exposure FR-SNAKE-090 counts on is that everything else goes on around
        // a stationary snake. What a test can see of it here is that the frame is
        // still being advanced — the meal's own clock is the one thing that moves.
        let world = try world()
        var game = try match(world)
        let prey = try XCTUnwrap(game.bots.first)
        game.begin(eating: prey.id)
        let before = try XCTUnwrap(game.bots.first { $0.id == prey.id }).health
        game.advance(seconds: 1.0 / 60)
        let after = try XCTUnwrap(game.bots.first { $0.id == prey.id }).health
        XCTAssertEqual(before - after, world.configurations.snake.eatingDamagePerSecond / 60, accuracy: 1e-9)
    }
}
