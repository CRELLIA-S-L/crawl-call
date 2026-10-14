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
// file verifies: FR-MAP-290, FR-MAP-300, FR-BOT-620, FR-BOT-630, FR-BOT-640, FR-BOT-650, FR-SCORE-160, FR-VIEW-370, FR-BOT-670, FR-BOT-680, FR-BOT-690, FR-BOT-700, FR-BOT-710, FR-BOT-720
import RealityKit
import XCTest
@testable import CrawlCall

/// The enemy a test puts in a bot's knowledge so that it holds an enemy it believes
/// alive: an id no bot of a one-a-side match has, so nothing else answers to it.
private let sightedEnemy = 99

/// A bot of the shipped configuration standing at a point, knowing what the test says
/// it knows.
private func soldier(id: Int, squad: Squad = .red, at position: SIMD3<Double>,
                     sightingAnEnemy: Bool = false, in world: World,
                     file: StaticString = #filePath, line: UInt = #line) throws -> Bot {
    var bot = try XCTUnwrap(Bot(id: id, squad: squad, archetype: .assault, at: position, floor: 0,
                                configuration: world.configurations.bot),
                            "the configuration carries no assault archetype", file: file, line: line)
    if sightingAnEnemy {
        bot.knowledge.enemies = [sightedEnemy: Knowledge.Sighting(point: SIMD3(1, 0, 1), time: .zero)]
    }
    return bot
}

/// The shipped assault's weights with greed and discipline said out loud: the two the
/// prize is weighed between while a squad is in a fight (FR-BOT-700, FR-BOT-720).
private func minded(_ bot: Bot, greed: Double, discipline: Double) -> Bot {
    var minded = bot
    minded.weights = BotConfiguration.Weights(panic: bot.weights.panic, discipline: discipline,
                                              aggression: bot.weights.aggression,
                                              selfSacrifice: bot.weights.selfSacrifice,
                                              courage: bot.weights.courage, greed: greed)
    return minded
}

/// What the match asks of every bot each frame: who may have the prize in its hands
/// (FR-BOT-700, FR-BOT-720), built exactly as `Game` builds it.
private func mayHold(alarmed: Set<Squad>, underOrders: Bool = false) -> (Bot) -> Bool {
    { bot in
        !alarmed.contains(bot.squad) || Deliberation.keepsThePrize(bot, underOrders: underOrders)
    }
}

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
    func testABotStandingOnItThatBelievesTheEnemyGoneCarriesIt() throws {
        // FR-BOT-630.
        let world = try world(map: "room", squadSize: 1)
        let node = NavigationGraph.Node(floor: 0, x: 12, z: 7)
        var prize = treasure(in: world, at: node)
        let lying = try XCTUnwrap(prize.lying)
        let bot = try soldier(id: 3, at: lying.point, in: world)
        var held: (point: SIMD3<Double>, floor: Int)?
        XCTAssertFalse(prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world), held: &held))
        XCTAssertEqual(prize.carrier, 3)
    }

    func testABotThatStillBelievesAnEnemyAliveTakesItAllTheSame() throws {
        // FR-BOT-630 asks nothing about the enemy since the maintainer's rule of
        // 2026-10-14: the treasure is what the fight is for, so a bot that walks over it
        // in the middle of one picks it up.
        let world = try world(map: "room", squadSize: 1)
        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 12, z: 7))
        let lying = try XCTUnwrap(prize.lying)
        let bot = try soldier(id: 3, at: lying.point, sightingAnEnemy: true, in: world)
        var held: (point: SIMD3<Double>, floor: Int)?
        XCTAssertFalse(prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world), held: &held))
        XCTAssertEqual(prize.carrier, 3, "a bot standing on the treasure left it lying")
    }

    func testABotStandingElsewhereDoesNotReachIt() throws {
        let world = try world(map: "room", squadSize: 1)
        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 12, z: 7))
        let bot = try soldier(id: 3, at: SIMD3(1, 0, 1), in: world)
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
        let bots = [try soldier(id: 5, at: lying.point, in: world),
                    try soldier(id: 2, at: lying.point, in: world)]
        var held: (point: SIMD3<Double>, floor: Int)?
        _ = prize.step(among: bots, cell: cell(world), cellOf: cellOf(world), held: &held)
        XCTAssertEqual(prize.carrier, 2)
    }

    func testTheTreasureFallsWhereItsCarrierFalls() throws {
        // FR-BOT-650: not back in the cell the map named, and not where it was going.
        let world = try world(map: "room", squadSize: 1)
        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 12, z: 7))
        let lying = try XCTUnwrap(prize.lying)
        var bot = try soldier(id: 3, at: lying.point, in: world)
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
        let bot = try soldier(id: 3, at: lying.point, in: world)
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
        var carrier = try soldier(id: 3, at: lying.point, in: world)
        var held: (point: SIMD3<Double>, floor: Int)?
        _ = prize.step(among: [carrier], cell: cell(world), cellOf: cellOf(world), held: &held)
        carrier.position = SIMD3(2.5, 0, 3.5)
        _ = prize.step(among: [carrier], cell: cell(world), cellOf: cellOf(world), held: &held)
        carrier.health = .zero
        _ = prize.step(among: [carrier], cell: cell(world), cellOf: cellOf(world), held: &held)

        let next = try soldier(id: 4, at: SIMD3(2.5, 0, 3.5), in: world)
        _ = prize.step(among: [carrier, next], cell: cell(world), cellOf: cellOf(world), held: &held)
        XCTAssertEqual(prize.carrier, 4)
    }

    func testTheCarrierOnTheEvacuationPointHasCarriedItOff() throws {
        // FR-SCORE-160, as the rule reports it: the match reads the flag and ends.
        let world = try world(map: "room", squadSize: 1)
        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 12, z: 7))
        let lying = try XCTUnwrap(prize.lying)
        var bot = try soldier(id: 3, at: lying.point, in: world)
        var held: (point: SIMD3<Double>, floor: Int)?
        _ = prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world), held: &held)

        let out = world.graph.centre(of: prize.evacuation,
                                     cellSize: world.configurations.tuning.navigationGraphCellSize,
                                     floorHeight: world.kit.floorHeight)
        bot.position = out
        XCTAssertTrue(prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world), held: &held))
        XCTAssertEqual(prize.place, .carriedOff)
    }

    func testAThreatTheSquadSeesPutsTheTreasureDown() throws {
        // FR-BOT-700: the crew finds somebody to fight, the prize goes down where the
        // carrier stands, and that bot does not pick it up again while it lasts. The
        // shipped assault is the ordinary case — greed 0.5 against discipline 0.5, so
        // its greed does not outweigh its sense of the job (FR-BOT-720).
        let world = try world(map: "room", squadSize: 1)
        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 12, z: 7))
        let lying = try XCTUnwrap(prize.lying)
        let bot = try soldier(id: 3, at: lying.point, in: world)
        var held: (point: SIMD3<Double>, floor: Int)?
        _ = prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world), held: &held)
        XCTAssertEqual(prize.carrier, bot.id, "it never picked the prize up, so this proves nothing")

        _ = prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world),
                       mayHold: mayHold(alarmed: [bot.squad]), held: &held)
        XCTAssertNil(prize.carrier, "it held on to the prize while its crew had a fight on")
        XCTAssertEqual(prize.lying?.point, bot.position, "the prize did not land where the carrier stood")

        _ = prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world),
                       mayHold: mayHold(alarmed: [bot.squad]), held: &held)
        XCTAssertNil(prize.carrier, "it picked the prize straight back up in the middle of a fight")

        _ = prize.step(among: [bot], cell: cell(world), cellOf: cellOf(world), held: &held)
        XCTAssertEqual(prize.carrier, bot.id, "the fighting was over and nobody picked the prize up")
    }

    func testACarrierOnThePointWaitsWhileOneOfTheOtherCrewIsUp() throws {
        // FR-SCORE-160 since 2026-10-14: reaching the point is not leaving with it.
        let world = try world(map: "room", squadSize: 1)
        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 12, z: 7))
        let lying = try XCTUnwrap(prize.lying)
        var bot = try soldier(id: 3, at: lying.point, in: world)
        var rival = try soldier(id: 4, squad: .blue, at: SIMD3(1, 0, 1), in: world)
        var held: (point: SIMD3<Double>, floor: Int)?
        _ = prize.step(among: [bot, rival], cell: cell(world), cellOf: cellOf(world), held: &held)
        bot.position = world.graph.centre(of: prize.evacuation,
                                          cellSize: world.configurations.tuning.navigationGraphCellSize,
                                          floorHeight: world.kit.floorHeight)

        XCTAssertFalse(prize.step(among: [bot, rival], cell: cell(world), cellOf: cellOf(world), held: &held),
                       "it left with the prize while one of the other crew was still up")
        XCTAssertEqual(prize.carrier, bot.id, "it stopped carrying the prize while it waited")

        rival.health = .zero
        XCTAssertTrue(prize.step(among: [bot, rival], cell: cell(world), cellOf: cellOf(world), held: &held),
                      "the last of the other crew was down and it still did not leave")
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
        var facts = Deliberation.Situation(plan: world.plan, graph: world.graph,
                                           configuration: world.configurations.bot,
                                           cellSize: world.configurations.tuning.navigationGraphCellSize)
        // What the nearness of the prize is measured against (FR-BOT-620), as the match
        // sets it for every bot.
        facts.arenaSpan = Perception.metres(world.plan.bounds.lowest, world.plan.bounds.highest)
        return facts
    }

    func testABotIsOfferedTheTreasureWhileItLies() throws {
        // FR-BOT-620.
        let world = try world(map: "room", squadSize: 1)
        let bot = try soldier(id: 1, at: SIMD3(1, 0, 1), in: world)
        var facts = situation(in: world)
        facts.treasure = NavigationGraph.Node(floor: 0, x: 12, z: 7)
        facts.evacuation = NavigationGraph.Node(floor: 0, x: 21, z: 14)
        let scored = Deliberation.scores(for: bot, in: facts)
        let take = scored.first { $0.action == .takeTreasure(at: NavigationGraph.Node(floor: 0, x: 12, z: 7)) }
        XCTAssertNotNil(take, "a bot was not offered the treasure lying in front of it")
        XCTAssertGreaterThan(try XCTUnwrap(take).utility, .zero,
                             "going for the treasure scored nothing, so the quiet motives win")
    }

    func testABotThatBelievesAnEnemyAliveIsOfferedItAllTheSame() throws {
        // The rule of 2026-10-14 in one test: the first act is no longer kept clear of
        // the prize, so a bot that holds a sighting it has not been to is offered it.
        let world = try world(map: "room", squadSize: 1)
        let bot = try soldier(id: 1, at: SIMD3(1, 0, 1), sightingAnEnemy: true, in: world)
        var facts = situation(in: world)
        facts.treasure = NavigationGraph.Node(floor: 0, x: 12, z: 7)
        facts.evacuation = NavigationGraph.Node(floor: 0, x: 21, z: 14)
        let take = Deliberation.scores(for: bot, in: facts).first {
            if case .takeTreasure = $0.action { return true }
            return false
        }
        XCTAssertNotNil(take, "an enemy it believes alive kept the treasure off its list")
        XCTAssertGreaterThan(try XCTUnwrap(take).utility, .zero)
    }

    func testATreasureSomebodyElseCarriesIsNotOffered() throws {
        // There is one treasure and one carrier: a bot that is not it has nothing to
        // take, which the situation says by holding no cell it lies in.
        let world = try world(map: "room", squadSize: 1)
        let bot = try soldier(id: 1, at: SIMD3(1, 0, 1), in: world)
        var facts = situation(in: world)
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
        let bot = try soldier(id: 1, at: SIMD3(1, 0, 1), in: world)
        var facts = situation(in: world)
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
        facts.carriesTreasure = true
        facts.evacuation = NavigationGraph.Node(floor: 0, x: 21, z: 14)
        func weights(discipline: Double) -> BotConfiguration.Weights {
            BotConfiguration.Weights(panic: 0.5, discipline: discipline, aggression: 0.5,
                                     selfSacrifice: 0.5, courage: 0.5, greed: 0.5)
        }
        var keen = try soldier(id: 1, at: SIMD3(1, 0, 1), in: world)
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
        var bot = try soldier(id: 6, at: SIMD3(4, 0, 5), in: world)
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

/// What a fight does to the prize: what it is worth to a bot while its crew can see
/// something (FR-BOT-690), what a standing order leaves of that (FR-BOT-710), who may
/// hold it (FR-BOT-700, FR-BOT-720), and what carrying it costs a bot's hands
/// (FR-BOT-670) and legs (FR-BOT-680).
final class TreasureUnderFireTests: XCTestCase {
    /// A bot standing a little way off the prize, with the view clear.
    private func facts(in world: World) -> Deliberation.Situation {
        var facts = Deliberation.Situation(plan: world.plan, graph: world.graph,
                                           configuration: world.configurations.bot,
                                           cellSize: world.configurations.tuning.navigationGraphCellSize)
        facts.arenaSpan = Perception.metres(world.plan.bounds.lowest, world.plan.bounds.highest)
        facts.treasure = NavigationGraph.Node(floor: 0, x: 12, z: 7)
        facts.evacuation = NavigationGraph.Node(floor: 0, x: 21, z: 14)
        return facts
    }

    /// What going for the prize, or carrying it, is worth to a bot in a situation —
    /// nil where it is not offered at all.
    private func prize(for bot: Bot, in facts: Deliberation.Situation) -> Double? {
        Deliberation.scores(for: bot, in: facts).first {
            if case .takeTreasure = $0.action { return true }
            if case .carryTreasure = $0.action { return true }
            return false
        }?.utility
    }

    func testAThreatTheSquadSeesLeavesThePrizeWorthNoMoreThanGreed() throws {
        // FR-BOT-690, both motives: the one that would go for it and the one that
        // carries it, with the crew's view clear and then with a threat in it. The
        // prize is not taken off the list any more — what is left of it is the bot's
        // greed, which is a share of what it was worth and not nothing.
        let world = try world(map: "room", squadSize: 1)
        let greed = 0.6
        let bot = minded(try soldier(id: 1, at: SIMD3(1, 0, 1), in: world), greed: greed, discipline: 0.5)
        let clear = facts(in: world)
        var seen = clear
        seen.squadSeesAThreat = true

        let calm = try XCTUnwrap(prize(for: bot, in: clear),
                                 "nothing was offered with the view clear, so this proves nothing")
        let fighting = try XCTUnwrap(prize(for: bot, in: seen),
                                     "a threat its crew could see took the prize off the list")
        XCTAssertEqual(fighting, calm * greed, accuracy: 1e-9,
                       "the prize in a fight was not worth the bot's greed of what it was worth")

        var carrying = clear
        carrying.carriesTreasure = true
        var carryingSeen = carrying
        carryingSeen.squadSeesAThreat = true
        let carried = try XCTUnwrap(prize(for: bot, in: carrying),
                                    "a carrier with the view clear was not offered the way out")
        XCTAssertEqual(try XCTUnwrap(prize(for: bot, in: carryingSeen)), carried * greed, accuracy: 1e-9,
                       "a carrier in a fight was not held to its greed")
    }

    func testABotOfNoGreedIsOfferedNothingInAFight() throws {
        // The negation of FR-BOT-690: at greed nothing the rule is the ban it replaced,
        // so the weighing has something to be read against.
        let world = try world(map: "room", squadSize: 1)
        let bot = minded(try soldier(id: 1, at: SIMD3(1, 0, 1), in: world), greed: .zero, discipline: 0.5)
        var seen = facts(in: world)
        seen.squadSeesAThreat = true
        XCTAssertNil(prize(for: bot, in: seen), "a bot of no greed was still offered the prize in a fight")
        XCTAssertNotNil(prize(for: bot, in: facts(in: world)),
                        "it was offered nothing with the view clear either, so this proves nothing")
    }

    func testAStandingOrderHoldsGreedInCheck() throws {
        // FR-BOT-710: the commander has no other way in, so what it buys is this
        // scaling — the bot's indiscipline is all that is left of its greed.
        let world = try world(map: "room", squadSize: 1)
        let discipline = 0.75
        let bot = minded(try soldier(id: 1, at: SIMD3(1, 0, 1), in: world), greed: 0.8, discipline: discipline)
        var free = facts(in: world)
        free.squadSeesAThreat = true
        var ordered = free
        ordered.underOrders = true

        let loose = try XCTUnwrap(prize(for: bot, in: free))
        XCTAssertEqual(try XCTUnwrap(prize(for: bot, in: ordered)), loose * (1 - discipline), accuracy: 1e-9,
                       "an order left the prize worth as much as it was to an uncommanded bot")
    }

    func testACarrierIsOfferedNothingThatUsesAWeapon() throws {
        // FR-BOT-670: hands full. The enemy in front of it would otherwise be a target,
        // and the empty magazine a reload.
        let world = try world(map: "room", squadSize: 1)
        var facts = Deliberation.Situation(plan: world.plan, graph: world.graph,
                                           configuration: world.configurations.bot,
                                           cellSize: world.configurations.tuning.navigationGraphCellSize)
        facts.arenaSpan = Perception.metres(world.plan.bounds.lowest, world.plan.bounds.highest)
        facts.evacuation = NavigationGraph.Node(floor: 0, x: 21, z: 14)
        var carrier = try XCTUnwrap(Bot(id: 1, squad: .red, archetype: .assault, at: SIMD3(1, 0, 1),
                                        floor: 0, configuration: world.configurations.bot))
        carrier.knowledge.ways = Set(world.graph.nodes)
        var enemy = try XCTUnwrap(Bot(id: 2, squad: .blue, archetype: .assault, at: SIMD3(2, 0, 1),
                                      floor: 0, configuration: world.configurations.bot))
        enemy.knowledge.ways = carrier.knowledge.ways
        facts.allies = [carrier, enemy]
        facts.enemies = [enemy.position]
        facts.enemiesInView = [(id: enemy.id, point: enemy.position)]

        facts.carriesTreasure = false
        XCTAssertTrue(Deliberation.scores(for: carrier, in: facts).contains { $0.action.usesAWeapon },
                      "a bot with its hands free was offered no weapon at all, so this proves nothing")

        facts.carriesTreasure = true
        XCTAssertFalse(Deliberation.scores(for: carrier, in: facts).contains { $0.action.usesAWeapon },
                       "a bot carrying the treasure was offered a weapon")
    }
    func testAGreedyCarrierKeepsThePrizeWhileItsCrewFights() throws {
        // FR-BOT-700: the exception the drop is written with. Greed 0.8 over discipline
        // 0.5 and nobody commanding, so this one walks on with the box while the
        // shooting goes on behind it.
        let world = try world(map: "room", squadSize: 1)
        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 12, z: 7))
        let lying = try XCTUnwrap(prize.lying)
        let looter = minded(try soldier(id: 3, at: lying.point, in: world), greed: 0.8, discipline: 0.5)
        var held: (point: SIMD3<Double>, floor: Int)?
        _ = prize.step(among: [looter], cell: cell(world), cellOf: cellOf(world),
                       mayHold: mayHold(alarmed: [looter.squad]), held: &held)
        XCTAssertEqual(prize.carrier, looter.id, "a greedy bot did not pick the prize up in a fight")
        _ = prize.step(among: [looter], cell: cell(world), cellOf: cellOf(world),
                       mayHold: mayHold(alarmed: [looter.squad]), held: &held)
        XCTAssertEqual(prize.carrier, looter.id, "a greedy bot put the prize down in a fight")
    }

    func testASquadThatLosesItsCommanderGoesLooting() throws {
        // FR-BOT-710 through the two rules that read it: the same bot in the same fight,
        // under an order and then under none, which is what the role-holder's death
        // leaves behind (FR-CMD-125).
        let world = try world(map: "room", squadSize: 1)
        let looter = minded(try soldier(id: 3, at: SIMD3(2.5, 0, 3.5), in: world), greed: 0.8, discipline: 0.5)
        XCTAssertFalse(Deliberation.keepsThePrize(looter, underOrders: true),
                       "a commanded bot kept the prize while its crew fought")
        XCTAssertTrue(Deliberation.keepsThePrize(looter, underOrders: false),
                      "a squad with no commander did not go looting")

        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 12, z: 7))
        let lying = try XCTUnwrap(prize.lying)
        let onIt = minded(try soldier(id: 4, at: lying.point, in: world), greed: 0.8, discipline: 0.5)
        var held: (point: SIMD3<Double>, floor: Int)?
        _ = prize.step(among: [onIt], cell: cell(world), cellOf: cellOf(world),
                       mayHold: mayHold(alarmed: [onIt.squad], underOrders: true), held: &held)
        XCTAssertNil(prize.carrier, "a commanded bot picked the prize up in the middle of a fight")
        _ = prize.step(among: [onIt], cell: cell(world), cellOf: cellOf(world),
                       mayHold: mayHold(alarmed: [onIt.squad]), held: &held)
        XCTAssertEqual(prize.carrier, onIt.id, "with its commander gone it still would not take the prize")
    }

    func testABotWhoseDutyOutweighsItsGreedTakesNothingInAFight() throws {
        // FR-BOT-720: the ordinary bot, so that the exception above has a rule to be
        // an exception to.
        let world = try world(map: "room", squadSize: 1)
        var prize = treasure(in: world, at: NavigationGraph.Node(floor: 0, x: 12, z: 7))
        let lying = try XCTUnwrap(prize.lying)
        let dutiful = minded(try soldier(id: 3, at: lying.point, in: world), greed: 0.3, discipline: 0.7)
        var held: (point: SIMD3<Double>, floor: Int)?
        _ = prize.step(among: [dutiful], cell: cell(world), cellOf: cellOf(world),
                       mayHold: mayHold(alarmed: [dutiful.squad]), held: &held)
        XCTAssertNil(prize.carrier, "a dutiful bot picked the prize up in the middle of a fight")
        _ = prize.step(among: [dutiful], cell: cell(world), cellOf: cellOf(world), held: &held)
        XCTAssertEqual(prize.carrier, dutiful.id, "the fighting was over and it still did not take the prize")
    }

    func testACarrierWalksAtAThirdOfItsSpeed() throws {
        // FR-BOT-680: the prize is heavy. Two bots of one archetype on one straight
        // route, one of them carrying, half a second in — long enough for both to be up
        // to speed (FR-BOT-290) and far enough from the route's end that neither is
        // braking, which is why this reads the speeds and not the ground covered.
        let world = try world(map: "room", squadSize: 1)
        let running = try XCTUnwrap(world.configurations.bot.archetypes["assault"]?.runSpeed)
        let slowdown = world.configurations.bot.carryingSlowdown
        var bots: [Bot] = []
        for id in [1, 2] {
            var bot = try XCTUnwrap(Bot(id: id, squad: .red, archetype: .assault,
                                        at: SIMD3(1.5, 0, 2.5 + Double(id)), floor: 0,
                                        configuration: world.configurations.bot))
            bot.knowledge.ways = Set(world.graph.nodes)
            bot.action = .advance(to: NavigationGraph.Node(floor: 0, x: 20, z: 5 + id))
            bots.append(bot)
        }
        for _ in 0..<30 {
            Execution.walk(&bots, seconds: 1.0 / 60, world: world, carrying: 2)
        }
        let free = bots[try checkedIndex(0, of: bots)].speed
        let laden = bots[try checkedIndex(1, of: bots)].speed
        XCTAssertEqual(free, running, accuracy: 1e-9, "the bot with free hands was not up to its run speed")
        XCTAssertEqual(laden, running / slowdown, accuracy: 1e-9,
                       "the carrier moved at \(laden) m/s, not a third of \(running)")
    }
}

final class SecondActTests: XCTestCase {
    func testAMatchIsWonByCarryingTheTreasureOff() throws {
        // The whole slice through a real match, with nobody steering the snake: two bots
        // a side, and whoever reaches the treasure (FR-BOT-620, FR-BOT-630) carries it
        // to the evacuation point (FR-BOT-640) and leaves with it once the other crew
        // is gone, which ends the match (FR-SCORE-160).
        //
        // Two a side and not one, since 2026-10-14: a carrier has no hand for a weapon
        // (FR-BOT-670), so a squad of one that picks the prize up can never clear the
        // way for itself and the second act cannot finish. Five minutes of match time:
        // longer than it takes, and short of the run being a measurement.
        let world = try world(map: "room", squadSize: 2)
        var game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        let frame = 1.0 / 60
        var carried = false
        for _ in 0..<18_000 where game.outcome == nil {
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
