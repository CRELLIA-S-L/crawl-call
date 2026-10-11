// Who is on the map when a match begins, and what each of them starts as: the set of
// archetypes (FR-BOT-010), the two squads (FR-BOT-020) at the island's two ends
// (FR-BOT-350), the personality an archetype hands its bot (FR-BOT-030), and which of
// them speaks for its squad (FR-BOT-040).
//
// file verifies: FR-BOT-010, FR-BOT-020, FR-BOT-350, FR-BOT-030, FR-BOT-040, INV-BOT-030
import XCTest
@testable import CrawlCall

final class ArchetypeTests: XCTestCase {
    func testThereAreExactlySixArchetypesAndTheyAreTheNamedOnes() {
        XCTAssertEqual(Set(Archetype.allCases.map(\.rawValue)),
                       ["assault", "heavy", "sapper", "scout", "sniper", "medic"])
        XCTAssertEqual(Archetype.allCases.count, 6)
    }

    func testEveryArchetypeHasAnEntryInTheShippedConfiguration() throws {
        // FR-BOT-030 initialises a bot from its archetype's entry, so an archetype the
        // configuration does not carry is a bot that cannot be spawned.
        let configuration = try Launch.world().get().configurations.bot
        for kind in Archetype.allCases {
            XCTAssertNotNil(configuration.archetypes[kind.rawValue], "\(kind.rawValue) has no entry")
        }
    }
}

final class SquadSpawnTests: XCTestCase {
    private func match() throws -> (world: World, start: NavigationGraph.Node, bots: [Bot]) {
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        return (world, start, Game(world: world, start: start).bots)
    }

    func testTwoSquadsOfTheConfiguredSizeAreSpawned() throws {
        let (world, _, bots) = try match()
        let size = world.configurations.match.squadSize
        XCTAssertEqual(bots.count, size * 2)
        XCTAssertEqual(bots.filter { $0.squad == .red }.count, size)
        XCTAssertEqual(bots.filter { $0.squad == .blue }.count, size)
    }

    func testTheSquadsAreHostileToEachOther() {
        XCTAssertEqual(Squad.red.enemy, .blue)
        XCTAssertEqual(Squad.blue.enemy, .red)
        XCTAssertEqual(Squad.allCases.count, 2)
    }

    func testEveryBotStandsOnAWalkableCellOfItsOwn() throws {
        let (world, _, bots) = try match()
        let cell = world.configurations.tuning.navigationGraphCellSize
        var occupied: Set<NavigationGraph.Node> = []
        for bot in bots {
            let node = NavigationGraph.Node(floor: bot.floor,
                                            x: Int((bot.position.x / cell).rounded()),
                                            z: Int((bot.position.z / cell).rounded()))
            XCTAssertTrue(world.graph.isWalkable(node), "bot \(bot.id) stands where nothing is walkable")
            XCTAssertTrue(occupied.insert(node).inserted, "two bots share a cell")
            XCTAssertEqual(bot.position.y, Double(bot.floor) * world.kit.floorHeight, accuracy: 1e-9)
        }
    }

    func testNoSquadStartsOnTopOfTheSnake() throws {
        // A match that begins with bots already inside the snake's interrupt distance
        // begins alarmed, and the stage's question is about the hunt rather than the
        // ambush. The number is the configuration's, not one invented here.
        let (world, start, bots) = try match()
        let cell = world.configurations.tuning.navigationGraphCellSize
        let snake = SIMD3(Double(start.x) * cell, Double(start.floor) * world.kit.floorHeight,
                          Double(start.z) * cell)
        for bot in bots {
            let apart = (bot.position - snake)
            let metres = (apart * apart).sum().squareRoot()
            XCTAssertGreaterThan(metres, world.configurations.bot.interruptDistance,
                                 "bot \(bot.id) of \(bot.squad) starts \(metres) m from the snake")
        }
    }

    func testTheSquadsDoNotStartOnTopOfEachOther() throws {
        // Measured across the room rather than along the walk, because the grouping
        // distance is in metres: the first rule counted graph steps and put both
        // squads on the same balcony, a long walk and four metres apart.
        let (world, _, bots) = try match()
        let wanted = world.configurations.bot.groupingDistance
        for red in bots where red.squad == .red {
            for blue in bots where blue.squad == .blue {
                let apart = Perception.metres(red.position, blue.position)
                XCTAssertGreaterThanOrEqual(apart, wanted,
                                            "bot \(red.id) and bot \(blue.id) start \(apart) m apart")
            }
        }
    }

    func testTheSquadsStartAtTheTwoEndsOfTheIslandTheRedOneFartherFromTheSnake() throws {
        // Worked out here over every pair rather than asked of `Squads`: the ends are
        // the two cells farthest apart across the ground among those the snake's start
        // reaches outside its interrupt distance.
        let (world, start, bots) = try match()
        let cell = world.configurations.tuning.navigationGraphCellSize
        let height = world.kit.floorHeight
        func at(_ node: NavigationGraph.Node) -> SIMD3<Double> { world.graph.centre(of: node, cellSize: cell, floorHeight: height) }
        func across(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { ((a.x - b.x) * (a.x - b.x) + (a.z - b.z) * (a.z - b.z)).squareRoot() }
        let snake = at(start)
        let cells = Squads.distances(in: world.graph, from: start).keys
            .filter { Perception.metres(at($0), snake) > world.configurations.bot.interruptDistance }
        var widest = 0.0
        for a in cells { for b in cells { widest = max(widest, across(at(a), at(b))) } }
        func node(of bot: Bot) -> NavigationGraph.Node {
            NavigationGraph.Node(floor: bot.floor, x: Int((bot.position.x / cell).rounded()), z: Int((bot.position.z / cell).rounded()))
        }
        let red = bots.filter { $0.squad == .red }
        let blue = bots.filter { $0.squad == .blue }
        // Each squad stands round its end: the two squads' own ends are the widest pair.
        var found = false
        for r in red { for b in blue where abs(across(at(node(of: r)), at(node(of: b))) - widest) < 1e-9 { found = true } }
        XCTAssertTrue(found, "no bot of either squad stands at an end of the island, \(widest) m apart")
        let middle = { (squad: [Bot]) in squad.map(\.position).reduce(.zero, +) / Double(squad.count) }
        XCTAssertGreaterThan(across(middle(red), snake), across(middle(blue), snake), "the red squad is not the farther one")
    }

    func testOnAStripWithTheSnakeOffCentreTheSquadsTakeBothEnds() throws {
        // The case the old placement got wrong: both squads went as far from the snake
        // as they could, and so to the same side of it.
        let shipped = try Launch.world().get()
        let rows = Array(repeating: String(repeating: ".", count: 80), count: 3)
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        let cell = shipped.configurations.tuning.navigationGraphCellSize
        let world = World(configurations: shipped.configurations, kit: shipped.kit, map: map, setting: shipped.setting,
                          graph: NavigationGraph.derive(from: map, stepHeight: shipped.configurations.tuning.stepHeight),
                          plan: ScenePlan.make(map: map, kit: shipped.kit, cellSize: cell))
        let bots = Squads.spawn(in: world, snakeStart: NavigationGraph.Node(floor: 0, x: 30, z: 1))
        let snakeX = 30 * cell
        let red = bots.filter { $0.squad == .red }
        let blue = bots.filter { $0.squad == .blue }
        XCTAssertFalse(red.isEmpty)
        XCTAssertFalse(blue.isEmpty)
        for bot in red { XCTAssertGreaterThan(bot.position.x, snakeX, "red bot \(bot.id) is not at the far end") }
        for bot in blue { XCTAssertLessThan(bot.position.x, snakeX, "blue bot \(bot.id) is on the red squad's side") }
        XCTAssertEqual(red.map(\.position.x).max() ?? 0, 79 * cell, accuracy: 1e-9)
        XCTAssertEqual(blue.map(\.position.x).min() ?? 0, 0, accuracy: 1e-9)
    }

    func testTheSameMapAlwaysGivesTheSameMatch() throws {
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        let first = Game(world: world, start: start).bots
        let again = Game(world: world, start: start).bots
        XCTAssertEqual(first, again)
    }

    func testABotCarriesItsArchetypesWeights() throws {
        let (world, _, bots) = try match()
        for bot in bots {
            let entry = try XCTUnwrap(world.configurations.bot.archetypes[bot.archetype.rawValue])
            XCTAssertEqual(bot.weights, entry.basePersonalityWeights,
                           "\(bot.archetype.rawValue) did not start from its own weights")
        }
    }

    func testTheArchetypesDifferFromOneAnother() throws {
        // The other half of FR-BOT-030: weights taken from a table where every row is
        // the same would satisfy the test above and mean nothing. Concept §8 gives the
        // directions — assault presses, the scout panics, the heavy holds.
        let configuration = try Launch.world().get().configurations.bot
        func weights(_ kind: Archetype) throws -> BotConfiguration.Weights {
            try XCTUnwrap(configuration.archetypes[kind.rawValue]).basePersonalityWeights
        }
        XCTAssertGreaterThan(try weights(.assault).aggression, try weights(.sapper).aggression)
        XCTAssertGreaterThan(try weights(.scout).panic, try weights(.heavy).panic)
        XCTAssertGreaterThan(try weights(.heavy).discipline, try weights(.assault).discipline)
        XCTAssertGreaterThan(try weights(.sniper).discipline, try weights(.sapper).discipline)
        XCTAssertGreaterThan(try weights(.medic).selfSacrifice, try weights(.assault).selfSacrifice)
        // Courage is not in the concept's table — it joined the weights afterwards
        // (FR-BOT-090) — so the directions are the behaviour column's: the heavy is
        // guarded and holds, the scout runs; the medic keeps behind the others.
        XCTAssertGreaterThan(try weights(.heavy).courage, try weights(.scout).courage)
        XCTAssertGreaterThan(try weights(.assault).courage, try weights(.medic).courage)
    }

    // MARK: who speaks for a squad (FR-BOT-040)

    /// The shipped match configuration with a different list of eligible archetypes,
    /// decoded through the real schema so that the test exercises the file's shape.
    private func matchConfiguration(eligible: [String]) throws -> MatchConfiguration {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "match", withExtension: "json",
                                                subdirectory: "config"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        json["commanderEligibleArchetypes"] = eligible
        return try Configurations.decode(MatchConfiguration.self, named: "match",
                                         schema: MatchConfiguration.schema,
                                         from: JSONSerialization.data(withJSONObject: json))
    }

    func testExactlyOneBotPerSquadHoldsTheCommanderRole() throws {
        let (_, _, bots) = try match()
        for squad in Squad.allCases {
            let holders = bots.filter { $0.squad == squad && $0.isCommander }
            XCTAssertEqual(holders.count, 1, "\(squad.name) has \(holders.count) commanders")
        }
    }

    func testTheShippedEmptyListAdmitsEveryArchetype() throws {
        // The shipped file names no archetype. Read as an allow-list of nothing it
        // would leave both squads voiceless; read as "no exclusions", as ADR-0011
        // puts it, every bot is eligible and the role lands on the first of them.
        let (world, _, bots) = try match()
        XCTAssertTrue(world.configurations.match.commanderEligibleArchetypes.isEmpty,
                      "this test is about the empty list; the shipped file now names archetypes")
        for squad in Squad.allCases {
            let holder = try XCTUnwrap(bots.first { $0.squad == squad && $0.isCommander })
            let lowest = try XCTUnwrap(bots.filter { $0.squad == squad }.map(\.id).min())
            XCTAssertEqual(holder.id, lowest)
        }
    }

    func testANamedListNarrowsWhoCanHoldTheRole() throws {
        // The scout and not the sniper, because a squad of the shipped size fields
        // neither sniper nor medic: archetypes are dealt round-robin and four cells
        // reach only the first four of the six.
        let (_, _, bots) = try match()
        let configuration = try matchConfiguration(eligible: [Archetype.scout.rawValue])
        for squad in Squad.allCases {
            let id = try XCTUnwrap(Squads.commander(of: squad, among: bots, configuration: configuration),
                                   "\(squad.name) has no scout to hold the role")
            let holder = try XCTUnwrap(bots.first { $0.id == id })
            XCTAssertEqual(holder.archetype, .scout)
            XCTAssertEqual(holder.squad, squad)
            XCTAssertNotEqual(holder.id, bots.filter { $0.squad == squad }.map(\.id).min(),
                              "the narrowed list moved the role off the first bot, or it never was on it")
        }
    }

    func testASquadWithNobodyEligibleHasNoCommander() throws {
        // A configuration that names an archetype the squad does not field. The
        // function says so rather than picking somebody anyway, and the caller
        // decides what it means (here: a squad that never speaks).
        let (_, _, bots) = try match()
        let configuration = try matchConfiguration(eligible: ["nobody-fields-this"])
        for squad in Squad.allCases {
            XCTAssertNil(Squads.commander(of: squad, among: bots, configuration: configuration))
        }
    }

    func testTheSameMatchDesignatesTheSameCommander() throws {
        // Spawning is deterministic (ADR-0056) and the role is part of it: a match set
        // up twice from the same world has the same voice.
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        let first = Game(world: world, start: start).bots.filter(\.isCommander).map(\.id)
        let again = Game(world: world, start: start).bots.filter(\.isCommander).map(\.id)
        XCTAssertEqual(first, again)
        XCTAssertEqual(first.count, 2)
    }

    func testTheRoleIsNotDrawn() throws {
        // FR-BOT-040 says the holder carries no visual mark, and ADR-0011 is why: a
        // marker makes the most valuable target the easiest to find.
        //
        // What holds it is structural — `Figure.parts` is handed an archetype and
        // never a bot, so there is nothing for a marker to branch on — and what this
        // test does is pin that signature: a figure built per bot would not compile
        // against it. The assertion underneath says the same thing in numbers: as
        // many distinct figures among the bots as there are archetypes among them,
        // which is what "the drawing is a function of the archetype" means.
        let (world, _, bots) = try match()
        let height = world.configurations.bot.figureHeight
        XCTAssertTrue(bots.contains(where: \.isCommander), "no commander to be unmarked")
        var figures: [[Figure.Part]] = []
        for bot in bots where !figures.contains(Figure.parts(for: bot.archetype, height: height)) {
            figures.append(Figure.parts(for: bot.archetype, height: height))
        }
        XCTAssertEqual(figures.count, Set(bots.map(\.archetype)).count)
    }

    func testBothSquadsAreDrawnFromTheOneArchetypeSet() throws {
        // INV-BOT-030 in the only form this step can check: the sides differ by colour
        // and nothing else, so the kinds present are the same on both sides.
        let (_, _, bots) = try match()
        let red = Set(bots.filter { $0.squad == .red }.map(\.archetype))
        let blue = Set(bots.filter { $0.squad == .blue }.map(\.archetype))
        XCTAssertEqual(red, blue)
        XCTAssertFalse(red.isEmpty)
    }
}
