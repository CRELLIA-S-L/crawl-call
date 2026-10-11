// A bot under fire does not stand in the open: it fires from the nearest cell beside
// cover (FR-BOT-420), steps behind it to reload (FR-BOT-425), and with no cover near
// keeps moving across the line of fire (FR-BOT-430).
//
// file verifies: FR-BOT-420, FR-BOT-425, FR-BOT-430
import XCTest
@testable import CrawlCall

final class SkirmishTests: XCTestCase {
    private var shipped: World!
    private var configuration: BotConfiguration { shipped.configurations.bot }
    private let cell = 0.5
    private let east = Double.pi / 2
    private let frame = 1.0 / 60

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

    /// A bot that knows every cell of the map: what it knows is not what these tests are
    /// about (FR-BOT-220).
    private func bot(_ id: Int, _ squad: Squad, at x: Int, _ z: Int, in floor: World, facing: Double? = nil) throws -> Bot {
        var made = try XCTUnwrap(Bot(id: id, squad: squad, archetype: .assault, at: at(x, z), floor: 0,
                                     configuration: configuration))
        made.facing = facing ?? east
        made.knowledge.ways = Set(floor.graph.nodes)
        return made
    }

    private func situation(_ floor: World, enemies: [SIMD3<Double>]) -> Deliberation.Situation {
        var made = Deliberation.Situation(plan: floor.plan, graph: floor.graph, configuration: configuration, cellSize: cell)
        made.bodyRadius = shipped.configurations.tuning.bodyRadius
        made.enemies = enemies
        return made
    }

    private func world(rows: Int, columns: Int) throws -> World {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n"
                                      + Array(repeating: String(repeating: ".", count: columns), count: rows)
                                        .joined(separator: "\n") + "\n", kit: shipped.kit)
        return World(configurations: shipped.configurations, kit: shipped.kit, map: map, setting: shipped.setting,
                     graph: NavigationGraph.derive(from: map, stepHeight: shipped.configurations.tuning.stepHeight),
                     plan: ScenePlan.make(map: map, kit: shipped.kit, cellSize: cell))
    }

    /// A crate higher than the eyes in the middle row, the enemy east of it.
    private func crateField() throws -> World {
        try world(String(repeating: ".", count: 20), "........o...........", String(repeating: ".", count: 20))
    }

    // MARK: beside cover (FR-BOT-420)

    func testTheCellFoundHasALineOfFireAndAHiddenCellBesideItAndIsTheNearest() throws {
        let floor = try crateField()
        let enemy = at(18, 1)
        let shooter = try bot(0, .red, at: 12, 2, in: floor)
        let seen = situation(floor, enemies: [enemy])
        let aim = enemy + SIMD3(0, configuration.eyeHeight, 0)
        let rise = SIMD3(0, configuration.eyeHeight, 0)
        let found = try XCTUnwrap(Deliberation.post(for: shooter, aim: aim, in: seen), "no cell beside the crate was found")
        func centre(_ node: NavigationGraph.Node) -> SIMD3<Double> { Deliberation.centre(of: node, in: seen) }
        XCTAssertTrue(Sight.isClear(from: centre(found.post) + rise, to: aim, through: floor.plan),
                      "no line of fire from where it is to fire from")
        XCTAssertTrue(floor.graph.neighbours(of: found.post).contains(found.refuge), "the hidden cell is not beside it")
        XCTAssertFalse(Deliberation.isWatched(found.refuge, for: shooter, in: seen), "the cell behind is watched")
        XCTAssertNotEqual(found.post, node(12, 2), "the open cell it stands in was taken for one beside cover")

        // No cell nearer the bot, within the search distance, has both.
        let reach = Deliberation.coverSearch(configuration)
        let distance = Perception.metres(shooter.position, centre(found.post))
        for other in floor.graph.nodes where Perception.metres(shooter.position, centre(other)) < distance - 1e-9
            && Perception.metres(shooter.position, centre(other)) <= reach {
            let fires = Sight.isClear(from: centre(other) + rise, to: aim, through: floor.plan)
            let hides = floor.graph.neighbours(of: other).contains { !Deliberation.isWatched($0, for: shooter, in: seen) }
            XCTAssertFalse(fires && hides, "\(other) is nearer and would do")
        }
    }

    func testACellASquadmateHasTakenIsNotTakenAgain() throws {
        let floor = try crateField()
        let enemy = at(18, 1)
        let aim = enemy + SIMD3(0, configuration.eyeHeight, 0)
        let shooter = try bot(0, .red, at: 12, 2, in: floor)
        var seen = situation(floor, enemies: [enemy])
        let first = try XCTUnwrap(Deliberation.post(for: shooter, aim: aim, in: seen))
        var mate = try bot(1, .red, at: 12, 0, in: floor)
        mate.post = first.post
        mate.refuge = first.refuge
        seen.allies = [shooter, mate]
        let second = Deliberation.post(for: shooter, aim: aim, in: seen)
        XCTAssertNotEqual(second?.post, first.post, "the squadmate's cell to fire from was taken again")
        XCTAssertNotEqual(second?.refuge, first.refuge, "the squadmate's hidden cell was taken again")
        XCTAssertNotEqual(second?.post, first.refuge)
        XCTAssertNotEqual(second?.refuge, first.post)
        // An enemy's cells are not a squadmate's.
        var foe = try bot(1, .blue, at: 12, 0, in: floor)
        foe.post = first.post
        foe.refuge = first.refuge
        seen.allies = [shooter, foe]
        XCTAssertEqual(Deliberation.post(for: shooter, aim: aim, in: seen)?.post, first.post)
    }

    func testWithNothingToHideBehindThereIsNoCellBesideCover() throws {
        let floor = try world(String(repeating: ".", count: 20), String(repeating: ".", count: 20),
                              String(repeating: ".", count: 20))
        let enemy = at(18, 1)
        let shooter = try bot(0, .red, at: 1, 2, in: floor)
        XCTAssertNil(Deliberation.post(for: shooter, aim: enemy + SIMD3(0, configuration.eyeHeight, 0),
                                       in: situation(floor, enemies: [enemy])))
    }

    func testABotFiringGoesToFireFromBesideCoverAndFiresOnTheWay() throws {
        let floor = try crateField()
        var shooter = try bot(0, .red, at: 1, 2, in: floor)
        shooter.knowledge.enemies = [1: .init(point: at(12, 2), time: 0)]
        let enemy = try bot(1, .blue, at: 12, 2, in: floor, facing: -east)
        var bots = [shooter, enemy]
        let volley = Execution.deliberate(&bots, slots: [0], world: floor, now: 0)
        XCTAssertEqual(try element(0, of: bots).action, .fire(at: .bot(id: 1)))
        XCTAssertEqual(volley.rounds.count, 1, "it did not fire as it set off")
        let post = try XCTUnwrap(try element(0, of: bots).post, "it found nowhere beside cover")
        XCTAssertNotNil(try element(0, of: bots).refuge)
        for _ in 0..<120 { Execution.walk(&bots, seconds: frame, world: floor, now: 0) }
        XCTAssertEqual(Execution.cell(of: try element(0, of: bots), world: floor), post, "it did not get there")
        XCTAssertEqual(try element(0, of: bots).action, .fire(at: .bot(id: 1)), "arriving ended its firing")
        XCTAssertEqual(try element(0, of: bots).speed, 0, "it did not stop there")
    }

    // MARK: reloading behind cover (FR-BOT-425)

    func testABotFiringFromBesideCoverReloadsInTheHiddenCell() throws {
        let floor = try crateField()
        var shooter = try bot(0, .red, at: 1, 2, in: floor)
        shooter.knowledge.enemies = [1: .init(point: at(12, 2), time: 0)]
        let enemy = try bot(1, .blue, at: 12, 2, in: floor, facing: -east)
        var bots = [shooter, enemy]
        _ = Execution.deliberate(&bots, slots: [0], world: floor, now: 0)
        let post = try XCTUnwrap(try element(0, of: bots).post)
        let refuge = try XCTUnwrap(try element(0, of: bots).refuge)
        // Standing where it fires from, out of rounds.
        let size = shipped.configurations.tuning.navigationGraphCellSize
        let first = try checkedIndex(0, of: bots)
        bots[first].position = SIMD3(Double(post.x) * size, 0, Double(post.z) * size)
        bots[first].path = []
        bots[first].ammunition = 0
        let magazine = try XCTUnwrap(configuration.archetypes["assault"]).magazine
        _ = Execution.deliberate(&bots, slots: [0], world: floor, now: 1)
        XCTAssertEqual(try element(0, of: bots).action, .reload)
        XCTAssertEqual(try element(0, of: bots).ammunition, 0, "it reloaded out in the open")
        for _ in 0..<120 {
            Execution.walk(&bots, seconds: frame, world: floor, now: 1)
            if try element(0, of: bots).ammunition > 0 { break }
        }
        XCTAssertEqual(try element(0, of: bots).ammunition, magazine, "it never reloaded")
        XCTAssertEqual(Execution.cell(of: try element(0, of: bots), world: floor), refuge,
                       "it reloaded somewhere other than the hidden cell")
    }

    func testReloadedBehindCoverABotComesOutAgainToFireFromWhereItDid() throws {
        // The bot of the test above, reloaded in the hidden cell and out of sight of the
        // enemy: it goes back to where it fired from, and fires only once it sees the
        // enemy again (FR-BOT-060, ADR-0063).
        let floor = try crateField()
        var shooter = try bot(0, .red, at: 1, 2, in: floor)
        shooter.knowledge.enemies = [1: .init(point: at(12, 2), time: 0)]
        let enemy = try bot(1, .blue, at: 12, 2, in: floor, facing: -east)
        var bots = [shooter, enemy]
        _ = Execution.deliberate(&bots, slots: [0], world: floor, now: 0)
        let post = try XCTUnwrap(try element(0, of: bots).post)
        let refuge = try XCTUnwrap(try element(0, of: bots).refuge)
        let size = shipped.configurations.tuning.navigationGraphCellSize
        let first = try checkedIndex(0, of: bots)
        bots[first].position = SIMD3(Double(refuge.x) * size, 0, Double(refuge.z) * size)
        bots[first].path = []
        bots[first].action = nil
        // Seen last a second ago, from where it cannot see it now.
        bots[first].knowledge.enemies = [1: .init(point: at(12, 2), time: 0)]
        XCTAssertFalse(Sight.isClear(from: try element(0, of: bots).eye, to: enemy.eye, through: floor.plan),
                       "the enemy is in sight from the hidden cell, so this proves nothing")
        let hidden = Execution.deliberate(&bots, slots: [0], world: floor, now: 1)
        XCTAssertEqual(try element(0, of: bots).action, .fire(at: .bot(id: 1)), "it stayed behind the cover")
        XCTAssertTrue(hidden.rounds.isEmpty, "it fired at an enemy it does not see")
        for _ in 0..<120 { Execution.walk(&bots, seconds: frame, world: floor, now: 1) }
        XCTAssertEqual(Execution.cell(of: try element(0, of: bots), world: floor), post,
                       "it did not come out to where it fired from")

        // Out there with a clear line to the enemy, it still does not fire before it has
        // seen it: turned away, it has not.
        var away = bots
        away[first].facing = -east
        Perception.noticeEnemies(&away, plan: floor.plan, configuration: configuration, now: 1.5)
        XCTAssertTrue(Sight.isClear(from: try element(0, of: away).eye, to: enemy.eye, through: floor.plan),
                      "no line of fire from where it fires from, so this proves nothing")
        XCTAssertTrue(Execution.deliberate(&away, slots: [0], world: floor, now: 1.5).rounds.isEmpty,
                      "it fired at an enemy it had not seen")

        // Facing it, it sees the enemy again and fires.
        let out = bots
        Perception.noticeEnemies(&bots, plan: floor.plan, configuration: configuration, now: 2)
        XCTAssertEqual(Execution.deliberate(&bots, slots: [0], world: floor, now: 2).rounds.count, 1)

        // Where it sees the place it last saw the enemy and nobody there, it does not
        // stand firing at the memory: the enemy has gone.
        var gone = out
        gone[first].facing = east
        gone.removeLast()
        _ = Execution.deliberate(&gone, slots: [0], world: floor, now: 2)
        if case .fire = try element(0, of: gone).action { XCTFail("it stands firing at where the enemy was") }
    }

    func testABotReloadingInTheHiddenCellKeepsWhereItFiresFrom() throws {
        // Deliberating once already in the hidden cell — come to it by rounding before the
        // end of its way, or pushed into it — it reloads there and does not forget where it
        // fires from, so that it comes out again (ADR-0063).
        let floor = try crateField()
        var shooter = try bot(0, .red, at: 1, 2, in: floor)
        shooter.knowledge.enemies = [1: .init(point: at(12, 2), time: 0)]
        var bots = [shooter, try bot(1, .blue, at: 12, 2, in: floor, facing: -east)]
        _ = Execution.deliberate(&bots, slots: [0], world: floor, now: 0)
        let post = try XCTUnwrap(try element(0, of: bots).post)
        let refuge = try XCTUnwrap(try element(0, of: bots).refuge)
        let size = shipped.configurations.tuning.navigationGraphCellSize
        let first = try checkedIndex(0, of: bots)
        bots[first].position = SIMD3(Double(refuge.x) * size, 0, Double(refuge.z) * size)
        bots[first].path = []
        bots[first].ammunition = 0
        _ = Execution.deliberate(&bots, slots: [0], world: floor, now: 1)
        XCTAssertEqual(try element(0, of: bots).action, .reload)
        XCTAssertEqual(try element(0, of: bots).ammunition, try XCTUnwrap(configuration.archetypes["assault"]).magazine)
        XCTAssertEqual(try element(0, of: bots).post, post, "it forgot where it fires from")
        // Out of sight of the enemy, it goes back out to fire.
        bots[first].action = nil
        _ = Execution.deliberate(&bots, slots: [0], world: floor, now: 2)
        XCTAssertEqual(try element(0, of: bots).action, .fire(at: .bot(id: 1)), "it stays behind the cover")
    }

    func testABotWithNoCoverBesideItReloadsWhereItStands() throws {
        let floor = try world(String(repeating: ".", count: 20), String(repeating: ".", count: 20),
                              String(repeating: ".", count: 20))
        var shooter = try bot(0, .red, at: 1, 1, in: floor)
        shooter.knowledge.enemies = [1: .init(point: at(12, 1), time: 0)]
        shooter.ammunition = 0
        var bots = [shooter, try bot(1, .blue, at: 12, 1, in: floor, facing: -east)]
        _ = Execution.deliberate(&bots, slots: [0], world: floor, now: 0)
        XCTAssertEqual(try element(0, of: bots).action, .reload)
        XCTAssertEqual(try element(0, of: bots).ammunition, try XCTUnwrap(configuration.archetypes["assault"]).magazine)
    }

    // MARK: on the move (FR-BOT-430)

    func testWithNoCoverABotFiringMovesAcrossItsLineOfFire() throws {
        // Seventeen rows, the bot in the middle: four metres of ground either way across the
        // line, more than it covers in an interval, so that a turn back is the interval's
        // and not the edge's.
        let floor = try world(rows: 17, columns: 24)
        var shooter = try bot(0, .red, at: 2, 8, in: floor)
        shooter.knowledge.enemies = [1: .init(point: at(12, 8), time: 0)]
        let enemy = try bot(1, .blue, at: 12, 8, in: floor, facing: -east)
        var bots = [shooter, enemy]
        _ = Execution.deliberate(&bots, slots: [0], world: floor, now: 0)
        XCTAssertEqual(try element(0, of: bots).action, .fire(at: .bot(id: 1)))
        XCTAssertNil(try element(0, of: bots).post, "a cell beside cover was found in the open")
        XCTAssertLessThan(configuration.strafingSpeed * configuration.strafingInterval, 4,
                          "the bot reaches the edge within an interval, so this proves nothing")

        // Half the interval: it has moved, across the line (z) and not along it (x), and
        // no faster than the strafing speed.
        let half = Int((configuration.strafingInterval / 2 / frame).rounded())
        var fastest = 0.0
        for step in 0..<half {
            Execution.walk(&bots, seconds: frame, world: floor, now: Double(step) * frame)
            fastest = max(fastest, try element(0, of: bots).speed)
        }
        let went = try element(0, of: bots).position - shooter.position
        XCTAssertGreaterThan(abs(went.z), 0.2, "it stood still")
        // Across the line as it runs from where the bot is now, which turns as it moves:
        // along the line hardly at all.
        XCTAssertLessThan(abs(went.x), abs(went.z) / 4, "it moved along its line of fire")
        XCTAssertLessThanOrEqual(fastest, configuration.strafingSpeed + 1e-9)
        XCTAssertGreaterThan(fastest, configuration.strafingSpeed - 1e-9, "it never got up to the strafing speed")

        // It turns back when the interval is up, and not before.
        let first = went.z.sign
        var turned: Double?
        var last = try element(0, of: bots).position.z
        for step in half..<(half * 4) {
            let now = Double(step) * frame
            Execution.walk(&bots, seconds: frame, world: floor, now: now)
            let z = try element(0, of: bots).position.z
            if turned == nil, (z - last).sign != first, abs(z - last) > 1e-12 { turned = now }
            last = z
        }
        let at = try XCTUnwrap(turned, "it never turned back")
        XCTAssertEqual(at, configuration.strafingInterval, accuracy: frame * 2,
                       "it turned back other than when the strafing interval was up")
    }

    func testABotStrafingTurnsBackWhereTheGroundEnds() throws {
        // One row wide: whichever way across the line it goes, the ground ends at once.
        let floor = try world(String(repeating: ".", count: 24))
        var shooter = try bot(0, .red, at: 2, 0, in: floor)
        shooter.knowledge.enemies = [1: .init(point: at(12, 0), time: 0)]
        var bots = [shooter, try bot(1, .blue, at: 12, 0, in: floor, facing: -east)]
        _ = Execution.deliberate(&bots, slots: [0], world: floor, now: 0)
        let way = try element(0, of: bots).strafe
        var turned = false
        // Well within the strafing interval: a turn is the edge's doing.
        let frames = Int((configuration.strafingInterval / 2 / frame).rounded())
        for step in 0..<frames {
            Execution.walk(&bots, seconds: frame, world: floor, now: Double(step) * frame)
            let now = try element(0, of: bots).strafe
            turned = turned || now != way
            XCTAssertTrue(floor.graph.isWalkable(Execution.cell(of: try element(0, of: bots), world: floor)),
                          "it walked off the ground")
        }
        XCTAssertTrue(turned, "it did not turn back at the edge")
    }
}
