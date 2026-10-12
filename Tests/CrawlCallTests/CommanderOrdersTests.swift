// What a commander's answer does to a match: the squad's threat and order, each
// soldier's role and weights, where an order sends a bot, and how far its discipline
// lets the order beat its own reading of the danger.
//
// No model anywhere. Every answer here is written out in the test, which is what the
// seam is for (ADR-0077): the shape of IF-CMD-020 is the contract, and a decision made
// up by hand exercises what it causes exactly as one from the model would.
//
// file verifies: FR-CMD-030, FR-CMD-040, FR-CMD-050, FR-CMD-060, FR-BOT-120, FR-BOT-130
import XCTest
@testable import CrawlCall

/// What one answer leaves behind (FR-CMD-030, FR-CMD-040, FR-CMD-050, FR-CMD-060).
final class SquadCommandTests: XCTestCase {
    private var configuration: BotConfiguration!

    override func setUpWithError() throws {
        try super.setUpWithError()
        configuration = try Launch.world().get().configurations.bot
    }

    private func lean(_ name: String, role: String? = nil, panic: Double = 0.5,
                      courage: Double = 0.5, discipline: Double = 0.5,
                      aggression: Double = 0.5, selfSacrifice: Double = 0.5) -> CommanderDecision.Lean {
        CommanderDecision.Lean(name: name, role: role, panic: panic, courage: courage,
                               discipline: discipline, aggression: aggression,
                               selfSacrifice: selfSacrifice)
    }

    private func decision(threat: CommanderDecision.Threat = .snake,
                          order: CommanderDecision.Order = .flank,
                          crew: [CommanderDecision.Lean] = []) -> CommanderDecision {
        CommanderDecision(threat: threat, order: order, crew: crew, truce: .none, line: nil)
    }

    private func bot(_ kind: Archetype, squad: Squad = .red, id: Int = 0) throws -> Bot {
        try XCTUnwrap(Bot(id: id, squad: squad, archetype: kind, at: .zero, floor: 0,
                          configuration: configuration))
    }

    // MARK: the squad's own (FR-CMD-030, FR-CMD-040)

    func testTheThreatAndTheOrderLandOnTheSquadThatWasAsked() throws {
        var bots = [try bot(.assault, squad: .red), try bot(.assault, squad: .blue, id: 1)]
        var commands = SquadCommands()
        XCTAssertNil(commands.of(.red), "a squad nobody has spoken to stands under nothing")

        commands.apply(decision(threat: .withdraw, order: .disperse), to: .red,
                       among: &bots, configuration: configuration)
        XCTAssertEqual(commands.of(.red), SquadCommand(threat: .withdraw, order: .disperse))
        XCTAssertNil(commands.of(.blue), "one squad's order reached the other")
    }

    func testALaterAnswerReplacesTheOrderTheSquadStoodUnder() throws {
        var bots = [try bot(.assault)]
        var commands = SquadCommands()
        commands.apply(decision(threat: .snake, order: .hold), to: .red,
                       among: &bots, configuration: configuration)
        commands.apply(decision(threat: .enemy, order: .flank), to: .red,
                       among: &bots, configuration: configuration)
        XCTAssertEqual(commands.of(.red), SquadCommand(threat: .enemy, order: .flank))
    }

    // MARK: the roles (FR-CMD-050)

    func testEachSoldierTakesTheRoleTheAnswerNamesForItByName() throws {
        var bots = [try bot(.assault, id: 0), try bot(.heavy, id: 1)]
        var commands = SquadCommands()
        commands.apply(decision(crew: [lean("Davis", role: "hold the stair"),
                                       lean("Pike", role: "cover Davis")]),
                       to: .red, among: &bots, configuration: configuration)
        XCTAssertEqual(try element(0, of: bots).role, "hold the stair")
        XCTAssertEqual(try element(1, of: bots).role, "cover Davis")
    }

    func testARoleOfNoneTakesTheRoleAway() throws {
        var bots = [try bot(.assault)]
        bots[try checkedIndex(0, of: bots)].role = "hold the stair"
        var commands = SquadCommands()
        commands.apply(decision(crew: [lean("Davis", role: nil)]), to: .red,
                       among: &bots, configuration: configuration)
        XCTAssertNil(try element(0, of: bots).role, "a role the commander took away stayed on the soldier")
    }

    func testASoldierTheAnswerPassesOverKeepsWhatItHad() throws {
        // The other half of IF-CMD-020's refusal to repair: a crew member the model
        // forgot is not a soldier whose orders were taken away.
        var bots = [try bot(.assault, id: 0), try bot(.heavy, id: 1)]
        bots[try checkedIndex(1, of: bots)].role = "cover Davis"
        let before = try element(1, of: bots).weights
        var commands = SquadCommands()
        commands.apply(decision(crew: [lean("Davis", role: "hold the stair", panic: 0.9)]),
                       to: .red, among: &bots, configuration: configuration)
        XCTAssertEqual(try element(1, of: bots).role, "cover Davis")
        XCTAssertEqual(try element(1, of: bots).weights, before)
    }

    // MARK: the weights (FR-CMD-060)

    func testTheWeightsAreReplacedByWhatTheCommanderNamed() throws {
        var bots = [try bot(.assault)]
        XCTAssertNotEqual(try element(0, of: bots).weights.panic, 0.1)
        var commands = SquadCommands()
        commands.apply(decision(crew: [lean("Davis", panic: 0.1, courage: 0.2, discipline: 0.3,
                                            aggression: 0.4, selfSacrifice: 0.6)]),
                       to: .red, among: &bots, configuration: configuration)
        XCTAssertEqual(try element(0, of: bots).weights, BotConfiguration.Weights(panic: 0.1, discipline: 0.3,
                                                                 aggression: 0.4, selfSacrifice: 0.6,
                                                                 courage: 0.2))
    }

    func testAWeightOutsideTheArchetypesRangeIsHeldToIt() throws {
        // The clamp of FR-CMD-060, against a configuration whose range is narrower
        // than the whole: every range in the shipped file runs 0 to 1 today, so a
        // shipped-file test could not tell clamping from doing nothing.
        let narrow = try configuration(panicOfAssault: 0.3, to: 0.6)
        let high = SquadCommands.weights(from: lean("Davis", panic: 0.95), for: .assault,
                                         configuration: narrow)
        let low = SquadCommands.weights(from: lean("Davis", panic: 0.05), for: .assault,
                                        configuration: narrow)
        XCTAssertEqual(high.panic, 0.6)
        XCTAssertEqual(low.panic, 0.3)
        // And a weight inside the range is left exactly where the commander put it.
        XCTAssertEqual(SquadCommands.weights(from: lean("Davis", panic: 0.45), for: .assault,
                                             configuration: narrow).panic, 0.45)
        // A range belongs to one archetype: the heavy's is untouched by the assault's.
        XCTAssertEqual(SquadCommands.weights(from: lean("Pike", panic: 0.95), for: .heavy,
                                             configuration: narrow).panic, 0.95)
    }

    /// The shipped bot configuration with one archetype's panic range narrowed.
    private func configuration(panicOfAssault lowest: Double, to highest: Double) throws -> BotConfiguration {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "bot", withExtension: "json", subdirectory: "config"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var archetypes = try XCTUnwrap(json["archetypes"] as? [String: Any])
        var assault = try XCTUnwrap(archetypes["assault"] as? [String: Any])
        var ranges = try XCTUnwrap(assault["allowedRanges"] as? [String: Any])
        ranges["panic"] = ["lowest": lowest, "highest": highest]
        assault["allowedRanges"] = ranges
        archetypes["assault"] = assault
        json["archetypes"] = archetypes
        return try Configurations.decode(BotConfiguration.self, named: "bot", schema: BotConfiguration.schema,
                                         from: JSONSerialization.data(withJSONObject: json))
    }
}

/// Where an order sends a bot (FR-CMD-040).
final class OrdersZoneTests: XCTestCase {
    private var kit: Kit!
    private var configuration: BotConfiguration!
    private let cell = 0.5

    override func setUpWithError() throws {
        try super.setUpWithError()
        kit = try Kit.load(named: "blockout", from: .main)
        configuration = try Launch.world().get().configurations.bot
    }

    private func arena(_ rows: String...) throws -> Deliberation.Situation {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n"
                                      + rows.joined(separator: "\n") + "\n", kit: kit)
        return Deliberation.Situation(plan: ScenePlan.make(map: map, kit: kit, cellSize: cell),
                                      graph: NavigationGraph.derive(from: map, stepHeight: ShippedTuning.stepHeight),
                                      configuration: configuration,
                                      cellSize: cell)
    }

    private func at(_ x: Int, _ z: Int) -> SIMD3<Double> { SIMD3(Double(x) * cell, 0, Double(z) * cell) }

    private func bot(at x: Int, _ z: Int, id: Int = 0) throws -> Bot {
        try XCTUnwrap(Bot(id: id, squad: .red, archetype: .assault, at: at(x, z), floor: 0,
                          configuration: configuration))
    }

    private func metres(_ node: NavigationGraph.Node, to point: SIMD3<Double>,
                        in situation: Deliberation.Situation) -> Double {
        Perception.metres(Deliberation.centre(of: node, in: situation), point)
    }

    func testHoldIsWhereTheBotAlreadyStands() throws {
        let situation = try arena("..........", "..........")
        let soldier = try bot(at: 3, 0)
        XCTAssertEqual(Orders.zone(for: soldier, under: .hold, in: situation),
                       NavigationGraph.Node(floor: 0, x: 3, z: 0))
    }

    func testDestroyingCoverNamesNoCellBecauseNothingCanWreckAWallYet() throws {
        // FR-BOT-070 is not built, so the fifth order has no cell to name. The
        // deliberation is then exactly what it was with no commander at all.
        let situation = try arena("..........")
        XCTAssertNil(Orders.zone(for: try bot(at: 3, 0), under: .destroyCover, in: situation))
    }

    func testFlankingGoesOffTheLineToTheEnemyWithoutGivingGround() throws {
        var situation = try arena("..........", "..........")
        situation.enemyBelief = at(9, 0)
        let soldier = try bot(at: 1, 0)
        let zone = try XCTUnwrap(Orders.zone(for: soldier, under: .flank, in: situation))
        XCTAssertEqual(zone.z, 1, "the flank stayed on the straight line to the enemy")
        XCTAssertLessThanOrEqual(metres(zone, to: at(9, 0), in: situation),
                                 Perception.metres(soldier.position, at(9, 0)),
                                 "the flank gave ground")
    }

    func testFlankingNamesNothingWhereNobodyHasSeenTheEnemy() throws {
        let situation = try arena("..........", "..........")
        XCTAssertNil(Orders.zone(for: try bot(at: 1, 0), under: .flank, in: situation),
                     "a crew nobody has seen was flanked")
    }

    func testWithdrawingPutsGroundBetweenTheBotAndWhatItIsAfraidOf() throws {
        var situation = try arena("..........")
        situation.snake = [at(1, 0)]
        let soldier = try bot(at: 5, 0)
        let zone = try XCTUnwrap(Orders.zone(for: soldier, under: .withdrawToZone, in: situation))
        XCTAssertGreaterThan(metres(zone, to: at(1, 0), in: situation),
                             Perception.metres(soldier.position, at(1, 0)),
                             "withdrawing moved towards the snake")
    }

    func testWithdrawingNamesNothingWhereTheSquadKnowsOfNoDanger() throws {
        let situation = try arena("..........")
        XCTAssertNil(Orders.zone(for: try bot(at: 5, 0), under: .withdrawToZone, in: situation))
    }

    func testDispersingPutsGroundBetweenTheBotAndItsNearestSquadmate() throws {
        var situation = try arena("..........")
        let soldier = try bot(at: 2, 0)
        let mate = try bot(at: 1, 0, id: 1)
        situation.allies = [soldier, mate]
        let zone = try XCTUnwrap(Orders.zone(for: soldier, under: .disperse, in: situation))
        XCTAssertGreaterThan(metres(zone, to: mate.position, in: situation),
                             Perception.metres(soldier.position, mate.position),
                             "dispersing left the bot no further from its squadmate")
    }

    func testASquadOfOneIsAlreadyDispersed() throws {
        var situation = try arena("..........")
        let soldier = try bot(at: 2, 0)
        situation.allies = [soldier]
        XCTAssertNil(Orders.zone(for: soldier, under: .disperse, in: situation))
    }

    func testNoOrderEverNamesACellTheBotDoesNotKnow() throws {
        // FR-BOT-220 reaches the orders too: a bot acts on what it knows, and a
        // destination it has never seen is one it would set off for and stop.
        var situation = try arena("..........", "..........")
        situation.knows = { _ in false }
        situation.enemyBelief = at(9, 0)
        situation.snake = [at(1, 0)]
        let soldier = try bot(at: 5, 0)
        let mate = try bot(at: 4, 0, id: 1)
        situation.allies = [soldier, mate]
        XCTAssertNil(Orders.zone(for: soldier, under: .flank, in: situation))
        XCTAssertNil(Orders.zone(for: soldier, under: .withdrawToZone, in: situation))
        XCTAssertNil(Orders.zone(for: soldier, under: .disperse, in: situation))
    }
}

/// What the threat priority and the order do inside a deliberation (FR-CMD-030,
/// FR-BOT-120, FR-BOT-130).
final class OrderedDeliberationTests: XCTestCase {
    private var kit: Kit!
    private var configuration: BotConfiguration!
    private let cell = 0.5

    override func setUpWithError() throws {
        try super.setUpWithError()
        kit = try Kit.load(named: "blockout", from: .main)
        configuration = try Launch.world().get().configurations.bot
    }

    private func arena(_ rows: String...) throws -> Deliberation.Situation {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n"
                                      + rows.joined(separator: "\n") + "\n", kit: kit)
        return Deliberation.Situation(plan: ScenePlan.make(map: map, kit: kit, cellSize: cell),
                                      graph: NavigationGraph.derive(from: map, stepHeight: ShippedTuning.stepHeight),
                                      configuration: configuration,
                                      cellSize: cell)
    }

    private func at(_ x: Int, _ z: Int) -> SIMD3<Double> { SIMD3(Double(x) * cell, 0, Double(z) * cell) }

    private func bot(at x: Int, _ z: Int, id: Int = 0) throws -> Bot {
        try XCTUnwrap(Bot(id: id, squad: .red, archetype: .assault, at: at(x, z), floor: 0,
                          configuration: configuration))
    }

    private func weights(panic: Double = 0.5, discipline: Double = 0.5,
                         aggression: Double = 0.5, selfSacrifice: Double = 0.5,
                         courage: Double = 0.5) -> BotConfiguration.Weights {
        BotConfiguration.Weights(panic: panic, discipline: discipline,
                                 aggression: aggression, selfSacrifice: selfSacrifice,
                                 courage: courage)
    }

    private func utility(of match: (Action) -> Bool, for bot: Bot,
                         in situation: Deliberation.Situation) -> Double? {
        Deliberation.scores(for: bot, in: situation).first { match($0.action) }?.utility
    }

    private func isCover(_ action: Action) -> Bool { if case .takeCover = action { return true }; return false }
    private func isFire(_ action: Action) -> Bool { if case .fire = action { return true }; return false }
    private func isZone(_ action: Action) -> Bool { if case .moveToOrderedZone = action { return true }; return false }

    /// A bot with an enemy near and a part of the snake further off: both in view,
    /// the snake beyond the override distance of 5 metres, and the enemy worth more by
    /// nearness alone.
    private func bothInView() throws -> (situation: Deliberation.Situation, bot: Bot) {
        var situation = try arena(".............")
        situation.snake = [at(12, 0)]
        situation.inView = situation.snake
        situation.enemiesInView = [(id: 7, point: at(4, 0))]
        situation.enemies = [at(4, 0)]
        return (situation, try bot(at: 1, 0))
    }

    func testWithNoCommanderTheNearerTargetWins() throws {
        // The control for the two below: with nothing told, the scores decide, and the
        // enemy at two metres beats the snake at five and a half.
        let (situation, soldier) = try bothInView()
        XCTAssertEqual(Deliberation.choose(for: soldier, in: situation), .fire(at: .bot(id: 7)))
    }

    func testToldToWorryAboutTheSnakeTheBotFiresAtItOverANearerEnemy() throws {
        var (situation, soldier) = try bothInView()
        situation.priority = .snake
        XCTAssertEqual(Deliberation.choose(for: soldier, in: situation), .fire(at: .snake(at: at(12, 0))))

        // And what firing is worth is the snake's own score, unchanged: the priority
        // ranks the kinds of target and does not scale what either is worth.
        var alone = situation
        alone.priority = nil
        alone.enemiesInView = []
        alone.enemies = []
        XCTAssertEqual(try XCTUnwrap(utility(of: isFire, for: soldier, in: situation)),
                       try XCTUnwrap(utility(of: isFire, for: soldier, in: alone)), accuracy: 1e-12)
    }

    func testToldToWorryAboutTheEnemyTheBotLeavesTheSnakeAlone() throws {
        var (situation, soldier) = try bothInView()
        situation.priority = .enemy
        XCTAssertEqual(Deliberation.choose(for: soldier, in: situation), .fire(at: .bot(id: 7)))
    }

    func testWithdrawNamesNothingToFireAtAndLeavesTheRankingWhereItWas() throws {
        var (situation, soldier) = try bothInView()
        situation.priority = .withdraw
        XCTAssertEqual(Deliberation.choose(for: soldier, in: situation), .fire(at: .bot(id: 7)))
    }

    func testTheSnakeWithinTheOverrideDistanceBeatsAnOrderToWorryAboutTheEnemy() throws {
        // FR-BOT-120 against FR-CMD-030: the local correction wins, which is the whole
        // of concept §9.2's "a snake five metres away overrides any order".
        var situation = try arena("............")
        situation.snake = [at(6, 0)]
        situation.inView = situation.snake
        situation.enemiesInView = [(id: 7, point: at(4, 0))]
        situation.enemies = [at(4, 0)]
        situation.priority = .enemy
        let soldier = try bot(at: 1, 0)
        XCTAssertLessThanOrEqual(Perception.metres(soldier.position, at(6, 0)),
                                 configuration.overrideDistance, "the arena does not pose the override")
        XCTAssertEqual(Deliberation.choose(for: soldier, in: situation), .fire(at: .snake(at: at(6, 0))))
    }

    // MARK: discipline against the bot's own reading (FR-BOT-130)

    /// A bot with cover within reach, the snake near enough to be afraid of, and an
    /// order standing.
    private func underOrders(discipline: Double, ordered: Bool) throws
        -> (situation: Deliberation.Situation, bot: Bot) {
        var situation = try arena("..........", ".#........")
        situation.snake = [at(3, 0)]
        situation.inView = situation.snake
        if ordered { situation.orderedZone = NavigationGraph.Node(floor: 0, x: 8, z: 0) }
        var soldier = try bot(at: 1, 0)
        soldier.weights = weights(panic: 0.9, discipline: discipline, aggression: 0.1, courage: 0.5)
        return (situation, soldier)
    }

    func testAnOrderWeighsTheBotsOwnReadingDownByItsDiscipline() throws {
        let loose = try underOrders(discipline: 0.25, ordered: true)
        let free = try underOrders(discipline: 0.25, ordered: false)
        let undamped = try XCTUnwrap(utility(of: isCover, for: free.bot, in: free.situation))
        let damped = try XCTUnwrap(utility(of: isCover, for: loose.bot, in: loose.situation))
        XCTAssertGreaterThan(undamped, 0)
        XCTAssertEqual(damped, undamped * 0.75, accuracy: 1e-12,
                       "the local term was not weighted by one minus the discipline")
    }

    func testDisciplineOfOneLeavesNothingOfTheBotsOwnReading() throws {
        let (situation, soldier) = try underOrders(discipline: 1, ordered: true)
        XCTAssertEqual(try XCTUnwrap(utility(of: isCover, for: soldier, in: situation)), 0, accuracy: 1e-12)
        XCTAssertEqual(Deliberation.choose(for: soldier, in: situation).map(isZone), true,
                       "a bot of discipline 1.0 did something other than what it was told")
    }

    func testDisciplineOfNoneLeavesTheOrderWorthNothing() throws {
        let (situation, soldier) = try underOrders(discipline: 0, ordered: true)
        XCTAssertEqual(try XCTUnwrap(utility(of: isZone, for: soldier, in: situation)), 0, accuracy: 1e-12)
        let chosen = try XCTUnwrap(Deliberation.choose(for: soldier, in: situation))
        XCTAssertFalse(isZone(chosen), "a bot of discipline 0.0 obeyed: \(chosen)")
    }

    func testWithNoOrderStandingTheBotsOwnReadingIsWhatItAlwaysWas() throws {
        // The negation: take the order away and the damping goes with it, whatever the
        // discipline. Without this the formula could be damping every bot in the game.
        for discipline in [0.0, 0.5, 1.0] {
            let (situation, soldier) = try underOrders(discipline: discipline, ordered: false)
            let (plain, same) = try underOrders(discipline: 0.5, ordered: false)
            XCTAssertEqual(try XCTUnwrap(utility(of: isCover, for: soldier, in: situation)),
                           try XCTUnwrap(utility(of: isCover, for: same, in: plain)), accuracy: 1e-12,
                           "discipline \(discipline) moved a bot under no order")
        }
    }
}

/// The whole way through: a match takes an answer and the squads stand under it.
final class CommandedMatchTests: XCTestCase {
    private func decision(_ order: CommanderDecision.Order,
                          threat: CommanderDecision.Threat = .enemy) -> CommanderDecision {
        CommanderDecision(threat: threat, order: order,
                          crew: [CommanderDecision.Lean(name: "Davis", role: "hold the stair",
                                                        panic: 0.1, courage: 0.9, discipline: 0.8,
                                                        aggression: 0.7, selfSacrifice: 0.2)],
                          truce: .none, line: nil)
    }

    private func match(_ script: [ScriptedCommander.Reply]) throws -> Game {
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        return Game(world: world, start: start, commander: ScriptedCommander(script))
    }

    func testAnAnswerTakenByAFrameSetsTheSquadsOrderAndItsSoldiers() async throws {
        let game = try match([.decision(decision(.disperse))])
        let desk = try XCTUnwrap(game.desk)
        let first = try XCTUnwrap(game.dueCalls().first)
        XCTAssertEqual(first.squad, .red)
        await desk.call(first.squad, with: first.state, at: 0)

        var later = game
        XCTAssertNil(later.commands.of(.red), "the order arrived before a frame took it")
        _ = later.advance(seconds: 0.1)
        XCTAssertEqual(later.commands.of(.red), SquadCommand(threat: .enemy, order: .disperse))
        XCTAssertNil(later.commands.of(.blue), "blue was never called and stands under nothing")

        let davis = try XCTUnwrap(later.bots.first { $0.squad == .red && $0.archetype == .assault })
        XCTAssertEqual(davis.role, "hold the stair")
        XCTAssertEqual(davis.weights.courage, 0.9)
        XCTAssertEqual(davis.weights.discipline, 0.8)
        let other = try XCTUnwrap(later.bots.first { $0.squad == .blue && $0.archetype == .assault })
        XCTAssertNil(other.role, "the other squad took red's roles")
    }

    func testARefusedCallLeavesTheSquadUnderTheOrderItHad() async throws {
        // CON-CMD-020 where it bites: the squad keeps the order, which is why a
        // refusal is a missed cycle rather than a squad without a commander.
        let game = try match([.decision(decision(.hold)), .failure(.refused)])
        let desk = try XCTUnwrap(game.desk)
        let first = try XCTUnwrap(game.dueCalls().first)
        await desk.call(first.squad, with: first.state, at: 0)
        var later = game
        _ = later.advance(seconds: 0.1)
        XCTAssertEqual(later.commands.of(.red)?.order, .hold)

        await desk.call(.red, with: first.state, at: 7)
        _ = later.advance(seconds: 0.1)
        XCTAssertEqual(later.commands.of(.red)?.order, .hold, "a refusal took the order away")
        XCTAssertEqual(later.commanderFailures.map(\.why), [.refused])
    }

    func testAMatchWithNoCommanderLeavesEverySquadUnderNothing() throws {
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        var game = Game(world: world, start: start)
        _ = game.advance(seconds: 1)
        XCTAssertNil(game.commands.of(.red))
        XCTAssertNil(game.commands.of(.blue))
    }
}
