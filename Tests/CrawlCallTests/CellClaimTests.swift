// Nobody sets out for a cell another bot holds or is making for (FR-BOT-530).
//
// The arena is an open strip, so that what is left out of a cell search is not
// confused with what the walls leave out.
//
// file verifies: FR-BOT-530
import XCTest
@testable import CrawlCall

final class CellClaimTests: XCTestCase {
    private var shipped: World!
    private var floor: World!
    private var configuration: BotConfiguration { shipped.configurations.bot }
    private let cell = 0.5

    override func setUpWithError() throws {
        try super.setUpWithError()
        shipped = try Launch.world().get()
        floor = try world(rows: 5, columns: 40)
    }

    /// A strip of the rows given, each character a cell: `o` is a crate taller than
    /// the eyes, so that a cell behind it is one the snake cannot see into.
    private func strip(_ rows: String...) throws -> World {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        return World(configurations: shipped.configurations, kit: shipped.kit, map: map, setting: shipped.setting,
                     graph: NavigationGraph.derive(from: map, stepHeight: shipped.configurations.tuning.stepHeight),
                     plan: ScenePlan.make(map: map, kit: shipped.kit, cellSize: cell))
    }

    private func world(rows: Int, columns: Int) throws -> World {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n"
                                      + Array(repeating: String(repeating: ".", count: columns), count: rows)
                                        .joined(separator: "\n") + "\n", kit: shipped.kit)
        return World(configurations: shipped.configurations, kit: shipped.kit, map: map, setting: shipped.setting,
                     graph: NavigationGraph.derive(from: map, stepHeight: shipped.configurations.tuning.stepHeight),
                     plan: ScenePlan.make(map: map, kit: shipped.kit, cellSize: cell))
    }

    private func at(_ x: Int, _ z: Int) -> SIMD3<Double> { SIMD3(Double(x) * cell, 0, Double(z) * cell) }
    private func node(_ x: Int, _ z: Int) -> NavigationGraph.Node { NavigationGraph.Node(floor: 0, x: x, z: z) }

    private func bot(_ id: Int, _ squad: Squad, at x: Int, _ z: Int) throws -> Bot {
        var made = try XCTUnwrap(Bot(id: id, squad: squad, archetype: .assault, at: at(x, z), floor: 0,
                                     configuration: configuration))
        made.facing = .pi / 2
        made.knowledge.ways = Set(floor.graph.nodes)
        return made
    }

    private func situation(_ allies: [Bot], enemiesInView: [(id: Int, point: SIMD3<Double>)] = [],
                           enemies: [SIMD3<Double>] = []) -> Deliberation.Situation {
        var made = Deliberation.Situation(plan: floor.plan, graph: floor.graph,
                                          configuration: configuration, cellSize: cell)
        made.bodyRadius = shipped.configurations.tuning.bodyRadius
        made.allies = allies
        made.enemiesInView = enemiesInView
        made.enemies = enemies
        return made
    }

    /// The cells the walk gives a bot, within the distance every cell search uses.
    private func offered(to bot: Bot, in situation: Deliberation.Situation) -> Set<NavigationGraph.Node> {
        Set(Deliberation.walk(from: node(Int((bot.position.x / cell).rounded()), Int((bot.position.z / cell).rounded())),
                              within: Deliberation.coverSearch(configuration),
                              for: bot, in: situation).map(\.node))
    }

    // MARK: what holds a cell

    func testTheCellASquadmateStandsInIsNotOffered() throws {
        let mover = try bot(0, .red, at: 10, 2)
        let mate = try bot(1, .red, at: 12, 2)
        let cells = offered(to: mover, in: situation([mover, mate]))
        XCTAssertFalse(cells.contains(node(12, 2)), "the cell a squadmate stands in was offered")
        XCTAssertTrue(cells.contains(node(12, 3)), "the cell beside it was left out as well")
    }

    func testTheCellASquadmateIsMakingForIsNotOffered() throws {
        let mover = try bot(0, .red, at: 10, 2)
        var mate = try bot(1, .red, at: 12, 2)
        mate.action = .takeCover(at: node(11, 1))
        let cells = offered(to: mover, in: situation([mover, mate]))
        XCTAssertFalse(cells.contains(node(11, 1)), "the cell a squadmate had set out for was offered")
    }

    func testTheCellsASquadmateFiresFromAndReloadsInAreNotOffered() throws {
        let mover = try bot(0, .red, at: 10, 2)
        var mate = try bot(1, .red, at: 12, 2)
        mate.post = node(11, 3)
        mate.refuge = node(11, 4)
        mate.action = .fire(at: .bot(id: 9), with: .primary)
        let cells = offered(to: mover, in: situation([mover, mate]))
        XCTAssertFalse(cells.contains(node(11, 3)), "the cell a squadmate fires from was offered")
        XCTAssertFalse(cells.contains(node(11, 4)), "the cell a squadmate reloads in was offered")
    }

    func testTheCellAnEnemyInViewStandsInIsNotOffered() throws {
        let mover = try bot(0, .red, at: 10, 2)
        let enemy = try bot(1, .blue, at: 12, 2)
        let cells = offered(to: mover, in: situation([mover], enemiesInView: [(id: enemy.id, point: enemy.position)]))
        XCTAssertFalse(cells.contains(node(12, 2)), "the cell an enemy in view stands in was offered")
    }

    // MARK: what does not hold one

    func testTheCellARememberedEnemyStoodInIsStillOffered() throws {
        let mover = try bot(0, .red, at: 10, 2)
        let cells = offered(to: mover, in: situation([mover], enemies: [at(12, 2)]))
        XCTAssertTrue(cells.contains(node(12, 2)),
                      "a cell an enemy was last seen in and is not seen in now was held against the bot")
    }

    func testTheCellABodyLiesInIsStillOffered() throws {
        let mover = try bot(0, .red, at: 10, 2)
        var dead = try bot(1, .red, at: 12, 2)
        dead.health = .zero
        dead.action = .takeCover(at: node(11, 1))
        let cells = offered(to: mover, in: situation([mover, dead]))
        XCTAssertTrue(cells.contains(node(12, 2)), "a body held the cell it lies in")
        XCTAssertTrue(cells.contains(node(11, 1)), "a body held the cell it had set out for")
    }

    func testTheCellTheBotItselfStandsInAndTheOneItIsMakingForAreStillOffered() throws {
        var mover = try bot(0, .red, at: 10, 2)
        mover.action = .takeCover(at: node(11, 1))
        let cells = offered(to: mover, in: situation([mover]))
        XCTAssertTrue(cells.contains(node(10, 2)), "the bot held the cell it stands in against itself")
        XCTAssertTrue(cells.contains(node(11, 1)), "the bot held the cell it is going to against itself")
    }

    func testAnEnemyOfTheOtherSquadHoldsNoCellByWhereItIsGoing() throws {
        let mover = try bot(0, .red, at: 10, 2)
        var enemy = try bot(1, .blue, at: 12, 2)
        enemy.action = .takeCover(at: node(11, 1))
        // Seen, so it holds the cell it stands in; where it is going is its own squad's
        // business and nobody tells this bot (FR-BOT-220).
        let cells = offered(to: mover, in: situation([mover], enemiesInView: [(id: enemy.id, point: enemy.position)]))
        XCTAssertFalse(cells.contains(node(12, 2)), "the cell an enemy in view stands in was offered")
        XCTAssertTrue(cells.contains(node(11, 1)), "a cell an enemy was making for was held against the bot")
    }

    // MARK: the searches that use it

    func testFleeingTakesAnotherCellOnceASquadmateIsMakingForTheBestOne() throws {
        let danger = at(0, 2)
        let mover = try bot(0, .red, at: 10, 2)
        var mate = try bot(1, .red, at: 10, 3)
        let alone = try XCTUnwrap(Deliberation.away(from: danger, for: mover, in: situation([mover, mate])),
                                  "nowhere to flee to in an open strip")
        mate.action = .flee(to: alone)
        let second = try XCTUnwrap(Deliberation.away(from: danger, for: mover, in: situation([mover, mate])),
                                   "with one cell claimed there was nowhere to flee to at all")
        XCTAssertNotEqual(second, alone, "it fled to the cell its squadmate had set out for")
    }

    func testAdvancingTakesAnotherCellOnceASquadmateIsMakingForTheBestOne() throws {
        let believed = at(30, 2)
        let mover = try bot(0, .red, at: 10, 2)
        var mate = try bot(1, .red, at: 10, 3)
        var seen = situation([mover, mate])
        seen.enemyBelief = believed
        let alone = try XCTUnwrap(Deliberation.quiet(for: mover, in: seen), "nothing to do in an open strip")
        guard case .advance(let cell) = alone else { return XCTFail("it did not advance, it chose \(alone)") }
        mate.action = .advance(to: cell)
        seen = situation([mover, mate])
        seen.enemyBelief = believed
        let second = try XCTUnwrap(Deliberation.quiet(for: mover, in: seen), "with one cell claimed there was nothing to do")
        guard case .advance(let other) = second else { return XCTFail("it stopped advancing, it chose \(second)") }
        XCTAssertNotEqual(other, cell, "it advanced on the cell its squadmate had set out for")
    }

    func testExploringTakesAnotherCellOnceASquadmateIsMakingForTheBestOne() throws {
        var mover = try bot(0, .red, at: 10, 2)
        var mate = try bot(1, .red, at: 10, 3)
        // It knows the strip but for two cells to the east: one of them is what it goes
        // to see (FR-BOT-370), and its squadmate takes it first.
        let unseen = [node(14, 2), node(14, 3)]
        mover.knowledge.ways = Set(floor.graph.nodes).subtracting(unseen)
        mate.knowledge.ways = mover.knowledge.ways
        var seen = situation([mover, mate])
        let knows = mover.knowledge
        seen.knows = { knows.knows($0) }
        let alone = try XCTUnwrap(Deliberation.quiet(for: mover, in: seen), "nothing to do with a cell unseen")
        guard case .explore(let cell) = alone else { return XCTFail("it did not explore, it chose \(alone)") }
        mate.action = .explore(to: cell)
        seen = situation([mover, mate])
        seen.knows = { knows.knows($0) }
        let second = try XCTUnwrap(Deliberation.quiet(for: mover, in: seen), "with one cell claimed there was nothing to do")
        guard case .explore(let other) = second else { return XCTFail("it stopped exploring, it chose \(second)") }
        XCTAssertNotEqual(other, cell, "it went to see the cell its squadmate had set out for")
    }

    func testTakingCoverTakesAnotherCellOnceASquadmateIsMakingForTheBestOne() throws {
        // One crate in an open strip and the snake remembered to the west: the cells
        // behind the crate are the only ones it cannot see into, so two bots a step
        // apart both want the nearest of them.
        floor = try strip("....................",
                          "..........o.........",
                          "....................")
        let remembered = at(0, 1)
        var first = try bot(0, .red, at: 6, 1)
        let second = try bot(1, .red, at: 7, 1)
        let alone = try XCTUnwrap(Deliberation.cover(for: second, from: [remembered],
                                                     in: situation([first, second])),
                                  "nothing behind the one crate hid from the snake")
        first.action = .takeCover(at: alone.node)
        let other = try XCTUnwrap(Deliberation.cover(for: second, from: [remembered],
                                                     in: situation([first, second])),
                                  "with one cell claimed there was no cover at all")
        XCTAssertNotEqual(other.node, alone.node, "it took cover in the cell its squadmate had set out for")
    }

    /// The wiring, in a frame of the real thing: four bots deliberating one after
    /// another, each seeing what the ones before it chose. What it guards is that the
    /// exclusion leaves every bot something to do — a filter that took one cell too
    /// many would show here as a bot with nothing chosen — and that no two of them set
    /// out for one cell. On this arena they do not collide without the exclusion
    /// either: flight sends two bots standing apart to two different cells by
    /// construction, so this is a guard on the wiring and not a test of FR-BOT-530,
    /// which the cell searches above answer for.
    func testEveryBotStillChoosesAndNoTwoOfASquadSetOutForOneCell() throws {
        // Four bots behind one crate, in pairs placed either side of the crate's row so
        // that each pair stands the same distance from the one cell behind it and ranks
        // the cells identically: without the exclusion the pair sets out for one cell.
        //
        // The snake's sighting is a few seconds old, so the snake is something they know
        // of and not something they can shoot at (FR-BOT-220): all four are choosing
        // where to go.
        floor = try strip("....................",
                          "..........o.........",
                          "....................")
        let seen = 4.0
        var bots = [try bot(0, .red, at: 6, 0), try bot(1, .red, at: 6, 2),
                    try bot(2, .red, at: 7, 0), try bot(3, .red, at: 7, 2)]
        for index in bots.indices {
            bots[index].knowledge.snake[.zero] = Knowledge.Sighting(point: at(0, 1), time: .zero)
        }
        _ = Execution.deliberate(&bots, slots: bots.map(\.id), world: floor, now: seen)
        let goals = bots.compactMap { Execution.destination(of: $0) }
        XCTAssertEqual(goals.count, bots.count,
                       "a bot chose to stay where it was: \(bots.map(\.action))")
        XCTAssertEqual(Set(goals).count, goals.count, "two bots of one squad set out for the same cell: \(goals)")
    }
}
