// How a match ends and how the next one starts: the snake shot with nothing left to
// lose (FR-SNAKE-210), the two ends that stop a match (FR-SCORE-140, FR-SCORE-150),
// and the plate that names the end and starts another (FR-VIEW-190).
//
// The two ends are reached through a real match rather than asserted about the type:
// what the requirements promise is that a match stops, and a flag nothing sets would
// satisfy a test that only read it back.
//
// verifies: FR-SNAKE-210, FR-SCORE-140, FR-SCORE-150, FR-VIEW-190, FR-VIEW-320
import RealityKit
import XCTest
@testable import CrawlCall

final class SnakeDeathTests: XCTestCase {
    private func snake(segments: Int) -> Snake {
        Snake(head: SIMD3(0, 0, 0), floor: 0, segments: segments, segmentSpacing: 0.5)
    }

    func testASnakeWithATailSurvivesWhatItCanPayFor() {
        var body = snake(segments: 2)
        XCTAssertEqual(body.take(damage: 10, perSegment: 10), 1)
        XCTAssertTrue(body.isAlive)
        XCTAssertEqual(body.segments, 1)
    }

    func testTheHitThatTakesTheLastSegmentIsNotTheHitThatKills() {
        // FR-SNAKE-210 is about damage taken *while* the tail is empty, and the
        // difference matters: a snake down to its last segment is one bullet from
        // death, not dead, and the requirement's own rationale says the first bullet
        // is never the last.
        var body = snake(segments: 1)
        body.take(damage: 10, perSegment: 10)
        XCTAssertEqual(body.segments, 0)
        XCTAssertTrue(body.isAlive, "the snake died on the hit that emptied its tail")
    }

    func testAHitOnAnEmptyTailKillsTheSnake() {
        var body = snake(segments: 0)
        XCTAssertEqual(body.take(damage: 2, perSegment: 10), 0)
        XCTAssertFalse(body.isAlive)
    }

    func testDamageTooSmallToCostASegmentStillKillsAnEmptyTail() {
        // The banking of FR-SNAKE-070 is what makes small arms add up; at an empty
        // tail there is nothing left to bank against, so a fifth of a segment is as
        // fatal as ten of them.
        var body = snake(segments: 0)
        body.take(damage: 2, perSegment: 10)
        XCTAssertFalse(body.isAlive)
    }

    func testNothingKillsASnakeThatIsNotShotAt() {
        var body = snake(segments: 0)
        body.take(damage: 0, perSegment: 10)
        XCTAssertTrue(body.isAlive, "a shot that dealt nothing killed the snake")
    }
}

final class MatchEndTests: XCTestCase {
    /// The shipped world with one configuration key replaced, taken through the same
    /// decode a bundled file goes through, so a test world is a world and not a
    /// second definition of one.
    private func world(snake key: String? = nil, value: Any = 0,
                       squadSize: Int? = nil) throws -> World {
        let base = try Launch.world(map: "room").get()
        var configurations = base.configurations
        if let key {
            configurations = Configurations(
                snake: try decode(SnakeConfiguration.self, named: "snake",
                                  schema: SnakeConfiguration.schema, replacing: key, with: value),
                tuning: configurations.tuning, view: configurations.view,
                bot: configurations.bot, match: configurations.match, scoring: configurations.scoring)
        }
        if let squadSize {
            configurations = Configurations(
                snake: configurations.snake, tuning: configurations.tuning,
                view: configurations.view, bot: configurations.bot,
                match: try decode(MatchConfiguration.self, named: "match",
                                  schema: MatchConfiguration.schema,
                                  replacing: "squadSize", with: squadSize),
                scoring: configurations.scoring)
        }
        return World(configurations: configurations, kit: base.kit, map: base.map,
                     setting: base.setting, graph: base.graph, plan: base.plan)
    }

    private func decode<T: Decodable>(_ type: T.Type, named name: String, schema: Schema,
                                      replacing key: String, with value: Any) throws -> T {
        let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "json",
                                                subdirectory: "config"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: url))
                                    as? [String: Any])
        json[key] = value
        return try Configurations.decode(type, named: name, schema: schema,
                                         from: JSONSerialization.data(withJSONObject: json))
    }

    /// Walks the snake at the first bot the match put on the ground floor, one frame
    /// at a time, for as long as the caller wants: a snake standing still is a snake
    /// nobody notices and therefore nobody shoots at (FR-BOT-050).
    ///
    /// The first and not the nearest, because which one it is does not matter — what
    /// matters is that the snake walks into somebody's sight rather than waiting in
    /// the corner — and the same map hands out the same bot every time.
    private func walkAtSomebody(_ game: inout Game, frames: Int,
                                until stop: (Game) -> Bool = { _ in false }) throws {
        let cell = game.world.configurations.tuning.navigationGraphCellSize
        let prey = try XCTUnwrap(game.bots.filter { $0.floor == 0 }.first)
        var route = Route.between(game.start,
                                  NavigationGraph.Node(floor: 0,
                                                       x: Int((prey.position.x / cell).rounded()),
                                                       z: Int((prey.position.z / cell).rounded())),
                                  in: game.world.graph)
        for _ in 0..<frames {
            if stop(game) { return }
            if let next = route.first {
                let there = SIMD3(Double(next.x) * cell, 0, Double(next.z) * cell)
                let toward = SIMD2(there.x - game.snake.head.x, there.z - game.snake.head.z)
                let length = (toward.x * toward.x + toward.y * toward.y).squareRoot()
                if length < 0.1 { route.removeFirst() }
                game.apply(.move(direction: length > 0 ? SIMD2(toward.x / length, toward.y / length) : .zero))
            }
            game.advance(seconds: 1.0 / 60)
        }
    }

    func testTheMatchEndsWhenTheSnakeIsShotToPieces() throws {
        // A snake that starts with no tail is one bullet from death, which is the
        // state FR-SNAKE-210 describes; the shot that kills it comes out of a real
        // match, from a bot that noticed it and chose to fire.
        let world = try world(snake: "startingSegmentCount", value: 0)
        var game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        XCTAssertNil(game.outcome, "the match was over before it began")
        try walkAtSomebody(&game, frames: 1800) { $0.outcome != nil }
        XCTAssertEqual(game.outcome, .snakeDied, "nobody ever finished off a tailless snake")
        XCTAssertFalse(game.snake.isAlive)
    }

    func testAMatchThatIsOverStopsWhereItStopped() throws {
        // FR-SCORE-140 ends the match, and an ended match that kept running would be
        // a screen where a dead snake is still being shot at.
        let world = try world(snake: "startingSegmentCount", value: 0)
        var game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        try walkAtSomebody(&game, frames: 1800) { $0.outcome != nil }
        // Asserted rather than skipped over: with the end removed from the code this
        // test reported itself skipped instead of failing, which is a broken feature
        // passing quietly.
        XCTAssertEqual(game.outcome, .snakeDied, "the snake was never finished off")

        let head = game.snake.head
        let bots = game.bots.map(\.position)
        game.apply(.move(direction: SIMD2(1, 0)))
        for _ in 0..<120 { game.advance(seconds: 1.0 / 60) }
        XCTAssertEqual(game.snake.head.x, head.x, accuracy: 1e-12)
        XCTAssertEqual(game.snake.head.z, head.z, accuracy: 1e-12)
        for (moved, was) in zip(game.bots.map(\.position), bots) {
            XCTAssertEqual(Perception.metres(moved, was), 0, accuracy: 1e-12,
                           "a bot walked on after the match ended")
        }
    }

    func testTheMatchEndsWhenNothingIsLeftAlive() throws {
        // FR-SCORE-150 from the other side of the condition: an arena with nobody in
        // it is over on the first frame, whatever the snake does.
        let world = try world(squadSize: 0)
        var game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        XCTAssertTrue(game.bots.isEmpty)
        game.advance(seconds: 1.0 / 60)
        XCTAssertEqual(game.outcome, .arenaEmpty)
    }

    func testAMatchWithPreyInItIsNotOver() throws {
        // The negation: as long as somebody is alive, the end of FR-SCORE-150 must
        // not fire — a condition written the wrong way round would end every match
        // at the whistle, and the test above would still pass.
        let world = try Launch.world(map: "room").get()
        var game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        try walkAtSomebody(&game, frames: 900)
        XCTAssertTrue(game.bots.contains { $0.health > 0 }, "the test ate the arena empty")
        XCTAssertNotEqual(game.outcome, .arenaEmpty)
    }

    func testEachEndIsNamedOnThePlate() {
        // FR-VIEW-190 asks which of the two ends it was, so the two must not read
        // the same.
        let shot = MatchEnd.headline(for: .snakeDied).text()
        let empty = MatchEnd.headline(for: .arenaEmpty).text()
        XCTAssertFalse(shot.isEmpty)
        XCTAssertFalse(empty.isEmpty)
        XCTAssertNotEqual(shot, empty, "both ends of a match say the same thing")
    }

    func testStartingAgainGivesAWholeMatchInTheSameArena() throws {
        let world = try Launch.world(map: "room").get()
        var game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        let began = game.snake.head
        try walkAtSomebody(&game, frames: 600)
        XCTAssertGreaterThan(Perception.metres(game.snake.head, began), 1,
                             "the snake never moved, so starting again proves nothing")

        let next = game.restarted()
        XCTAssertNil(next.outcome)
        XCTAssertEqual(next.snake.segments, world.configurations.snake.startingSegmentCount)
        XCTAssertTrue(next.snake.isAlive)
        XCTAssertEqual(next.bots.count, game.world.configurations.match.squadSize * 2)
        XCTAssertEqual(next.shots.count, 0)
        XCTAssertNil(next.eating)
        XCTAssertEqual(next.start, game.start, "the new match is somewhere else")
        XCTAssertEqual(Perception.metres(next.snake.head, began), 0, accuracy: 1e-12,
                       "the new match began somewhere other than where the first one did")
    }
}

@MainActor
final class RestartOnScreenTests: XCTestCase {
    func testStartingAgainPutsTheEatenBotsBackOnScreen() throws {
        // The scene is kept across a restart rather than built again, so what this
        // asks is whether the bodies that were taken off screen come back: a bot the
        // snake ate has to be standing in the arena again when the next match starts
        // (FR-VIEW-190).
        let world = try Launch.world(map: "room").get()
        let game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        let built = SceneBuilder.scene(for: world.plan, view: world.configurations.view)
        let camera = try XCTUnwrap(built.root.children.first { $0.name == "camera" })
        let squads = BotEntity.make(for: game.bots, height: world.configurations.bot.figureHeight)
        let session = GameSession(game: game,
                                  snakeEntity: SnakeEntity.make(radius: world.configurations.tuning.bodyRadius,
                                                                segments: game.snake.segments),
                                  botEntities: squads,
                                  shotEntities: ShotEntity.make(for: game.bots),
                                  camera: camera, seeThrough: built.seeThrough,
                                  distance: 12, fieldOfView: 50)

        let cell = world.configurations.tuning.navigationGraphCellSize
        let prey = try XCTUnwrap(game.bots.filter { $0.floor == 0 }.first)
        var route = Route.between(game.start,
                                  NavigationGraph.Node(floor: 0,
                                                       x: Int((prey.position.x / cell).rounded()),
                                                       z: Int((prey.position.z / cell).rounded())),
                                  in: world.graph)
        for _ in 0..<1800 where session.game.bots.count == game.bots.count {
            if let next = route.first {
                let there = SIMD3(Double(next.x) * cell, 0, Double(next.z) * cell)
                let head = session.game.snake.head
                let toward = SIMD2(there.x - head.x, there.z - head.z)
                let length = (toward.x * toward.x + toward.y * toward.y).squareRoot()
                if length < 0.1 { route.removeFirst() }
                session.apply(.move(direction: length > 0 ? SIMD2(toward.x / length, toward.y / length) : .zero))
            }
            if session.canEat { session.apply(.eat) }
            session.step(seconds: 1.0 / 60)
        }
        XCTAssertLessThan(session.game.bots.count, game.bots.count,
                          "the snake never ate anybody, so the restart proves nothing")
        XCTAssertLessThan(squads.children.filter(\.isEnabled).count, game.bots.count)

        // The one that was eaten, and what the meal left of it on screen: swallowing
        // shrinks the body towards the head (FR-VIEW-100), so this is the body a new
        // match has to undo as well as re-enable.
        let eaten = try XCTUnwrap(game.bots.map(\.id).first { id in
            !session.game.bots.contains { $0.id == id }
        })
        let body = try XCTUnwrap(squads.children.first { $0.name == "bot\(eaten)" })
        // Smaller, or cut at the mouth: a body shrinks whole, a living bot is cut away
        // under the head coming down over it (FR-VIEW-320).
        func cut(_ entity: Entity) -> Bool {
            entity.components.has(BotEntity.UncutMaterials.self) || entity.children.contains(where: cut)
        }
        XCTAssertTrue(body.scale.min() < 1 || cut(body), "the bot was never drawn going into the snake")

        session.restart()
        XCTAssertNil(session.game.outcome)
        XCTAssertEqual(session.game.bots.count, world.configurations.match.squadSize * 2)
        XCTAssertEqual(squads.children.filter(\.isEnabled).count, game.bots.count,
                       "a bot eaten in the last match is still off screen in this one")
        // Found in play on 2026-09-23: it came back the size the last bite left it.
        for axis in [body.scale.x, body.scale.y, body.scale.z] {
            XCTAssertEqual(Double(axis), 1, accuracy: 1e-6,
                           "a bot eaten in the last match is still the size it was swallowed at")
        }
        XCTAssertFalse(cut(body), "a bot eaten in the last match is still cut at the snake's mouth")
        // And where the new match has it, not where the snake's mouth had pulled it.
        let again = try XCTUnwrap(session.game.bots.first { $0.id == eaten })
        XCTAssertEqual(Double(body.position.x), again.position.x, accuracy: 1e-5,
                       "it came back standing where the snake's mouth had pulled it")
        XCTAssertEqual(Double(body.position.z), again.position.z, accuracy: 1e-5,
                       "it came back standing where the snake's mouth had pulled it")
        XCTAssertEqual(Double(body.position.y), again.position.y, accuracy: 1e-6)
    }
}
