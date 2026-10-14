// The second act: the two cells the map names (FR-MAP-290, FR-MAP-300), the motive to
// go for the treasure and the motive to carry it (FR-BOT-620, FR-BOT-640), who picks it
// up and where it falls (FR-BOT-630, FR-BOT-650), the end it brings (FR-SCORE-160) and
// what is drawn of it (FR-VIEW-370).
//
// The rule the match runs each frame is `Treasure.step`, which takes the bots and
// nothing else, so the picking up, the dropping and the delivery are asked of it with
// bots put where the test wants them. The end of a match is asked of a real match, so
// that the outcome is one a match reaches and not a flag nothing sets.
//
// file verifies: FR-MAP-290, FR-MAP-300, FR-BOT-620, FR-BOT-630, FR-BOT-640, FR-BOT-650, FR-SCORE-160, FR-VIEW-370
import RealityKit
import XCTest
@testable import CrawlCall

/// The enemy a test puts in a bot's knowledge to make it believe one is still out
/// there: an id no bot of a one-a-side match has, so nothing else answers to it.
private let sightedEnemy = 99

/// A bot of the shipped configuration standing at a point, knowing what the test says
/// it knows.
private func soldier(id: Int, squad: Squad = .red, at position: SIMD3<Double>,
                     believesEnemyGone: Bool, in world: World,
                     file: StaticString = #filePath, line: UInt = #line) throws -> Bot {
    var bot = try XCTUnwrap(Bot(id: id, squad: squad, archetype: .assault, at: position, floor: 0,
                                configuration: world.configurations.bot),
                            "the configuration carries no assault archetype", file: file, line: line)
    if !believesEnemyGone {
        bot.knowledge.enemies = [sightedEnemy: Knowledge.Sighting(point: SIMD3(1, 0, 1), time: .zero)]
    }
    return bot
}

final class TreasureOnTheMapTests: XCTestCase {
    private func parse(_ text: String) throws -> MapSpecification {
        try MapParser.parse(text, kit: try Kit.load(named: "blockout", from: .main))
    }

    func testTheTreasureLiesInTheCellTheMapNames() throws {
        // FR-MAP-290: where the match starts it is where the map said, and not where
        // anybody was standing.
        let world = try world(map: "room", squadSize: 1)
        let game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        let named = try XCTUnwrap(world.map.treasure, "the room names no treasure")
        let node = NavigationGraph.Node(floor: named.floor, x: named.x, z: named.z)
        let centre = world.graph.centre(of: node, cellSize: world.configurations.tuning.navigationGraphCellSize,
                                        floorHeight: world.kit.floorHeight)
        let lying = try XCTUnwrap(game.treasure?.lying, "the match starts with no treasure lying anywhere")
        XCTAssertEqual(lying.point.x, centre.x, accuracy: 1e-9)
        XCTAssertEqual(lying.point.z, centre.z, accuracy: 1e-9)
        XCTAssertEqual(lying.floor, named.floor)
        XCTAssertEqual(game.treasure?.evacuation,
                       NavigationGraph.Node(floor: 0, x: 21, z: 14),
                       "the evacuation point is not the cell the room names")
    }

    func testAMapThatNamesNoTreasureIsRefused() throws {
        // FR-MAP-300, and the message says which of the two is missing.
        let map = try parse("kit blockout\nsetting greenholm\nspawn 0,0 0\nevacuation 1,0 0\nfloor 0\n..\n")
        XCTAssertThrowsError(try MapParser.requirePlaces(map)) { error in
            XCTAssertEqual(error as? MapParseError, .noTreasure)
        }
    }

    func testAMapThatNamesNoEvacuationPointIsRefused() throws {
        let map = try parse("kit blockout\nsetting greenholm\nspawn 0,0 0\ntreasure 0,0 0\nfloor 0\n..\n")
        XCTAssertThrowsError(try MapParser.requirePlaces(map)) { error in
            XCTAssertEqual(error as? MapParseError, .noEvacuation)
        }
    }

    func testATreasureNothingCanStandOnIsRefusedByItsLine() throws {
        // The wall is cell 0; the line named is the one that put the treasure there.
        let map = try parse("kit blockout\nsetting greenholm\nspawn 1,0 0\ntreasure 0,0 0\nevacuation 1,0 0\nfloor 0\n#.\n")
        XCTAssertThrowsError(try MapParser.requirePlaces(map)) { error in
            XCTAssertEqual(error as? MapParseError, .placeNotWalkable("treasure", line: 4))
        }
    }

    func testAnEvacuationPointNothingCanStandOnIsRefusedByItsLine() throws {
        let map = try parse("kit blockout\nsetting greenholm\nspawn 1,0 0\ntreasure 1,0 0\nevacuation 0,0 0\nfloor 0\n#.\n")
        XCTAssertThrowsError(try MapParser.requirePlaces(map)) { error in
            XCTAssertEqual(error as? MapParseError, .placeNotWalkable("evacuation", line: 5))
        }
    }

    func testACellWrittenWrongIsRefusedAsAPlace() throws {
        XCTAssertThrowsError(try parse("kit blockout\nsetting greenholm\ntreasure 1 0\nfloor 0\n..\n")) { error in
            XCTAssertEqual(error as? MapParseError, .badPlace("treasure 1 0", line: 3))
        }
    }

    func testAMapReadWithoutBeingPlayedNeedNameNeitherCell() throws {
        // The refusal is the launch's (FR-MAP-300), not the parser's: a tool that reads
        // a map to draw it does not need a second act.
        let map = try parse("kit blockout\nsetting greenholm\nfloor 0\n..\n")
        XCTAssertNil(map.treasure)
        XCTAssertNil(map.evacuation)
    }

    func testTheShippedArenaNamesBothCells() throws {
        // FR-MAP-300 over the map that is actually played, which is the one a refusal
        // would stop.
        let world = try Launch.world(map: "blockout").get()
        XCTAssertNoThrow(try MapParser.requirePlaces(world.map))
        let treasure = try XCTUnwrap(world.map.treasure)
        let evacuation = try XCTUnwrap(world.map.evacuation)
        XCTAssertNotEqual(NavigationGraph.Node(floor: treasure.floor, x: treasure.x, z: treasure.z),
                          NavigationGraph.Node(floor: evacuation.floor, x: evacuation.x, z: evacuation.z),
                          "the treasure is already at the evacuation point, so there is no second act")
        // The snake is born near the treasure and not on it (concept §6.4): the map's
        // doing, which is why this is read off the map and not off a number.
        let cell = world.configurations.tuning.navigationGraphCellSize
        let lies = world.graph.centre(of: .init(floor: treasure.floor, x: treasure.x, z: treasure.z),
                                      cellSize: cell, floorHeight: world.kit.floorHeight)
        for spawn in world.map.spawns {
            let born = world.graph.centre(of: .init(floor: spawn.floor, x: spawn.x, z: spawn.z),
                                          cellSize: cell, floorHeight: world.kit.floorHeight)
            let metres = Perception.metres(born, lies)
            XCTAssertGreaterThan(metres, world.configurations.bot.overrideDistance * 0.5,
                                 "the snake is born on top of the treasure")
            XCTAssertLessThan(metres, Perception.metres(world.plan.bounds.lowest, world.plan.bounds.highest) / 2,
                              "the snake is born on the other side of the arena from the treasure")
        }
    }
}

final class TakingTheTreasureTests: XCTestCase {
    /// The cell a bot stands in, as the match reads it.
    private func cell(_ world: World) -> (Bot) -> NavigationGraph.Node {
        { Execution.cell(of: $0, world: world) }
    }
    private func cellOf(_ world: World) -> (SIMD3<Double>) -> NavigationGraph.Node? {
        { Deliberation.cell(of: $0, graph: world.graph,
                            cellSize: world.configurations.tuning.navigationGraphCellSize,
                            floorHeight: world.kit.floorHeight) }
    }

    /// A treasure lying in a cell of the room, with the evacuation point elsewhere.
    private func treasure(in world: World, at node: NavigationGraph.Node) -> Treasure {
        Treasure(place: .lying(at: world.graph.centre(of: node,
                                                      cellSize: world.configurations.tuning.navigationGraphCellSize,
                                                      floorHeight: world.kit.floorHeight),
                               floor: node.floor),
                 evacuation: NavigationGraph.Node(floor: 0, x: 21, z: 14))
    }

    func testABotStandingOnItThatBelievesTheEnemyGoneCarriesIt() throws {
        // FR-BOT-630.
        let world = try world(map: "room", squadSize: 1)
        let node = NavigationGraph.Node(floor: 0, x: 12, z: 7)
        var prize = treasure(in: world, at: node)
        let lying = try XCTUnwrap(prize.lying)
        let bot = try soldier(id: 3, at: lying.point, believesEnemyGone: true, in: world)
        var held: (point: SIMD3<Double>, floor: Int)?
        XCTAssertFalse(prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world), held: &held))
        XCTAssertEqual(prize.carrier, 3)
    }

    func testABotThatStillBelievesAnEnemyAliveLeavesItWhereItLies() throws {
        // The negation of FR-BOT-630's condition, which is FR-BOT-620's: the treasure
        // is the prize for a won war, and a bot that walks over it in the middle of one
        // leaves it alone.
        let world = try world(map: "room", squadSize: 1)
        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 12, z: 7))
        let lying = try XCTUnwrap(prize.lying)
        let bot = try soldier(id: 3, at: lying.point, believesEnemyGone: false, in: world)
        var held: (point: SIMD3<Double>, floor: Int)?
        XCTAssertFalse(prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world), held: &held))
        XCTAssertNil(prize.carrier)
    }

    func testABotStandingElsewhereDoesNotReachIt() throws {
        let world = try world(map: "room", squadSize: 1)
        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 12, z: 7))
        let bot = try soldier(id: 3, at: SIMD3(1, 0, 1), believesEnemyGone: true, in: world)
        var held: (point: SIMD3<Double>, floor: Int)?
        XCTAssertFalse(prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world), held: &held))
        XCTAssertNil(prize.carrier)
    }

    func testTheLowestIdOfThoseStandingOnItTakesIt() throws {
        // Two bots in one cell is what FR-BOT-300 allows for a moment; which of them
        // takes it has to be the same twice over.
        let world = try world(map: "room", squadSize: 1)
        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 12, z: 7))
        let lying = try XCTUnwrap(prize.lying)
        let bots = [try soldier(id: 5, at: lying.point, believesEnemyGone: true, in: world),
                    try soldier(id: 2, at: lying.point, believesEnemyGone: true, in: world)]
        var held: (point: SIMD3<Double>, floor: Int)?
        _ = prize.step(among: bots, cell: cell(world), cellOf: cellOf(world), held: &held)
        XCTAssertEqual(prize.carrier, 2)
    }

    func testTheTreasureFallsWhereItsCarrierFalls() throws {
        // FR-BOT-650: not back in the cell the map named, and not where it was going.
        let world = try world(map: "room", squadSize: 1)
        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 12, z: 7))
        let lying = try XCTUnwrap(prize.lying)
        var bot = try soldier(id: 3, at: lying.point, believesEnemyGone: true, in: world)
        var held: (point: SIMD3<Double>, floor: Int)?
        _ = prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world), held: &held)
        XCTAssertEqual(prize.carrier, 3)

        bot.position = SIMD3(2.5, 0, 3.5)
        _ = prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world), held: &held)
        bot.health = .zero
        _ = prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world), held: &held)
        let fallen = try XCTUnwrap(prize.lying, "the treasure is still being carried by a dead bot")
        XCTAssertEqual(fallen.point.x, 2.5, accuracy: 1e-9)
        XCTAssertEqual(fallen.point.z, 3.5, accuracy: 1e-9)
        XCTAssertNotEqual(fallen.point, lying.point, "the treasure went back to where it began")
    }

    func testATreasureFallsWhereACarrierTheSnakeAteStood() throws {
        // A bot the snake finishes eating leaves the arena, so there is nobody to ask
        // where it fell: the treasure falls where it stood as the frame began.
        let world = try world(map: "room", squadSize: 1)
        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 12, z: 7))
        let lying = try XCTUnwrap(prize.lying)
        let bot = try soldier(id: 3, at: lying.point, believesEnemyGone: true, in: world)
        var held: (point: SIMD3<Double>, floor: Int)?
        _ = prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world), held: &held)
        _ = prize.step(among: [], cell: cell(world), cellOf: cellOf(world), held: &held)
        let fallen = try XCTUnwrap(prize.lying, "a treasure whose carrier was eaten is nowhere")
        XCTAssertEqual(fallen.point, lying.point)
    }

    func testTheNextBotThatMayPicksUpATreasureThatWasDropped() throws {
        // FR-BOT-630 again, over a treasure that is no longer in the cell the map named.
        let world = try world(map: "room", squadSize: 1)
        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 12, z: 7))
        let lying = try XCTUnwrap(prize.lying)
        var carrier = try soldier(id: 3, at: lying.point, believesEnemyGone: true, in: world)
        var held: (point: SIMD3<Double>, floor: Int)?
        _ = prize.step(among: [carrier], cell: cell(world), cellOf: cellOf(world), held: &held)
        carrier.position = SIMD3(2.5, 0, 3.5)
        _ = prize.step(among: [carrier], cell: cell(world), cellOf: cellOf(world), held: &held)
        carrier.health = .zero
        _ = prize.step(among: [carrier], cell: cell(world), cellOf: cellOf(world), held: &held)

        let next = try soldier(id: 4, at: SIMD3(2.5, 0, 3.5), believesEnemyGone: true, in: world)
        _ = prize.step(among: [carrier, next], cell: cell(world), cellOf: cellOf(world), held: &held)
        XCTAssertEqual(prize.carrier, 4)
    }

    func testTheCarrierOnTheEvacuationPointHasCarriedItOff() throws {
        // FR-SCORE-160, as the rule reports it: the match reads the flag and ends.
        let world = try world(map: "room", squadSize: 1)
        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 12, z: 7))
        let lying = try XCTUnwrap(prize.lying)
        var bot = try soldier(id: 3, at: lying.point, believesEnemyGone: true, in: world)
        var held: (point: SIMD3<Double>, floor: Int)?
        _ = prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world), held: &held)

        let out = world.graph.centre(of: prize.evacuation,
                                     cellSize: world.configurations.tuning.navigationGraphCellSize,
                                     floorHeight: world.kit.floorHeight)
        bot.position = out
        XCTAssertTrue(prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world), held: &held))
        XCTAssertEqual(prize.place, .carriedOff)
    }

    func testATreasureOnTheEvacuationPointThatNobodyCarriesIsNotCarriedOff() throws {
        // The negation: it is the carrying that ends the match, not the lying there.
        let world = try world(map: "room", squadSize: 1)
        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 21, z: 14))
        var held: (point: SIMD3<Double>, floor: Int)?
        XCTAssertFalse(prize.step(among: [], cell: cell(world), cellOf: cellOf(world), held: &held))
        XCTAssertNotEqual(prize.place, .carriedOff)
    }
}

final class TreasureMotiveTests: XCTestCase {
    private func situation(in world: World) -> Deliberation.Situation {
        Deliberation.Situation(plan: world.plan, graph: world.graph,
                               configuration: world.configurations.bot,
                               cellSize: world.configurations.tuning.navigationGraphCellSize)
    }

    func testABotThatBelievesTheEnemyGoneIsOfferedTheTreasure() throws {
        // FR-BOT-620.
        let world = try world(map: "room", squadSize: 1)
        let bot = try soldier(id: 1, at: SIMD3(1, 0, 1), believesEnemyGone: true, in: world)
        var facts = situation(in: world)
        facts.believesEnemyGone = true
        facts.treasure = NavigationGraph.Node(floor: 0, x: 12, z: 7)
        facts.evacuation = NavigationGraph.Node(floor: 0, x: 21, z: 14)
        let scored = Deliberation.scores(for: bot, in: facts)
        let take = scored.first { $0.action == .takeTreasure(at: NavigationGraph.Node(floor: 0, x: 12, z: 7)) }
        XCTAssertNotNil(take, "a bot with nobody left to fight was not offered the treasure")
        XCTAssertGreaterThan(try XCTUnwrap(take).utility, .zero,
                             "going for the treasure scored nothing, so the quiet motives win")
    }

    func testABotThatBelievesAnEnemyAliveIsNotOfferedTheTreasure() throws {
        // The condition of FR-BOT-620, which is what keeps the first act unchanged.
        let world = try world(map: "room", squadSize: 1)
        let bot = try soldier(id: 1, at: SIMD3(1, 0, 1), believesEnemyGone: false, in: world)
        var facts = situation(in: world)
        facts.believesEnemyGone = false
        facts.treasure = NavigationGraph.Node(floor: 0, x: 12, z: 7)
        facts.evacuation = NavigationGraph.Node(floor: 0, x: 21, z: 14)
        XCTAssertNil(Deliberation.scores(for: bot, in: facts).first {
            if case .takeTreasure = $0.action { return true }
            return false
        })
    }

    func testATreasureSomebodyElseCarriesIsNotOffered() throws {
        // There is one treasure and one carrier: a bot that is not it has nothing to
        // take, which the situation says by holding no cell it lies in.
        let world = try world(map: "room", squadSize: 1)
        let bot = try soldier(id: 1, at: SIMD3(1, 0, 1), believesEnemyGone: true, in: world)
        var facts = situation(in: world)
        facts.believesEnemyGone = true
        facts.evacuation = NavigationGraph.Node(floor: 0, x: 21, z: 14)
        let scored = Deliberation.scores(for: bot, in: facts)
        XCTAssertNil(scored.first {
            if case .takeTreasure = $0.action { return true }
            if case .carryTreasure = $0.action { return true }
            return false
        })
    }

    func testTheCarrierIsOfferedTheEvacuationPointAndNotTheTreasure() throws {
        // FR-BOT-640: the one motive a bot holding it has.
        let world = try world(map: "room", squadSize: 1)
        let bot = try soldier(id: 1, at: SIMD3(1, 0, 1), believesEnemyGone: true, in: world)
        var facts = situation(in: world)
        facts.believesEnemyGone = true
        facts.carriesTreasure = true
        facts.treasure = nil
        facts.evacuation = NavigationGraph.Node(floor: 0, x: 21, z: 14)
        let scored = Deliberation.scores(for: bot, in: facts)
        let carry = scored.first { $0.action == .carryTreasure(to: NavigationGraph.Node(floor: 0, x: 21, z: 14)) }
        XCTAssertNotNil(carry, "the bot carrying the treasure was not offered the way out")
        XCTAssertGreaterThan(try XCTUnwrap(carry).utility, .zero)
        XCTAssertNil(scored.first {
            if case .takeTreasure = $0.action { return true }
            return false
        })
    }

    func testADisciplinedCarrierIsWorthMoreThanAnUndisciplinedOne() throws {
        // FR-BOT-640 scores by the same weights as everything else (concept §9.2):
        // a disciplined bot carries it under fire, an undisciplined one is easier to
        // pull off the job by anything else that scores.
        let world = try world(map: "room", squadSize: 1)
        var facts = situation(in: world)
        facts.believesEnemyGone = true
        facts.carriesTreasure = true
        facts.evacuation = NavigationGraph.Node(floor: 0, x: 21, z: 14)
        func weights(discipline: Double) -> BotConfiguration.Weights {
            BotConfiguration.Weights(panic: 0.5, discipline: discipline, aggression: 0.5,
                                     selfSacrifice: 0.5, courage: 0.5)
        }
        var keen = try soldier(id: 1, at: SIMD3(1, 0, 1), believesEnemyGone: true, in: world)
        keen.weights = weights(discipline: 0.9)
        var slack = keen
        slack.weights = weights(discipline: 0.1)
        func worth(_ bot: Bot) throws -> Double {
            try XCTUnwrap(Deliberation.scores(for: bot, in: facts).first {
                if case .carryTreasure = $0.action { return true }
                return false
            }).utility
        }
        XCTAssertGreaterThan(try worth(keen), try worth(slack))
    }

    func testABotThatKnowsOfNoEnemyAndHasSweptTheirGroundBelievesThemGone() throws {
        // What FR-BOT-620 is checked against: the knowledge a bot already keeps, so
        // that a squad can believe it and be wrong.
        var knowledge = Knowledge()
        knowledge.enemyStart = Knowledge.Area(centre: SIMD3(1, 0, 1), radius: 2)
        XCTAssertFalse(knowledge.believesEnemyGone, "a squad that has not been to the enemy's ground believes it won")
        knowledge.enemyStart = nil
        XCTAssertTrue(knowledge.believesEnemyGone)
        knowledge.enemies = [sightedEnemy: Knowledge.Sighting(point: SIMD3(3, 0, 3), time: .zero)]
        XCTAssertFalse(knowledge.believesEnemyGone, "a sighting it has not been to is an enemy it believes alive")
        knowledge.notFound(enemy: sightedEnemy, at: 1)
        XCTAssertTrue(knowledge.believesEnemyGone, "a sighting gone to and found empty still counts as an enemy")
    }
}

@MainActor
final class TreasureOnScreenTests: XCTestCase {
    func testTheTreasureIsDrawnWhereItLies() throws {
        // FR-VIEW-370: above the point it lies at, by half its own height.
        let prize = Treasure(place: .lying(at: SIMD3(2, 0.5, 3), floor: 0),
                             evacuation: NavigationGraph.Node(floor: 0, x: 21, z: 14))
        let box = TreasureEntity.make()
        TreasureEntity.update(box, treasure: prize, bots: [])
        XCTAssertTrue(box.isEnabled)
        XCTAssertEqual(Double(box.position.x), 2, accuracy: 1e-5)
        XCTAssertEqual(Double(box.position.y), 0.5 + Prize.lift, accuracy: 1e-5)
        XCTAssertEqual(Double(box.position.z), 3, accuracy: 1e-5)
    }

    func testTheTreasureIsDrawnAtTheBotCarryingIt() throws {
        let world = try world(map: "room", squadSize: 1)
        var bot = try soldier(id: 6, at: SIMD3(4, 0, 5), believesEnemyGone: true, in: world)
        bot.facing = .zero
        let prize = Treasure(place: .carried(by: 6),
                             evacuation: NavigationGraph.Node(floor: 0, x: 21, z: 14))
        let box = TreasureEntity.make()
        TreasureEntity.update(box, treasure: prize, bots: [bot])
        XCTAssertTrue(box.isEnabled)
        XCTAssertEqual(Double(box.position.x), 4, accuracy: 1e-5)
        XCTAssertEqual(Double(box.position.y), Prize.heldAt, accuracy: 1e-5)
        XCTAssertEqual(Double(box.position.z), 5 + Prize.heldAhead, accuracy: 1e-5,
                       "the treasure is not held ahead of the way its carrier faces")
    }

    func testNothingIsDrawnOnceItHasBeenCarriedOff() throws {
        let prize = Treasure(place: .carriedOff, evacuation: NavigationGraph.Node(floor: 0, x: 21, z: 14))
        let box = TreasureEntity.make()
        box.isEnabled = true
        TreasureEntity.update(box, treasure: prize, bots: [])
        XCTAssertFalse(box.isEnabled)
    }

    func testNothingIsDrawnOnAMapThatNamesNoTreasure() throws {
        let box = TreasureEntity.make()
        box.isEnabled = true
        TreasureEntity.update(box, treasure: nil, bots: [])
        XCTAssertFalse(box.isEnabled)
    }

    func testThePlateNamesTheEndTheTreasureBrings() throws {
        // FR-VIEW-190 over the third end: its own line, not one of the other two.
        XCTAssertEqual(MatchEnd.headline(for: .treasureTaken), .matchEndTreasureTaken)
        XCTAssertNotEqual(MatchEnd.headline(for: .treasureTaken), MatchEnd.headline(for: .arenaEmpty))
        XCTAssertNotEqual(MatchEnd.headline(for: .treasureTaken), MatchEnd.headline(for: .snakeDied))
    }
}

final class SecondActTests: XCTestCase {
    func testASquadThatBelievesItHasWonCarriesTheTreasureOffAndEndsTheMatch() throws {
        // The whole slice through a real match, with nobody steering the snake: one bot
        // a side fight, the survivor sweeps the ground it believed the enemy held, goes
        // for the treasure (FR-BOT-620, FR-BOT-630) and carries it to the evacuation
        // point (FR-BOT-640), which ends the match (FR-SCORE-160).
        //
        // One a side, because what this asks is whether the second act happens at all,
        // and the first act of a full match is decided by numbers this test is not
        // about. Three minutes of match time: longer than it takes, and short of the
        // run being a measurement.
        let world = try world(map: "room", squadSize: 1)
        var game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        let frame = 1.0 / 60
        var carried = false
        for _ in 0..<10_800 where game.outcome == nil {
            _ = game.advance(seconds: frame)
            if game.treasure?.carrier != nil { carried = true }
        }
        XCTAssertTrue(carried, "nobody ever picked the treasure up")
        XCTAssertEqual(game.outcome, .treasureTaken,
                       "the match ended some other way than with the treasure carried off")
        XCTAssertEqual(game.treasure?.place, .carriedOff)

        // And the next match has it back where the map says, as FR-VIEW-190 asks of
        // everything a match changes.
        let again = game.restarted()
        let lying = try XCTUnwrap(again.treasure?.lying, "the new match starts with no treasure")
        let named = try XCTUnwrap(world.map.treasure)
        let centre = world.graph.centre(of: .init(floor: named.floor, x: named.x, z: named.z),
                                        cellSize: world.configurations.tuning.navigationGraphCellSize,
                                        floorHeight: world.kit.floorHeight)
        XCTAssertEqual(lying.point.x, centre.x, accuracy: 1e-9)
        XCTAssertEqual(lying.point.z, centre.z, accuracy: 1e-9)
        XCTAssertNil(again.outcome)
    }
}
