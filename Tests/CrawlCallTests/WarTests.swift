// The squads at war: a bot fires at an enemy it sees (FR-BOT-060) and keeps to its
// target unless another is worth clearly more (FR-BOT-140); a bot with no health
// left is a body that does nothing (FR-BOT-320), drawn lying (FR-VIEW-300); a bot
// hides from the enemy as from the snake (FR-BOT-330); and a bot that stands looks
// where there is something to see, not at a wall (FR-BOT-340).
//
// verifies: FR-BOT-060, FR-BOT-140, FR-BOT-320, FR-BOT-330, FR-BOT-340, FR-VIEW-300
import RealityKit
import XCTest
@testable import CrawlCall

final class WarTests: XCTestCase {
    private var shipped: World!
    private var configuration: BotConfiguration { shipped.configurations.bot }
    private let cell = 0.5
    private let east = Double.pi / 2

    override func setUpWithError() throws {
        try super.setUpWithError()
        shipped = try Launch.world().get()
    }

    private func world(_ rows: String...) throws -> World {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        return World(configurations: shipped.configurations, kit: shipped.kit, map: map, setting: shipped.setting,
                     graph: NavigationGraph.derive(from: map, stepHeight: shipped.configurations.tuning.stepHeight),
                     plan: ScenePlan.make(map: map, kit: shipped.kit, cellSize: cell))
    }

    private func at(_ x: Int, _ z: Int) -> SIMD3<Double> { SIMD3(Double(x) * cell, 0, Double(z) * cell) }
    private func node(_ x: Int, _ z: Int) -> NavigationGraph.Node { NavigationGraph.Node(floor: 0, x: x, z: z) }

    private func bot(_ id: Int, _ squad: Squad, at x: Int, _ z: Int, facing: Double? = nil) throws -> Bot {
        var made = try XCTUnwrap(Bot(id: id, squad: squad, archetype: .assault, at: at(x, z), floor: 0,
                                     configuration: configuration))
        made.facing = facing ?? east
        return made
    }

    private func situation(_ floor: World) -> Deliberation.Situation {
        Deliberation.Situation(plan: floor.plan, graph: floor.graph, configuration: configuration, cellSize: cell)
    }

    private var damage: Double { configuration.archetypes["assault"]?.weaponDamage ?? .nan }

    // MARK: fire at the enemy (FR-BOT-060)

    func testABotFiresAtAnEnemyItSeesAndTheEnemyIsHurt() throws {
        // One open row, nowhere to hide: firing is what there is to do.
        let floor = try world(String(repeating: ".", count: 16))
        var shooter = try bot(0, .red, at: 1, 0)
        shooter.knowledge.enemies = [1: .init(point: at(8, 0), time: 2)]
        let enemy = try bot(1, .blue, at: 8, 0, facing: -east)
        var bots = [shooter, enemy]
        let volley = Execution.deliberate(&bots, slots: [0], world: floor, now: 2)
        XCTAssertEqual(try element(0, of: bots).action, .fire(at: .bot(id: 1)))
        XCTAssertEqual(try element(1, of: bots).health, enemy.health - damage, accuracy: 1e-9)
        XCTAssertEqual(try element(0, of: bots).ammunition, shooter.ammunition - 1)
        XCTAssertEqual(volley.damage, 0, "a shot at a bot struck the snake")
        XCTAssertEqual(volley.hits, 0)
        XCTAssertEqual(volley.shots.count, 1, "the shot is not drawn")

        // An enemy remembered and not in view now is not fired at.
        var remembering = shooter
        remembering.knowledge.enemies = [1: .init(point: at(8, 0), time: 1)]
        bots = [remembering, enemy]
        _ = Execution.deliberate(&bots, slots: [0], world: floor, now: 2)
        XCTAssertEqual(try element(1, of: bots).health, enemy.health, "the bot fired at an enemy it does not see")
    }

    func testNoBotFiresAtItsOwnSquad() throws {
        let floor = try world(String(repeating: ".", count: 16))
        var bots = [try bot(0, .red, at: 1, 0), try bot(1, .red, at: 8, 0)]
        Perception.noticeEnemies(&bots, plan: floor.plan, configuration: configuration, now: 1)
        _ = Execution.deliberate(&bots, slots: [0], world: floor, now: 1)
        let full = try bot(1, .red, at: 8, 0).health
        XCTAssertTrue(try element(0, of: bots).knowledge.enemies.isEmpty, "a mate was taken for an enemy")
        XCTAssertEqual(try element(1, of: bots).health, full, "the bot fired at its own squad")
    }

    // MARK: keeping a target (FR-BOT-140)

    func testATargetIsKeptUntilAnotherIsWorthMoreByTheMargin() throws {
        let floor = try world(String(repeating: ".", count: 20))
        var shooter = try bot(0, .red, at: 1, 0)
        var seen = situation(floor)
        seen.enemiesInView = [(id: 1, point: at(6, 0)), (id: 2, point: at(8, 0))]
        let margin = configuration.hysteresisMargin
        // Worth falls off with distance: the nearer enemy, 1, is worth more.
        func worth(_ gap: Double) -> (Double) -> Double {
            { metres in metres < 3.0 ? 1 + gap : 1 }
        }
        XCTAssertEqual(Deliberation.target(for: shooter, in: seen, worth: worth(margin / 2))?.target, .bot(id: 1))

        // Already firing at 2: the other is better, by less than the margin — kept.
        shooter.action = .fire(at: .bot(id: 2))
        XCTAssertEqual(Deliberation.target(for: shooter, in: seen, worth: worth(margin / 2))?.target, .bot(id: 2))
        // By more than the margin — changed.
        XCTAssertEqual(Deliberation.target(for: shooter, in: seen, worth: worth(margin * 2))?.target, .bot(id: 1))
        // Its target out of view: nothing to keep.
        seen.enemiesInView = [(id: 1, point: at(6, 0))]
        XCTAssertEqual(Deliberation.target(for: shooter, in: seen, worth: worth(margin / 2))?.target, .bot(id: 1))
    }

    // MARK: the dead (FR-BOT-320)

    func testABotKilledIsABodyThatDoesNothing() throws {
        let floor = try world(String(repeating: ".", count: 16))
        var shooter = try bot(0, .red, at: 1, 0)
        shooter.knowledge.enemies = [1: .init(point: at(8, 0), time: 2)]
        var enemy = try bot(1, .blue, at: 8, 0, facing: -east)
        enemy.health = damage / 2
        enemy.action = .flee(to: node(14, 0))
        enemy.path = [node(9, 0), node(10, 0)]
        var bots = [shooter, enemy]
        _ = Execution.deliberate(&bots, slots: [0], world: floor, now: 2)
        let body = try element(1, of: bots)
        XCTAssertEqual(body.health, 0)
        XCTAssertFalse(body.isAlive)
        XCTAssertNil(body.action, "the body still means to go somewhere")

        // It chooses nothing, though given its turn and an enemy in view; walks
        // nowhere, though left a way to go; turns no more; and is not pushed.
        var still = body
        still.knowledge.enemies = [2: .init(point: at(8, 0), time: 3)]
        still.action = .flee(to: node(14, 0))
        still.path = [node(9, 0), node(14, 0)]
        var living = try bot(2, .red, at: 8, 0)
        living.position.x += 0.1
        bots = [still, living]
        let volley = Execution.deliberate(&bots, slots: [1, 2], world: floor, now: 3)
        XCTAssertTrue(volley.shots.isEmpty, "somebody fired: the body, or the living at nothing")
        XCTAssertEqual(try element(0, of: bots).action, still.action, "the body chose")
        for _ in 0..<30 { Execution.walk(&bots, seconds: 1.0 / 60, world: floor) }
        XCTAssertEqual(try element(0, of: bots).position, still.position, "the body moved")
        XCTAssertEqual(try element(0, of: bots).facing, still.facing, "the body turned")
    }

    func testABodyIsSeenForWhatItIsAndNobodyFiresAtIt() throws {
        let floor = try world(String(repeating: ".", count: 16))
        var shooter = try bot(0, .red, at: 1, 0)
        shooter.knowledge.enemies = [1: .init(point: at(8, 0), time: 1)]
        var body = try bot(1, .blue, at: 8, 0)
        body.health = 0
        var bots = [shooter, body, try bot(2, .red, at: 1, 1, facing: -east)]  // the mate looks away
        Perception.noticeEnemies(&bots, plan: floor.plan, configuration: configuration, now: 2)
        let knowledge = try element(0, of: bots).knowledge
        XCTAssertNil(knowledge.enemies.first { $0.key == 1 }, "the body is still an enemy")
        XCTAssertEqual(knowledge.fallen, [1: 2])
        _ = Execution.deliberate(&bots, slots: [0], world: floor, now: 2)
        XCTAssertNotEqual(try element(0, of: bots).action, .fire(at: .bot(id: 1)))

        // The squad hears of it after its delay, and an older sighting of the enemy
        // standing does not bring it back.
        let delay = try XCTUnwrap(configuration.shareDelay["red"])
        bots[try checkedIndex(2, of: bots)].knowledge.enemies = [1: .init(point: at(8, 0), time: 1)]
        Execution.share(&bots, now: 2 + delay * 0.5, configuration: configuration)
        XCTAssertTrue(try element(2, of: bots).knowledge.fallen.isEmpty, "heard before the delay")
        Execution.share(&bots, now: 2 + delay, configuration: configuration)
        XCTAssertEqual(try element(2, of: bots).knowledge.fallen, [1: 2])
        XCTAssertTrue(try element(2, of: bots).knowledge.enemies.isEmpty, "the dead enemy is still one")
    }

    // MARK: hiding from the enemy (FR-BOT-330)

    func testABotHidesFromAnEnemyBehindWhatStandsHigherThanItsEyes() throws {
        // A crate below the row and a wall further along it: the enemy's eyes see over
        // the wall and not over the crate.
        let floor = try world(String(repeating: ".", count: 16),
                              "....o...#.......",
                              String(repeating: ".", count: 16))
        let hider = try bot(0, .red, at: 4, 0)
        var seen = situation(floor)
        seen.enemies = [at(4, 0) + SIMD3(0, 0, -3)]  // three metres north of the row
        let cover = try XCTUnwrap(Deliberation.cover(for: hider, from: [], enemies: seen.enemies, in: seen))
        XCTAssertEqual(cover.node, node(4, 2), "the bot did not go behind the crate")
        let score = Deliberation.scores(for: hider, in: seen)
        XCTAssertTrue(score.contains { if case .takeCover = $0.action { return true }; return false },
                      "no cover is offered from an enemy")
        // With nothing standing high enough, there is no cover.
        let low = try world(String(repeating: ".", count: 16),
                            "........#.......",
                            String(repeating: ".", count: 16))
        var open = situation(low)
        open.enemies = seen.enemies
        XCTAssertNil(Deliberation.cover(for: hider, from: [], enemies: open.enemies, in: open),
                     "a wall lower than the enemy's eyes was taken for cover")
    }

    // MARK: not looking at a wall (FR-BOT-340)

    private func knowing(_ bot: Bot, _ floor: World) -> Bot {
        var bot = bot
        bot.knowledge.outline = Set(floor.graph.nodes)
            .union(floor.map.placements.map { node($0.x, $0.z) })
        Perception.lookAtMap(&bot, world: floor, modules: Perception.modules(of: floor.map), now: 0)
        return bot
    }

    func testAStandingBotTurnsFromAWallBeforeIt() throws {
        let floor = try world(String(repeating: ".", count: 12),
                              ".....o......",
                              ".....o......",
                              ".....o......",
                              String(repeating: ".", count: 12))
        // Facing the crates, half a metre away.
        let facing = knowing(try bot(0, .red, at: 4, 2, facing: east), floor)
        let away = Execution.lookout(for: facing, world: floor)
        let gap = abs(atan2(sin(away - east), cos(away - east)))
        XCTAssertGreaterThan(gap, .pi / 4, "the bot still looks at the crates")
        var bots = [facing]
        for _ in 0..<60 { Execution.walk(&bots, seconds: 1.0 / 60, world: floor) }
        XCTAssertEqual(try element(0, of: bots).facing, away, accuracy: 1e-9, "the bot did not turn from the crates")

        // Facing open ground, it keeps its facing.
        let open = knowing(try bot(0, .red, at: 4, 2, facing: -east), floor)
        XCTAssertEqual(Execution.lookout(for: open, world: floor), -east)
    }

    func testTheEdgeOfTheBuildingIsAWallAndAnUnseenCellIsNot() throws {
        let floor = try world(String(repeating: ".", count: 12), String(repeating: ".", count: 12))
        // At the east edge of the outline, facing out of it.
        let edge = knowing(try bot(0, .red, at: 11, 0, facing: east), floor)
        XCTAssertNotEqual(Execution.lookout(for: edge, world: floor), east, "the bot stares off the edge")
        // Facing a crate it has not seen: open, as far as it knows (ADR-0032).
        let crate = try world(String(repeating: ".", count: 12), ".....o......")
        var blind = try bot(0, .red, at: 4, 1, facing: east)
        blind.knowledge.outline = Set(crate.graph.nodes).union(crate.map.placements.map { node($0.x, $0.z) })
        XCTAssertEqual(Execution.lookout(for: blind, world: crate), east)
    }

    // MARK: the body drawn (FR-VIEW-300)

    @MainActor
    func testABodyIsDrawnLying() throws {
        var body = try bot(0, .red, at: 4, 4)
        body.health = 0
        let alive = try bot(1, .red, at: 8, 4)
        let entity = BotEntity.make(for: [body, alive], height: configuration.figureHeight)
        BotEntity.update(entity, from: [body, alive])
        func up(_ id: Int) throws -> SIMD3<Float> {
            let figure = try XCTUnwrap(entity.children.first { $0.name == EntityName.numbered(EntityName.bot, id) })
            return figure.orientation.act(SIMD3(0, 1, 0))
        }
        XCTAssertEqual(try up(0).y, 0, accuracy: 1e-5, "the body stands")
        XCTAssertEqual(try up(1).y, 1, accuracy: 1e-5, "the living bot lies down")
    }
}
