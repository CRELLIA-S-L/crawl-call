// The grenade: thrown no further than its range and going off when its fuse has run
// out (FR-BOT-470), taking everybody within the blast (FR-BOT-480), hurting a snake
// the more of it the blast covers and only once (FR-BOT-490), and never thrown where
// it would catch a squadmate the thrower can see (FR-BOT-500).
//
// The arena is an open strip, so that the only thing between anybody is distance.
//
// file verifies: FR-BOT-080, FR-BOT-470, FR-BOT-480, FR-BOT-490, FR-BOT-500
import XCTest
@testable import CrawlCall

final class GrenadeTests: XCTestCase {
    private var shipped: World!
    private var world: World!
    private let now = 10.0
    private let frame = 1.0 / 60

    override func setUpWithError() throws {
        try super.setUpWithError()
        shipped = try Launch.world().get()
        let rows = Array(repeating: String(repeating: ".", count: 80), count: 3)
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        let cell = shipped.configurations.tuning.navigationGraphCellSize
        world = World(configurations: shipped.configurations, kit: shipped.kit, map: map, setting: shipped.setting,
                      graph: NavigationGraph.derive(from: map, stepHeight: shipped.configurations.tuning.stepHeight),
                      plan: ScenePlan.make(map: map, kit: shipped.kit, cellSize: cell))
    }

    private var configuration: BotConfiguration { world.configurations.bot }

    private func bot(_ id: Int, _ squad: Squad = .red, at x: Double, _ archetype: Archetype = .assault) throws -> Bot {
        var bot = try XCTUnwrap(Bot(id: id, squad: squad, archetype: archetype, at: SIMD3(x, 0, 0.5), floor: 0,
                                    configuration: configuration))
        bot.facing = .pi / 2
        return bot
    }

    private func grenade(of bot: Bot) -> BotConfiguration.Grenade { bot.arms.grenades.numbers }

    /// What a bot sees: the enemies in view where they stand, and whatever squadmates
    /// it is given.
    private func seeing(_ enemies: [Bot], mates: [Bot] = [], from shooter: Bot) -> Deliberation.Situation {
        var situation = Deliberation.Situation(plan: world.plan, graph: world.graph,
                                               configuration: configuration,
                                               cellSize: world.configurations.tuning.navigationGraphCellSize)
        situation.enemies = enemies.map(\.position)
        situation.enemiesInView = enemies.map { (id: $0.id, point: $0.position) }
        situation.allies = [shooter] + mates
        return situation
    }

    private func throwing(in scored: [(action: Action, utility: Double)]) -> (action: Action, utility: Double)? {
        scored.first { if case .throwGrenade = $0.action { return true }; return false }
    }

    // MARK: no further than the throw (FR-BOT-470)

    func testATargetBeyondTheThrowIsNoGrenadeAction() throws {
        let shooter = try bot(0, at: 5)
        let range = grenade(of: shooter).throwRange
        let near = try bot(1, .blue, at: 5 + range / 2)
        let far = try bot(2, .blue, at: 5 + range * 2)
        XCTAssertNotNil(throwing(in: Deliberation.scores(for: shooter, in: seeing([near], from: shooter))),
                        "a target inside the throw was no grenade action")
        XCTAssertNil(throwing(in: Deliberation.scores(for: shooter, in: seeing([far], from: shooter))),
                     "a grenade was offered at a target it cannot be thrown to")
    }

    func testAThrownGrenadeGoesOffWhenItsFuseHasRunOutAndNotBefore() throws {
        // Three enemies in a knot, and a primary two thirds spent: what the grenade is
        // worth then is more than another shot, which is the whole of why it is thrown.
        var bots = try knot()
        let volley = Execution.deliberate(&bots, slots: [0], world: world, now: now)
        XCTAssertEqual(bots.first?.action.map(isThrow), true, "it did not throw")
        var flying = volley.grenades
        let thrown = try element(0, of: flying)
        XCTAssertEqual(thrown.fuse, grenade(of: try element(0, of: bots)).fuseTime)
        XCTAssertEqual(try element(0, of: bots).arms.grenades.left,
                       try element(0, of: bots).arms.grenades.carried - 1, "the throw cost no grenade")

        let whole = bots.map(\.health)
        // A frame short of the fuse: nothing has happened to anybody.
        let frames = Int((thrown.fuse / frame).rounded(.down))
        for _ in 0..<(frames - 1) {
            _ = Blast.burn(&flying, seconds: frame, bots: &bots, snake: [])
        }
        XCTAssertEqual(bots.map(\.health), whole, "the grenade went off before its fuse had run out")
        XCTAssertEqual(flying.count, 1, "the grenade is already gone")
        for _ in 0..<2 { _ = Blast.burn(&flying, seconds: frame, bots: &bots, snake: []) }
        XCTAssertTrue(flying.isEmpty, "the grenade never went off")
        XCTAssertLessThan(try element(1, of: bots).health, try element(1, of: whole),
                          "the blast left the enemy it was thrown at whole")
    }

    // MARK: everybody in the blast (FR-BOT-480)

    func testTheBlastTakesEveryBodyWithinItAndNobodyOutsideIt() throws {
        let thrower = try bot(0, at: 5)
        let radius = grenade(of: thrower).blastRadius
        let damage = grenade(of: thrower).damage
        // The blast is centred a step in front of the thrower, with an enemy and a
        // squadmate of its own standing in it and one of each just outside.
        let centre = SIMD3(5 + radius / 2, 0.0, 0.5)
        var bots = [thrower,
                    try bot(1, .blue, at: centre.x),
                    try bot(2, .red, at: centre.x + radius / 2),
                    try bot(3, .blue, at: centre.x + radius * 2)]
        let whole = bots.map(\.health)
        let struck = Blast.detonate(Thrown(thrower: thrower.id, squad: .red, position: centre,
                                           numbers: grenade(of: thrower), fuse: .zero),
                                    bots: &bots, snake: [])
        XCTAssertEqual(struck.damage, 0, "a blast with no snake in it hurt the snake")
        for index in 0...2 {
            XCTAssertEqual(try element(index, of: bots).health, try element(index, of: whole) - damage,
                           "the body \(index) places along took something other than the blast's damage")
        }
        XCTAssertEqual(try element(3, of: bots).health, try element(3, of: whole),
                       "a bot outside the blast was hurt by it")
    }

    // MARK: more of the snake, more damage, once (FR-BOT-490)

    func testABlastOverMoreOfTheSnakeHurtsItMoreAndWoundsItOnlyOnce() throws {
        let thrower = try bot(0, at: 5)
        let numbers = grenade(of: thrower)
        let centre = SIMD3(5.0, 0.0, 0.5)
        var bots = [thrower]
        let blast = { (snake: [SIMD3<Double>]) in
            Blast.detonate(Thrown(thrower: 0, squad: .red, position: centre, numbers: numbers, fuse: .zero),
                           bots: &bots, snake: snake)
        }
        // Parts a quarter of the radius apart, so that the given number of them lie in
        // the blast and nothing is on the edge of it.
        let step = numbers.blastRadius / 4
        let along = { (parts: Int) in (0..<parts).map { SIMD3(centre.x + Double($0) * step, 0, centre.z) } }
        let one = blast(along(1))
        let five = blast(along(5))
        XCTAssertEqual(one.damage, numbers.damage, accuracy: 1e-12)
        XCTAssertEqual(five.damage, numbers.damage * (1 + 4 * numbers.furtherPartShare), accuracy: 1e-12)
        XCTAssertGreaterThan(five.damage, one.damage, "a blast over five parts hurt no more than one over one")
        XCTAssertLessThan(five.damage, one.damage * 5, "a blast over five parts was worth five blasts")
        XCTAssertEqual(one.hits, 1)
        XCTAssertEqual(five.hits, 1, "the snake was wounded once per part rather than once")
    }

    // MARK: not onto one's own (FR-BOT-500)

    func testABotDoesNotThrowWhereASquadmateItSeesWouldBeCaught() throws {
        let thrower = try bot(0, at: 5)
        let radius = grenade(of: thrower).blastRadius
        let enemy = try bot(1, .blue, at: 5 + radius * 2)
        let mate = try bot(2, .red, at: enemy.position.x - radius / 2)
        XCTAssertNotNil(throwing(in: Deliberation.scores(for: thrower, in: seeing([enemy], from: thrower))),
                        "with nobody of its own about it would not throw either")
        XCTAssertNil(throwing(in: Deliberation.scores(for: thrower, in: seeing([enemy], mates: [mate], from: thrower))),
                     "it threw where it could see one of its own standing")
    }

    func testABotThrowsWhereASquadmateItCannotSeeStands() throws {
        // Deliberate, and in ADR-0075: a bot acts on what it knows (FR-BOT-220), so a
        // squadmate it cannot see is one it cannot know to be in the way. The occasional
        // grenade onto one's own squad is the price of that and not a fault.
        let thrower = try bot(0, at: 5)
        let radius = grenade(of: thrower).blastRadius
        let range = try XCTUnwrap(configuration.archetypes[Archetype.assault.rawValue]).detectionRange
        let enemy = try bot(1, .blue, at: 5 + radius)
        // Behind the thrower, out of its field of view, and well within the blast of
        // nothing it is looking at — so it is seen neither by eye nor by the throw.
        let unseen = try bot(2, .red, at: 5 - range * 2)
        XCTAssertFalse(Perception.sees(unseen.eye, from: thrower, within: range, plan: world.plan,
                                       configuration: configuration),
                       "the squadmate this test needs hidden is in plain sight")
        XCTAssertNotNil(throwing(in: Deliberation.scores(for: thrower, in: seeing([enemy], mates: [unseen],
                                                                                  from: thrower))),
                        "a squadmate it cannot see stopped the throw")
    }

    func testABotDoesNotThrowOntoItself() throws {
        let thrower = try bot(0, at: 5)
        let radius = grenade(of: thrower).blastRadius
        let close = try bot(1, .blue, at: 5 + radius / 2)
        let scored = Deliberation.scores(for: thrower, in: seeing([close], from: thrower))
        XCTAssertNil(throwing(in: scored), "it threw a grenade at its own feet")
        XCTAssertTrue(scored.contains { if case .fire = $0.action { return true }; return false },
                      "it would not fire at an enemy that close either, and this test proves nothing")
    }

    /// A bot with two fifths of its primary spent and three enemies standing in a knot
    /// a few metres off: the shape in which the scores choose the grenade — above
    /// another shot from a part-spent magazine, above the sidearm, and still above
    /// stopping to reload.
    private func knot() throws -> [Bot] {
        var shooter = try bot(0, at: 5)
        let spread = grenade(of: shooter).blastRadius / 3
        let enemies = try (1...3).map { try bot($0, .blue, at: 8 + Double($0 - 1) * spread) }
        shooter.arms.primary.rounds = shooter.arms.primary.numbers.magazine * 3 / 5
        for enemy in enemies {
            shooter.knowledge.enemies[enemy.id] = .init(point: enemy.position, time: now)
        }
        return [shooter] + enemies
    }

    private func isThrow(_ action: Action) -> Bool { if case .throwGrenade = action { return true }; return false }
}
