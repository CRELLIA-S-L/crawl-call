// How a bot decides: the set it chooses from (FR-BOT-200), the maximum being what it
// picks (FR-BOT-080), and its personality moving the scores (FR-BOT-090).
//
// The arena is built here rather than loaded, so that what is in the way, where the
// cover is and how far the snake stands are all known quantities.
//
// file verifies: FR-BOT-080, FR-BOT-090, FR-BOT-118, FR-BOT-200, FR-BOT-210, IF-BOT-010, FR-BOT-220
import XCTest
@testable import CrawlCall

final class DeliberationTests: XCTestCase {
    private var kit: Kit!
    private var configuration: BotConfiguration!

    override func setUpWithError() throws {
        try super.setUpWithError()
        kit = try Kit.load(named: "blockout", from: .main)
        configuration = try Launch.world().get().configurations.bot
    }

    private let cell = 0.5

    private func arena(_ rows: String...) throws -> Deliberation.Situation {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n", kit: kit)
        return Deliberation.Situation(plan: ScenePlan.make(map: map, kit: kit, cellSize: cell),
                                      graph: NavigationGraph.derive(from: map, stepHeight: ShippedTuning.stepHeight),
                                      configuration: configuration,
                                      cellSize: cell)
    }

    private func at(_ x: Int, _ z: Int) -> SIMD3<Double> { SIMD3(Double(x) * cell, 0, Double(z) * cell) }

    private func bot(_ kind: Archetype = .assault, at x: Int, _ z: Int, id: Int = 0) throws -> Bot {
        try XCTUnwrap(Bot(id: id, squad: .red, archetype: kind, at: at(x, z), floor: 0,
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

    private func isFire(_ action: Action) -> Bool { if case .fire = action { return true }; return false }
    private func isCover(_ action: Action) -> Bool { if case .takeCover = action { return true }; return false }
    private func isFlight(_ action: Action) -> Bool { if case .flee = action { return true }; return false }
    private func isZone(_ action: Action) -> Bool { if case .moveToOrderedZone = action { return true }; return false }
    private func isHeal(_ action: Action) -> Bool { if case .heal = action { return true }; return false }

    // MARK: the set to choose from (FR-BOT-200)

    func testAllSixNamedActionsCanBeScored() throws {
        // A medic with a hurt squadmate beside it, a snake in view, cover within
        // reach, a magazine half spent and an order to obey: every action the
        // requirement names is on the list at once.
        var situation = try arena("..........",
                                  "....#.....",
                                  "..........")
        situation.snake = [at(8, 0)]
        situation.inView = situation.snake  // seen now, as these tests pose it (FR-BOT-220)
        situation.orderedZone = NavigationGraph.Node(floor: 0, x: 2, z: 2)
        var hurt = try bot(.assault, at: 1, 1, id: 1)
        hurt.health = 10
        situation.allies = [hurt]

        var medic = try bot(.medic, at: 1, 0)
        medic.ammunition = 15
        let actions = Deliberation.scores(for: medic, in: situation).map(\.action)
        XCTAssertTrue(actions.contains(where: isFire), "fire is not on the list")
        XCTAssertTrue(actions.contains(where: isCover), "taking cover is not on the list")
        XCTAssertTrue(actions.contains(where: isZone), "the ordered zone is not on the list")
        XCTAssertTrue(actions.contains(where: isFlight), "fleeing is not on the list")
        XCTAssertTrue(actions.contains(.reload), "reloading is not on the list")
        XCTAssertTrue(actions.contains(where: isHeal), "healing is not on the list")
    }

    func testAnActionWithNothingToActOnIsNotOnTheList() throws {
        // The other half: a full bot with no snake seen, no order and nobody hurt has
        // nothing to choose, rather than a list of zeroes.
        let situation = try arena("..........")
        let idle = try bot(.assault, at: 1, 0)
        XCTAssertTrue(Deliberation.scores(for: idle, in: situation).isEmpty)
        XCTAssertNil(Deliberation.choose(for: idle, in: situation))
    }

    // MARK: the maximum is what is chosen (FR-BOT-080)

    func testTheChosenActionIsTheHighestScoring() throws {
        var situation = try arena("..........", "..........")
        situation.snake = [at(6, 0)]
        situation.inView = situation.snake  // seen now, as these tests pose it (FR-BOT-220)
        var medic = try bot(.medic, at: 1, 0)
        medic.ammunition = 9
        var hurt = try bot(.heavy, at: 1, 1, id: 1)
        hurt.health = 30
        situation.allies = [hurt]

        let scored = Deliberation.scores(for: medic, in: situation)
        let best = try XCTUnwrap(scored.max { $0.utility < $1.utility })
        XCTAssertGreaterThan(scored.count, 1, "one action is not a choice")
        XCTAssertEqual(Deliberation.choose(for: medic, in: situation), best.action)
    }

    func testAmmunitionMovesTheChoice() throws {
        var situation = try arena("..........")
        situation.snake = [at(5, 0)]
        situation.inView = situation.snake  // seen now, as these tests pose it (FR-BOT-220)
        let armed = try bot(.assault, at: 1, 0)
        XCTAssertEqual(Deliberation.choose(for: armed, in: situation).map(isFire), true)

        var empty = armed
        empty.ammunition = 0
        XCTAssertEqual(Deliberation.choose(for: empty, in: situation), .reload)
        XCTAssertNil(utility(of: isFire, for: empty, in: situation), "an empty bot still offered to fire")
    }

    func testHealthMovesTheChoice() throws {
        var situation = try arena("..........")
        situation.snake = [at(4, 0)]
        situation.inView = situation.snake  // seen now, as these tests pose it (FR-BOT-220)
        var whole = try bot(.scout, at: 1, 0)
        // Panic low enough that the standing fear of FR-BOT-210 does not by itself
        // outrank shooting: what is under test here is the wound, not the panic.
        whole.weights = weights(panic: 0.3)
        XCTAssertEqual(Deliberation.choose(for: whole, in: situation).map(isFire), true)

        var wounded = whole
        wounded.health = 5
        let choice = try XCTUnwrap(Deliberation.choose(for: wounded, in: situation))
        XCTAssertTrue(isFlight(choice) || isCover(choice),
                      "a bot at five health with panic 0.3 chose \(choice)")
    }

    func testTheSnakesPositionMovesTheChoice() throws {
        // Out of detection range there is no snake to act on at all; inside it, the
        // nearer it is the more every snake-shaped action is worth.
        let range = try XCTUnwrap(configuration.archetypes[Archetype.assault.rawValue]).detectionRange
        var near = try arena(String(repeating: ".", count: 60))
        near.snake = [at(4, 0)]
        near.inView = near.snake  // seen now, as these tests pose it (FR-BOT-220)
        var far = near
        far.snake = [at(Int((range / cell).rounded(.down)) - 1, 0)]
        far.inView = far.snake  // seen now, as these tests pose it (FR-BOT-220)
        let bot = try bot(.assault, at: 1, 0)

        let close = try XCTUnwrap(utility(of: isFire, for: bot, in: near))
        let distant = try XCTUnwrap(utility(of: isFire, for: bot, in: far))
        XCTAssertGreaterThan(close, distant)
    }

    func testALineOfFireIsWhatMakesFiringAvailable() throws {
        var blocked = try arena("...#......")
        blocked.snake = [at(6, 0)]
        blocked.inView = blocked.snake  // seen now, as these tests pose it (FR-BOT-220)
        let bot = try bot(.assault, at: 0, 0)
        XCTAssertNil(utility(of: isFire, for: bot, in: blocked), "a bot fired through a wall")

        var open = try arena("..........")
        open.snake = [at(6, 0)]
        open.inView = open.snake  // seen now, as these tests pose it (FR-BOT-220)
        XCTAssertNotNil(utility(of: isFire, for: bot, in: open))
    }

    func testTheDistanceToCoverMovesItsScore() throws {
        // The same wall, once beside the bot and once at the edge of its search: the
        // nearer cover is worth more.
        var near = try arena("..........",
                             ".#........")
        near.snake = [at(9, 0)]
        near.inView = near.snake  // seen now, as these tests pose it (FR-BOT-220)
        var far = try arena("..........",
                            "........#.")
        far.snake = [at(9, 0)]
        far.inView = far.snake  // seen now, as these tests pose it (FR-BOT-220)
        let bot = try bot(.assault, at: 1, 0)

        let handy = try XCTUnwrap(utility(of: isCover, for: bot, in: near))
        let distant = try XCTUnwrap(utility(of: isCover, for: bot, in: far))
        XCTAssertGreaterThan(handy, distant)
    }

    // MARK: where a flight goes (FR-BOT-118)

    func testABotFleesToACellItCanGetTo() throws {
        // A wall across the corridor, with the snake behind the bot: everything on the
        // far side of it lies further from the snake and is worth more to a bot that
        // measures the distance across the map instead of along it.
        var cut = try arena("...#........")
        cut.snake = [at(0, 0)]
        cut.inView = cut.snake  // seen now, as these tests pose it (FR-BOT-220)
        let bot = try bot(.assault, at: 1, 0)

        let flight = try XCTUnwrap(Deliberation.scores(for: bot, in: cut).first { isFlight($0.action) })
        guard case .flee(let node) = flight.action else { return XCTFail("not a flight") }
        let here = NavigationGraph.Node(floor: 0, x: 1, z: 0)
        XCTAssertFalse(Route.between(here, node, in: cut.graph).isEmpty,
                       "the bot set off for a cell with no route to it")
    }

    func testABotWithNowhereToGoDoesNotFlee() throws {
        // Walled in on every side: there is no cell it can get to, so it is not sent
        // to one — the other half of the same rule.
        var boxed = try arena("#####",
                              "#.###",
                              "#####")
        boxed.snake = [at(4, 1)]
        boxed.inView = boxed.snake  // seen now, as these tests pose it (FR-BOT-220)
        let bot = try bot(.assault, at: 1, 1)

        XCTAssertNil(utility(of: isFlight, for: bot, in: boxed))
    }

    // MARK: fear that does not wait for a wound (FR-BOT-210)

    func testAWholeBotStillWantsToRunFromANearSnake() throws {
        // The bot is untouched and the snake is two cells away. Before this rule the
        // urge to run was the fear of a wound already taken, which is nothing at all
        // while the bot is whole — and nothing but the snake's mouth ever wounds one.
        var close = try arena("..........")
        close.snake = [at(2, 0)]
        close.inView = close.snake  // seen now, as these tests pose it (FR-BOT-220)
        let bot = try bot(.assault, at: 0, 0)

        let urge = try XCTUnwrap(utility(of: isFlight, for: bot, in: close))
        XCTAssertGreaterThan(urge, 0)
    }

    func testTheNearerTheSnakeTheStrongerTheUrgeToRun() throws {
        // The bot stands in the middle of the room in both arenas: in a corner, with
        // the snake between it and the rest of the floor, there is nowhere further to
        // go and no flight is scored at all — which is a different rule (FR-BOT-118)
        // and would have made this one look satisfied for the wrong reason.
        var near = try arena("....................")
        near.snake = [at(8, 0)]
        near.inView = near.snake  // seen now, as these tests pose it (FR-BOT-220)
        var far = try arena("....................")
        far.snake = [at(2, 0)]
        far.inView = far.snake  // seen now, as these tests pose it (FR-BOT-220)
        let bot = try bot(.assault, at: 10, 0)

        let pressing = try XCTUnwrap(utility(of: isFlight, for: bot, in: near))
        let distant = try XCTUnwrap(utility(of: isFlight, for: bot, in: far))
        XCTAssertGreaterThan(pressing, distant)
    }

    func testAWoundAddsToTheFearRatherThanBeingAllOfIt() throws {
        // Both halves have to be there: the wound still counts, and it counts on top
        // of the fear rather than instead of it.
        var arena = try arena("..........")
        arena.snake = [at(2, 0)]
        arena.inView = arena.snake  // seen now, as these tests pose it (FR-BOT-220)
        let whole = try bot(.assault, at: 0, 0)
        var hurt = whole
        hurt.health /= 2

        let steady = try XCTUnwrap(utility(of: isFlight, for: whole, in: arena))
        let shaken = try XCTUnwrap(utility(of: isFlight, for: hurt, in: arena))
        XCTAssertGreaterThan(shaken, steady)
    }

    // MARK: personality multiplies (FR-BOT-090)

    func testAggressionScalesAttackAndPanicScalesThreat() throws {
        var situation = try arena("..........",
                                  ".#........")
        situation.snake = [at(7, 0)]
        situation.inView = situation.snake  // seen now, as these tests pose it (FR-BOT-220)
        var calm = try bot(.assault, at: 1, 0)
        calm.weights = weights(panic: 0.2, aggression: 0.2)
        var fierce = calm
        fierce.weights = weights(panic: 0.2, aggression: 0.9)
        var frightened = calm
        frightened.weights = weights(panic: 0.9, aggression: 0.2)

        let attack = try XCTUnwrap(utility(of: isFire, for: calm, in: situation))
        XCTAssertGreaterThan(try XCTUnwrap(utility(of: isFire, for: fierce, in: situation)), attack)
        let threat = try XCTUnwrap(utility(of: isCover, for: calm, in: situation))
        XCTAssertGreaterThan(try XCTUnwrap(utility(of: isCover, for: frightened, in: situation)), threat)
        // And the weights decide the choice, not only the number: the same bot in the
        // same spot fires when it is aggressive, and when it is frightened it answers
        // the threat instead — behind a wall or with its feet, which of the two being
        // FR-BOT-210's business rather than this requirement's.
        XCTAssertEqual(Deliberation.choose(for: fierce, in: situation).map(isFire), true)
        let scared = try XCTUnwrap(Deliberation.choose(for: frightened, in: situation))
        XCTAssertTrue(isCover(scared) || isFlight(scared),
                      "a bot with panic 0.9 and aggression 0.2 chose \(scared)")
    }

    func testDisciplineScalesObedienceAndSelfSacrificeScalesHealing() throws {
        var situation = try arena("..........", "..........")
        situation.orderedZone = NavigationGraph.Node(floor: 0, x: 8, z: 1)
        var hurt = try bot(.assault, at: 2, 0, id: 1)
        hurt.health = 20
        situation.allies = [hurt]

        var slack = try bot(.medic, at: 1, 0)
        slack.weights = weights(discipline: 0.2, selfSacrifice: 0.2)
        var dutiful = slack
        dutiful.weights = weights(discipline: 0.9, selfSacrifice: 0.2)
        var selfless = slack
        selfless.weights = weights(discipline: 0.2, selfSacrifice: 0.9)

        XCTAssertGreaterThan(try XCTUnwrap(utility(of: isZone, for: dutiful, in: situation)),
                             try XCTUnwrap(utility(of: isZone, for: slack, in: situation)))
        XCTAssertGreaterThan(try XCTUnwrap(utility(of: isHeal, for: selfless, in: situation)),
                             try XCTUnwrap(utility(of: isHeal, for: slack, in: situation)))
        XCTAssertEqual(Deliberation.choose(for: selfless, in: situation).map(isHeal), true)
    }

    func testCourageScalesFiringAtTheDanger() throws {
        // The first of the two terms courage pulls on: what it is worth to stand and
        // shoot at the thing that can kill you.
        var situation = try arena("..........")
        situation.snake = [at(5, 0)]
        situation.inView = situation.snake  // seen now, as these tests pose it (FR-BOT-220)
        var timid = try bot(.assault, at: 1, 0)
        timid.weights = weights(courage: 0.1)
        var brave = timid
        brave.weights = weights(courage: 0.9)

        XCTAssertGreaterThan(try XCTUnwrap(utility(of: isFire, for: brave, in: situation)),
                             try XCTUnwrap(utility(of: isFire, for: timid, in: situation)))
    }

    func testCourageScalesHoldingGroundUnderDanger() throws {
        // The second term: the order kept while the snake is on top of the bot. Both
        // bots have the same discipline, so what moves the score is courage alone.
        // The wall is there for the threat term to have somewhere to send them, so
        // that the two scores can be compared as well as the order's.
        var situation = try arena("..........", ".#........")
        situation.orderedZone = NavigationGraph.Node(floor: 0, x: 8, z: 1)
        situation.snake = [at(3, 0)]
        situation.inView = situation.snake
        var timid = try bot(.assault, at: 1, 0)
        timid.weights = weights(panic: 0.5, discipline: 0.5, courage: 0.1)
        var brave = timid
        brave.weights = weights(panic: 0.5, discipline: 0.5, courage: 0.9)

        XCTAssertGreaterThan(try XCTUnwrap(utility(of: isZone, for: brave, in: situation)),
                             try XCTUnwrap(utility(of: isZone, for: timid, in: situation)))
        // Courage and panic pull on different terms, which is why courage is a weight
        // of its own and not the other side of panic: the two bots fear the snake
        // exactly alike and differ only in whether they stay where they were sent.
        XCTAssertEqual(try XCTUnwrap(utility(of: isCover, for: brave, in: situation)),
                       try XCTUnwrap(utility(of: isCover, for: timid, in: situation)),
                       accuracy: 1e-12)
    }

    func testAnEnemyIsADangerToHoldGroundUnderToo() throws {
        // Not only the snake: an enemy bot it has seen is a danger as well
        // (FR-BOT-330), so courage answers to it in the same term.
        var situation = try arena("..........", "..........")
        situation.orderedZone = NavigationGraph.Node(floor: 0, x: 8, z: 1)
        situation.enemies = [at(3, 0)]
        var timid = try bot(.assault, at: 1, 0)
        timid.weights = weights(discipline: 0.5, courage: 0.1)
        var brave = timid
        brave.weights = weights(discipline: 0.5, courage: 0.9)

        XCTAssertGreaterThan(try XCTUnwrap(utility(of: isZone, for: brave, in: situation)),
                             try XCTUnwrap(utility(of: isZone, for: timid, in: situation)))
    }

    func testCourageLeavesAnOrderAloneWithNothingNear() throws {
        // The negation, and what keeps courage from being a second discipline: with
        // no danger known, holding a position is obedience and courage does not
        // touch it.
        var situation = try arena("..........", "..........")
        situation.orderedZone = NavigationGraph.Node(floor: 0, x: 8, z: 1)
        var timid = try bot(.assault, at: 1, 0)
        timid.weights = weights(discipline: 0.5, courage: 0.1)
        var brave = timid
        brave.weights = weights(discipline: 0.5, courage: 0.9)

        XCTAssertEqual(try XCTUnwrap(utility(of: isZone, for: brave, in: situation)),
                       try XCTUnwrap(utility(of: isZone, for: timid, in: situation)),
                       accuracy: 1e-12)
    }

    func testOnlyAMedicHeals() throws {
        var situation = try arena("..........")
        var hurt = try bot(.assault, at: 2, 0, id: 1)
        hurt.health = 20
        situation.allies = [hurt]
        let soldier = try bot(.assault, at: 1, 0)
        XCTAssertNil(utility(of: isHeal, for: soldier, in: situation))
    }

    // MARK: the mix is the configuration's (IF-BOT-010)

    /// The shipped bot configuration with one term's weight replaced.
    private func configuration(obedience: Double) throws -> BotConfiguration {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "bot", withExtension: "json", subdirectory: "config"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var terms = try XCTUnwrap(json["utilityTermWeights"] as? [String: Any])
        terms["obedience"] = obedience
        json["utilityTermWeights"] = terms
        return try Configurations.decode(BotConfiguration.self, named: "bot", schema: BotConfiguration.schema,
                                         from: JSONSerialization.data(withJSONObject: json))
    }

    func testTheWeightOfATermIsReadFromTheConfiguration() throws {
        // Obeying is worth the obedience weight times the bot's discipline, and with
        // no danger near that is all of it, so doubling the weight in the file doubles
        // the score — which it cannot do if the weight is anywhere but in the file.
        var situation = try arena("..........")
        situation.orderedZone = NavigationGraph.Node(floor: 0, x: 8, z: 0)
        let soldier = try bot(.assault, at: 1, 0)

        let once = try XCTUnwrap(utility(of: isZone, for: soldier, in: Deliberation.Situation(
            orderedZone: situation.orderedZone, plan: situation.plan, graph: situation.graph,
            configuration: try configuration(obedience: 1), cellSize: cell)))
        let twice = try XCTUnwrap(utility(of: isZone, for: soldier, in: Deliberation.Situation(
            orderedZone: situation.orderedZone, plan: situation.plan, graph: situation.graph,
            configuration: try configuration(obedience: 2), cellSize: cell)))
        XCTAssertGreaterThan(once, 0)
        XCTAssertEqual(twice, 2 * once, accuracy: 1e-12)
    }
}
