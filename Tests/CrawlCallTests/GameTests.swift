// The logic's edge: intents in, a snake moving, and nothing about touches anywhere
// near it (FR-VIEW-030).
//
// file verifies: FR-VIEW-030, FR-SNAKE-030
import RealityKit
import XCTest
@testable import CrawlCall

final class GameTests: XCTestCase {
    private func game() throws -> Game {
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        return Game(world: world, start: start)
    }

    func testAMatchStartsOnAWalkableCellOfTheLowestFloor() throws {
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        XCTAssertEqual(start.floor, 0)
        XCTAssertTrue(world.graph.isWalkable(start))
    }

    func testTheSnakeStartsWithTheSegmentsTheConfigurationSets() throws {
        let g = try game()
        XCTAssertEqual(g.snake.segments, g.world.configurations.snake.startingSegmentCount)
        XCTAssertEqual(g.snake.segmentSpacing,
                       g.world.configurations.tuning.bodyRadius * 2, accuracy: 1e-12)
    }

    func testNothingMovesUntilAnIntentSaysSo() throws {
        var g = try game()
        let before = g.snake.head
        g.advance(seconds: 0.1)
        XCTAssertEqual(g.snake.head.x, before.x, accuracy: 1e-12)
        XCTAssertEqual(g.snake.head.z, before.z, accuracy: 1e-12)
    }

    func testAMoveIntentIsHeldUntilAnotherReplacesIt() throws {
        var g = try game()
        let start = g.snake.head
        g.apply(.move(direction: SIMD2(1, 0)))
        g.advance(seconds: 0.1)
        g.advance(seconds: 0.1)
        // Held: two frames of movement from one intent.
        let speed = g.world.configurations.snake.baseSpeed
        XCTAssertEqual(g.snake.head.x - start.x, speed * 0.2, accuracy: 1e-9)

        g.apply(.move(direction: SIMD2(0, 0)))
        let stopped = g.snake.head
        g.advance(seconds: 0.1)
        XCTAssertEqual(g.snake.head.x, stopped.x, accuracy: 1e-12)
    }

    func testPauseStopsTheWorldAndReleasingItResumes() throws {
        var g = try game()
        g.apply(.move(direction: SIMD2(1, 0)))
        g.apply(.pause)
        let paused = g.snake.head
        g.advance(seconds: 0.5)
        XCTAssertEqual(g.snake.head.x, paused.x, accuracy: 1e-12)
        g.apply(.pause)
        g.advance(seconds: 0.1)
        XCTAssertGreaterThan(g.snake.head.x, paused.x)
    }

    func testTheSpeedIsTheConfigurationsAndNotAConstant() throws {
        var g = try game()
        let start = g.snake.head
        g.apply(.move(direction: SIMD2(1, 0)))
        g.advance(seconds: 1.0 / 60)
        let moved = g.snake.head.x - start.x
        XCTAssertEqual(moved, g.world.configurations.snake.baseSpeed / 60, accuracy: 1e-9)
    }

    func testIntentsTheMatchDoesNotUseYetAreAcceptedWithoutEffect() throws {
        // IF-VIEW-010 delivers four; the match consumes two of them today, and saying
        // so beats a crash or a silent drop.
        var g = try game()
        g.apply(.move(direction: SIMD2(1, 0)))
        let before = g.snake.head
        g.apply(.useAbility(segment: 0))
        g.apply(.point(at: SIMD2(5, 5)))
        g.advance(seconds: 0.1)
        XCTAssertGreaterThan(g.snake.head.x, before.x)   // still moving, nothing broke
        XCTAssertFalse(g.isPaused)
    }
}

/// The snake on screen: one body through the head and every point of the tail, where
/// the model says they are, however many the snake has eaten its way to (FR-VIEW-250).
///
/// verifies: FR-SNAKE-010, FR-SNAKE-020, FR-VIEW-250, FR-VIEW-260, FR-VIEW-270
@MainActor
final class SnakeEntityTests: XCTestCase {
    private func drawn(_ entity: Entity) throws -> Int {
        let body = try XCTUnwrap(entity.children.first { $0.name == "body" } as? ModelEntity, "no body")
        let mesh = try XCTUnwrap(body.model?.mesh.lowLevelMesh, "the body is not rebuilt in place")
        return mesh.parts.first?.indexCount ?? 0
    }

    func testTheHeadHasTwoEyesWithPupilsUnderTheirCeiling() throws {
        // FR-VIEW-260: two eyes, each with a pupil, of a sphere of the game's own, and
        // no more than 1024 triangles in all.
        let entity = SnakeEntity.make(radius: 0.3, segments: 4)
        let head = try XCTUnwrap(entity.children.first { $0.name == "head" })
        let eyes = head.children.compactMap { $0 as? ModelEntity }
        XCTAssertEqual(Set(eyes.map(\.name)), ["leftEye", "rightEye"])
        var triangles = 0
        for eye in eyes {
            let pupil = try XCTUnwrap(eye.children.first { $0.name == "pupil" } as? ModelEntity)
            for part in [eye, pupil] {
                let mesh = try XCTUnwrap(part.model?.mesh)
                triangles += mesh.contents.models.reduce(0) { sum, model in
                    model.parts.reduce(sum) { $0 + ($1.triangleIndices?.count ?? 0) / 3 }
                }
            }
        }
        XCTAssertEqual(triangles, 4 * LowPolySphere.triangles(rings: SnakeEyes.rings, segments: SnakeEyes.segments))
        XCTAssertLessThanOrEqual(triangles, 1024)
    }

    func testTheEyesSitOnTopOfTheHeadAndLookWhereItGoes() throws {
        let world = try Launch.world().get()
        let radius = world.configurations.tuning.bodyRadius
        let row = String(repeating: ".", count: 30)
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n"
                                      + Array(repeating: row, count: 30).joined(separator: "\n") + "\n",
                                      kit: world.kit)
        let surfaces = Surfaces(graph: NavigationGraph.derive(from: map, stepHeight: world.configurations.tuning.stepHeight),
                                kit: world.kit, tuning: world.configurations.tuning, map: map)
        var snake = Snake(head: SIMD3(7, 0, 7), floor: 0, segments: 4, segmentSpacing: radius * 2)
        let entity = SnakeEntity.make(radius: radius, segments: snake.segments)
        let head = try XCTUnwrap(entity.children.first { $0.name == "head" })
        for (way, frames) in [(SIMD2(1.0, 0), 90), (SIMD2(0, -1.0), 90)] {
            for _ in 0..<frames {
                snake.advance(direction: way, speed: 3, seconds: 1.0 / 60, over: surfaces)
            }
            SnakeEntity.update(entity, from: snake, radius: radius)
            let centre = SIMD3<Float>(snake.head) + SIMD3(0, Float(radius * SnakeShape.headShare), 0)
            let forward = SIMD3<Float>(Float(way.x), 0, Float(way.y))
            var sides: [Float] = []
            for name in ["leftEye", "rightEye"] {
                let eye = try XCTUnwrap(head.children.first { $0.name == name })
                let pupil = try XCTUnwrap(eye.children.first { $0.name == "pupil" })
                let at = eye.position(relativeTo: nil), look = pupil.position(relativeTo: nil)
                XCTAssertGreaterThan(simd_dot(at - centre, forward), 0, "\(name) is behind the head going \(way)")
                XCTAssertGreaterThan(at.y, centre.y, "\(name) is not on top of the head")
                XCTAssertGreaterThan(simd_dot(look - at, forward), 0, "\(name)'s pupil does not look the way it goes")
                sides.append(simd_dot(at - centre, simd_cross(SIMD3(0, 1, 0), forward)))
            }
            let left = try element(0, of: sides), right = try element(1, of: sides)
            XCTAssertEqual(left, -right, accuracy: 1e-4, "the eyes are not either side of the head")
            XCTAssertNotEqual(left, 0, accuracy: 1e-3)
        }
    }

    func testTheBodyWearsTheSpottedSkin() throws {
        // FR-VIEW-270: the skin shader, with the spots' colour and the body's radius.
        let entity = SnakeEntity.make(radius: 0.3, segments: 4)
        let body = try XCTUnwrap(entity.children.first { $0.name == "body" } as? ModelEntity)
        let skin = try XCTUnwrap(body.model?.materials.first as? CustomMaterial, "the body is plain")
        XCTAssertEqual(Double(skin.custom.value.x), SnakeSkin.spots.x, accuracy: 1e-6)
        XCTAssertEqual(Double(skin.custom.value.y), SnakeSkin.spots.y, accuracy: 1e-6)
        XCTAssertEqual(Double(skin.custom.value.z), SnakeSkin.spots.z, accuracy: 1e-6)
        XCTAssertEqual(Double(skin.custom.value.w), 0.3, accuracy: 1e-6)
        XCTAssertEqual(skin.roughness.scale, SnakeSkin.roughness, accuracy: 1e-6)
    }

    func testThereIsAHeadAndOneBody() throws {
        let entity = SnakeEntity.make(radius: 0.3, segments: 4)
        XCTAssertEqual(entity.children.filter { $0.name == "head" }.count, 1)
        XCTAssertEqual(entity.children.filter { $0.name == "body" }.count, 1)
    }

    func testTheBodyIsLaidWhereTheModelSays() throws {
        let world = try Launch.world().get()
        var game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        let radius = world.configurations.tuning.bodyRadius
        let entity = SnakeEntity.make(radius: radius, segments: game.snake.segments)
        game.apply(.move(direction: SIMD2(1, 0)))
        for _ in 0..<60 { game.advance(seconds: 1.0 / 60) }
        SnakeEntity.update(entity, from: game.snake, radius: radius)

        let head = try XCTUnwrap(entity.children.first { $0.name == "head" })
        XCTAssertEqual(Double(head.position.x), game.snake.head.x, accuracy: 1e-5)
        XCTAssertFalse(game.snake.tail.isEmpty)
        let shape = SnakeBody.tube(head: game.snake.head, tail: game.snake.tail, radius: radius)
        XCTAssertEqual(try drawn(entity), shape.indices.count, "the screen draws a different body from the model's")
    }

    func testASnakeThatHasEatenIsDrawnLongerThanItStarted() throws {
        // The defect FR-VIEW-180 was written against: a body made once, at the length
        // the match begins with, so that a snake that ate past it grew in the model and
        // stood still on screen (FR-SNAKE-060 true and invisible).
        // On open ground forty cells square, walked round in circles, so that nothing
        // stops the trail from growing.
        let world = try Launch.world().get()
        let radius = world.configurations.tuning.bodyRadius
        let row = String(repeating: ".", count: 40)
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n"
                                      + Array(repeating: row, count: 40).joined(separator: "\n") + "\n",
                                      kit: world.kit)
        let surfaces = Surfaces(graph: NavigationGraph.derive(from: map, stepHeight: world.configurations.tuning.stepHeight),
                                kit: world.kit, tuning: world.configurations.tuning, map: map)
        let starting = world.configurations.snake.startingSegmentCount
        var snake = Snake(head: SIMD3(10, 0, 10), floor: 0, segments: starting, segmentSpacing: radius * 2)
        let entity = SnakeEntity.make(radius: radius, segments: snake.segments)
        var frame = 0
        func walk(_ frames: Int) {
            for _ in 0..<frames {
                let angle = Double(frame) * 0.02
                snake.advance(direction: SIMD2(cos(angle), sin(angle)), speed: world.configurations.snake.baseSpeed,
                              seconds: 1.0 / 60, over: surfaces)
                frame += 1
            }
        }
        walk(240)
        SnakeEntity.update(entity, from: snake, radius: radius)
        let before = try drawn(entity)

        // Eat past what the body was made for, then walk far enough for the trail to
        // carry it all.
        snake.grow(by: SnakeBodyBuffer.spare + 10)
        walk(1200)
        XCTAssertGreaterThan(snake.tail.count, starting + SnakeBodyBuffer.spare, "the tail did not grow, so the test proves nothing")
        SnakeEntity.update(entity, from: snake, radius: radius)
        let shape = SnakeBody.tube(head: snake.head, tail: snake.tail, radius: radius)
        XCTAssertEqual(try drawn(entity), shape.indices.count, "the body was not drawn to the tail's length")
        XCTAssertGreaterThan(try drawn(entity), before)
        XCTAssertEqual(entity.children.filter { $0.name == "body" }.count, 1, "an old body was left behind")
    }
}
// srs-end: FR-SNAKE-010
