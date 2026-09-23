// Who is on the map when a match begins, and what each of them starts as: the set of
// archetypes (FR-BOT-010), the two squads and their placement (FR-BOT-020), and the
// personality an archetype hands its bot (FR-BOT-030).
//
// verifies: FR-BOT-010, FR-BOT-020, FR-BOT-030, INV-BOT-030
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
        let start = try XCTUnwrap(Game.start(in: world))
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

    func testTheSameMapAlwaysGivesTheSameMatch() throws {
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.start(in: world))
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
