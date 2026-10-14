// What a commander's answer does to a match: the squad's threat, its order and the part
// of the arena that order names, which cell a bot picks for itself under one, and how
// far its discipline lets the order beat its own reading of the danger.
//
// Nothing a commander says reaches a soldier any more (ADR-0085), and one test here is
// about that: an answer changes what a squad is trying to do and nothing about who its
// soldiers are.
//
// No model anywhere. Every answer here is written out in the test, which is what the
// seam is for (ADR-0077): the shape of IF-CMD-020 is the contract, and a decision made
// up by hand exercises what it causes exactly as one from the model would.
//
// file verifies: FR-CMD-030, FR-CMD-040, FR-BOT-116, FR-BOT-120, FR-BOT-130, FR-BOT-660
import XCTest
@testable import CrawlCall

/// What one answer leaves behind (FR-CMD-030, FR-CMD-040).
final class SquadCommandTests: XCTestCase {
    private var configuration: BotConfiguration!

    override func setUpWithError() throws {
        try super.setUpWithError()
        configuration = try Launch.world().get().configurations.bot
    }

    private func decision(threat: CommanderDecision.Threat = .snake,
                          order: CommanderDecision.Order = .flank,
                          place: Places.Part? = .east) -> CommanderDecision {
        CommanderDecision(threat: threat, order: order, place: place, truce: .none, line: nil)
    }

    private func bot(_ kind: Archetype, squad: Squad = .red, id: Int = 0) throws -> Bot {
        try XCTUnwrap(Bot(id: id, squad: squad, archetype: kind, at: .zero, floor: 0,
                          configuration: configuration))
    }

    // MARK: the squad's own (FR-CMD-030, FR-CMD-040)

    func testTheThreatTheOrderAndThePlaceLandOnTheSquadThatWasAsked() throws {
        var commands = SquadCommands()
        XCTAssertNil(commands.of(.red), "a squad nobody has spoken to stands under nothing")

        commands.apply(decision(threat: .withdraw, order: .withdraw, place: .northWest), to: .red)
        XCTAssertEqual(commands.of(.red),
                       SquadCommand(threat: .withdraw, order: .withdraw, place: .northWest))
        XCTAssertNil(commands.of(.blue), "one squad's order reached the other")
    }

    func testAnOrderMayNameNoPlaceAtAll() throws {
        var commands = SquadCommands()
        commands.apply(decision(order: .hold, place: nil), to: .red)
        XCTAssertEqual(commands.of(.red), SquadCommand(threat: .snake, order: .hold, place: nil))
    }

    func testALaterAnswerReplacesTheOrderTheSquadStoodUnder() throws {
        var commands = SquadCommands()
        commands.apply(decision(threat: .snake, order: .hold, place: .middle), to: .red)
        commands.apply(decision(threat: .enemy, order: .press, place: .south), to: .red)
        XCTAssertEqual(commands.of(.red), SquadCommand(threat: .enemy, order: .press, place: .south))
    }

    func testAnAnswerChangesNothingAboutTheSoldiersThemselves() throws {
        // The rule of ADR-0085, asserted where it would be broken: what a bot is stays
        // the bot's, and an answer moves only what its squad is trying to do.
        var soldier = try bot(.assault)
        soldier.weights = BotConfiguration.Weights(panic: 0.1, discipline: 0.2, aggression: 0.3,
                                                   selfSacrifice: 0.4, courage: 0.5)
        let before = soldier
        var commands = SquadCommands()
        commands.apply(decision(), to: .red)
        XCTAssertEqual(soldier, before, "an answer reached inside a soldier")
    }
}

/// Which cell a bot takes under an order (FR-BOT-116): its own best, not one the order
/// named.
final class OrderedCellTests: XCTestCase {
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
        var situation = Deliberation.Situation(plan: ScenePlan.make(map: map, kit: kit, cellSize: cell),
                                               graph: NavigationGraph.derive(from: map, stepHeight: ShippedTuning.stepHeight),
                                               configuration: configuration,
                                               cellSize: cell)
        situation.arenaSpan = 20
        return situation
    }

    private func at(_ x: Int, _ z: Int) -> SIMD3<Double> { SIMD3(Double(x) * cell, 0, Double(z) * cell) }

    private func bot(at x: Int, _ z: Int, id: Int = 0, squad: Squad = .red) throws -> Bot {
        try XCTUnwrap(Bot(id: id, squad: squad, archetype: .assault, at: at(x, z), floor: 0,
                          configuration: configuration))
    }

    func testWithNoPlaceNamedThereIsNoCellToGoTo() throws {
        let situation = try arena(String(repeating: ".", count: 40))
        XCTAssertNil(Deliberation.ordered(for: try bot(at: 2, 0), in: situation),
                     "a bot was sent somewhere by an order that named nowhere")
    }

    func testTheCellIsTheOneWorthMostWithinReachAndItLiesTowardsThePlace() throws {
        var situation = try arena(String(repeating: ".", count: 40))
        situation.orderedPart = at(39, 0)
        let soldier = try bot(at: 2, 0)

        let zone = try XCTUnwrap(Deliberation.ordered(for: soldier, in: situation))
        XCTAssertGreaterThan(Deliberation.centre(of: zone, in: situation).x, soldier.position.x,
                             "the order sent the bot away from the part it named")
        XCTAssertLessThanOrEqual(Perception.metres(soldier.position, Deliberation.centre(of: zone, in: situation)),
                                 Deliberation.coverSearch(configuration),
                                 "one step of an order is further than a bot looks for cover")
    }

    func testStandingOnTheBestCellThereIsNothingToGoTo() throws {
        // The shape FR-BOT-119 gave cover: an action with nothing to gain is off the
        // list rather than on it at nothing.
        var situation = try arena(String(repeating: ".", count: 40))
        let soldier = try bot(at: 2, 0)
        situation.orderedPart = soldier.position

        XCTAssertNil(Deliberation.ordered(for: soldier, in: situation),
                     "a bot already where the order points was sent somewhere else")
    }

    func testNoCellTheBotDoesNotKnowIsEverNamed() throws {
        // FR-BOT-220 reaches the order too: a destination it has never seen is one it
        // would set off for and stop.
        var situation = try arena(String(repeating: ".", count: 40))
        situation.orderedPart = at(39, 0)
        situation.knows = { $0.x <= 2 }
        let soldier = try bot(at: 2, 0)

        let zone = Deliberation.ordered(for: soldier, in: situation)
        XCTAssertNil(zone, "the order named a cell the bot has never seen: \(String(describing: zone))")
    }

    func testTheBotPicksItsOwnCellAndNotTheNearestOneToThePlace() throws {
        // The whole point of the rule. An alarmed squad keeps together (FR-BOT-190), so
        // of two cells the same distance from the bot the one beside its squadmate is
        // worth more — and that is the one it takes, although the other lies nearer to
        // where the commander pointed.
        var situation = try arena(String(repeating: ".", count: 40),
                                  String(repeating: ".", count: 40))
        situation.orderedPart = at(39, 0)
        situation.awareness = .alarm
        let soldier = try bot(at: 2, 0)
        let mate = try bot(at: 6, 1, id: 1)
        situation.allies = [soldier, mate]

        let zone = try XCTUnwrap(Deliberation.ordered(for: soldier, in: situation))
        XCTAssertLessThanOrEqual(Perception.metres(Deliberation.centre(of: zone, in: situation), mate.position),
                                 configuration.groupingDistance,
                                 "the bot went for the place and left its squadmate behind")
    }
}

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
        XCTAssertEqual(Deliberation.choose(for: soldier, in: situation), .fire(at: .bot(id: 7), with: .primary))
    }

    func testToldToWorryAboutTheSnakeTheBotFiresAtItOverANearerEnemy() throws {
        var (situation, soldier) = try bothInView()
        situation.priority = .snake
        XCTAssertEqual(Deliberation.choose(for: soldier, in: situation), .fire(at: .snake(at: at(12, 0)), with: .primary))

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
        XCTAssertEqual(Deliberation.choose(for: soldier, in: situation), .fire(at: .bot(id: 7), with: .primary))
    }

    func testWithdrawNamesNothingToFireAtAndLeavesTheRankingWhereItWas() throws {
        var (situation, soldier) = try bothInView()
        situation.priority = .withdraw
        XCTAssertEqual(Deliberation.choose(for: soldier, in: situation), .fire(at: .bot(id: 7), with: .primary))
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
        XCTAssertEqual(Deliberation.choose(for: soldier, in: situation), .fire(at: .snake(at: at(6, 0)), with: .primary))
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
                          threat: CommanderDecision.Threat = .enemy,
                          place: Places.Part? = .east) -> CommanderDecision {
        CommanderDecision(threat: threat, order: order, place: place, truce: .none, line: nil)
    }

    private func match(_ script: [ScriptedCommander.Reply]) throws -> Game {
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        return Game(world: world, start: start, commander: ScriptedCommander(script))
    }

    func testAnAnswerTakenByAFrameSetsTheSquadsOrderAndLeavesItsSoldiersAlone() async throws {
        let game = try match([.decision(decision(.press, place: .east))])
        let desk = try XCTUnwrap(game.desk)
        let first = try XCTUnwrap(game.dueCalls().first)
        XCTAssertEqual(first.squad, .red)
        await desk.call(first.squad, with: first.state, at: 0)

        var later = game
        XCTAssertNil(later.commands.of(.red), "the order arrived before a frame took it")
        _ = later.advance(seconds: 0.1)
        XCTAssertEqual(later.commands.of(.red),
                       SquadCommand(threat: .enemy, order: .press, place: .east))
        XCTAssertNil(later.commands.of(.blue), "blue was never called and stands under nothing")

        // And the soldiers are the soldiers the match started with (ADR-0085).
        let davis = try XCTUnwrap(later.bots.first { $0.squad == .red && $0.archetype == .assault })
        let began = try XCTUnwrap(game.bots.first { $0.squad == .red && $0.archetype == .assault })
        XCTAssertEqual(davis.weights, began.weights, "an answer rewrote a soldier's character")
    }

    func testASquadToldToPressEastSpendsItsMatchFurtherEastThanOneToldToPressWest() throws {
        // The whole chain in one test, with nothing stubbed but the answerer: a place
        // becomes a point, the point becomes a term in what a position is worth, and
        // the bots — choosing their own cells by their own cover, height and
        // squadmates — end up where they were pointed.
        //
        // Where the squad was over the match it lived and not where it stood at the
        // end: since the arms were built a firefight is decided inside half a minute
        // (ADR-0086, ADR-0087, ADR-0088), and a squad that pressed east and was shot
        // there has no position at the fortieth second at all. A squad wiped out in the
        // first frame still reads as nothing, which is a failure and not a pass.
        //
        // The other squad is told the opposite rather than told nothing. A squad under
        // no order advances on the enemy it believes in (FR-BOT-360), and the enemy of
        // red is east, so the silent squad drifts east by itself: measured on
        // 2026-10-13, over forty seconds, told east 14.24 m against silent 14.25 m —
        // no margin at all — while told east against told west is 14.24 m against
        // 5.04 m, in an arena whose east is 13.38 m and west 2.13 m. The order is what
        // this measures, so the comparison is between two orders.
        func averageEast(of game: Game, over seconds: Double) -> Double {
            var game = game
            let frame = 1.0 / 60
            var total = Double.zero, frames = Int.zero
            for _ in 0..<Int(seconds / frame) {
                game.advance(seconds: frame)
                let red = game.bots.filter { $0.squad == .red && $0.isAlive }.map(\.position.x)
                guard !red.isEmpty else { continue }
                total += red.reduce(0, +) / Double(red.count)
                frames += 1
            }
            return frames == .zero ? .nan : total / Double(frames)
        }
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        let east = Places.middle(of: .east, in: world.plan.bounds).x
        let west = Places.middle(of: .west, in: world.plan.bounds).x
        XCTAssertGreaterThan(east, west, "the arena's east is not east of its west")

        let eastward = averageEast(of: Game(world: world, start: start,
                                            commander: ScriptedCommander([.decision(decision(.press, place: .east))])),
                                   over: 40)
        let westward = averageEast(of: Game(world: world, start: start,
                                            commander: ScriptedCommander([.decision(decision(.press, place: .west))])),
                                   over: 40)
        XCTAssertFalse(eastward.isNaN || westward.isNaN, "red was wiped out before it had moved at all")
        XCTAssertGreaterThan(eastward, westward,
                             "a squad told to press east spent its match no further east than one told west")
        XCTAssertGreaterThan(eastward, east, "a squad told to press east never reached the arena's east")
        XCTAssertLessThan(westward, east, "a squad told to press west spent its match east of the arena's middle")
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

/// An order that names the ground a bot is already standing on (FR-BOT-660).
final class OrderAlreadyObeyedTests: XCTestCase {
    /// One bot of the shipped arena, alone in it, having looked at the map round it:
    /// with no enemy, no snake and a full magazine the only thing it can score is the
    /// order (FR-BOT-116), and a bot that has seen no cell has nowhere to be sent
    /// (FR-BOT-220, FR-BOT-230).
    private func alone(in world: World) throws -> [Bot] {
        let game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        var soldier = try XCTUnwrap(game.bots.first(where: { $0.squad == .red }),
                                    "the arena spawned no red squad")
        Perception.lookAtMap(&soldier, world: world, modules: Perception.modules(of: world.map), now: .zero)
        return [soldier]
    }

    private func command(_ part: Places.Part) -> SquadCommand {
        SquadCommand(threat: .enemy, order: .press, place: part)
    }

    func testThePartABotStandsInIsTheOneItsCommanderIsTold() throws {
        // The two readings are one reading: what `Places.part` answers is the word
        // `SquadView.place` puts in front of the model (IF-CMD-010).
        let world = try Launch.world().get()
        for part in Places.Part.allCases {
            let middle = Places.middle(of: part, in: world.plan.bounds)
            XCTAssertEqual(Places.part(of: middle, in: world.plan.bounds), part,
                           "the middle of \(part.rawValue) reads as another part")
        }
    }

    func testABotOrderedIntoThePartItStandsInIsGivenNoCellToMoveTo() throws {
        // FR-BOT-660. Told to be where it already is, the bot has nothing to obey and
        // goes looking instead (FR-BOT-360, FR-BOT-370).
        let world = try Launch.world().get()
        var bots = try alone(in: world)
        let soldier = try element(.zero, of: bots)
        let here = try XCTUnwrap(Places.part(of: soldier.position, in: world.plan.bounds))
        _ = Execution.deliberate(&bots, slots: [soldier.id], world: world,
                                 command: { _ in self.command(here) })
        if case .moveToOrderedZone = try element(.zero, of: bots).action {
            XCTFail("the bot was sent to the part it was already standing in")
        }
    }

    func testABotOrderedIntoAnotherPartIsGivenACellToMoveTo() throws {
        // The negation of the rule: the same bot, the same order, a part it is not in.
        let world = try Launch.world().get()
        var bots = try alone(in: world)
        let soldier = try element(.zero, of: bots)
        let here = try XCTUnwrap(Places.part(of: soldier.position, in: world.plan.bounds))
        let away = try XCTUnwrap(Places.Part.allCases.first { part in
            guard part != here else { return false }
            let middle = Places.middle(of: part, in: world.plan.bounds)
            return Perception.metres(middle, soldier.position) > world.configurations.bot.groupingDistance
        }, "every part of this arena is within a squad's grouping distance of the other")
        _ = Execution.deliberate(&bots, slots: [soldier.id], world: world,
                                 command: { _ in self.command(away) })
        guard case .moveToOrderedZone = try element(.zero, of: bots).action else {
            XCTFail("a bot ordered across the arena chose \(String(describing: try element(.zero, of: bots).action))")
            return
        }
    }

    func testTwoSquadsEachOrderedOntoItsOwnGroundStillFightEachOther() throws {
        // What the rule is for, measured end to end: a commander that keeps pointing
        // each squad at the ground it already holds used to stop the match dead — no
        // shot fired in a hundred and fifty seconds (ADR-0095). The squads have to
        // find each other anyway.
        let world = try Launch.world().get()
        var game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)),
                        commander: HomeCommander())
        let frame = 1.0 / 60
        var gone: Double?
        for step in 0..<9_000 where game.outcome == nil {
            _ = game.advance(seconds: frame)
            if gone == nil, Squad.allCases.contains(where: { squad in
                !game.bots.contains { $0.squad == squad && $0.isAlive }
            }) {
                gone = Double(step) * frame
            }
        }
        let when = try XCTUnwrap(gone, "in a hundred and fifty seconds neither squad lost a bot")
        XCTAssertLessThan(when, 150, "the war took the whole match")
    }
}

/// A commander that tells a squad to press into the part it is already standing in —
/// the answer a model gives when it has seen nobody, and the one FR-BOT-660 is about.
/// Which squad it is asked about it reads from where that squad's own crew stands,
/// since a call never names the squad (IF-CMD-010).
private final class HomeCommander: Commander, @unchecked Sendable {
    var isAvailable: Bool { true }

    func decide(from state: CommanderInput) async -> Result<CommanderDecision, CommanderFailure> {
        let said = state.crew.first?.place ?? ""
        let part = Places.Part.allCases.first { $0.rawValue == said } ?? .middle
        return .success(CommanderDecision(threat: .enemy, order: .press, place: part,
                                          truce: .none, line: nil))
    }
}
