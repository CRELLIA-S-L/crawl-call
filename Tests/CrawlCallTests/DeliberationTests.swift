// How a bot decides: the set it chooses from (FR-BOT-200), the maximum being what it
// picks (FR-BOT-080), and its personality moving the scores (FR-BOT-090).
//
// The arena is built here rather than loaded, so that what is in the way, where the
// cover is and how far the snake stands are all known quantities.
//
// verifies: FR-BOT-080, FR-BOT-090, FR-BOT-200
import XCTest
@testable import CrawlCall

final class DeliberationTests: XCTestCase {
    private lazy var kit: Kit = { try! Kit.load(named: "blockout", from: .main) }()
    private lazy var configuration: BotConfiguration = { try! Launch.world().get().configurations.bot }()
    private let cell = 0.5

    private func arena(_ rows: String...) throws -> Deliberation.Situation {
        let map = try MapParser.parse("kit blockout\nfloor 0\n" + rows.joined(separator: "\n") + "\n", kit: kit)
        return Deliberation.Situation(plan: ScenePlan.make(map: map, kit: kit, cellSize: cell),
                                      graph: NavigationGraph.derive(from: map),
                                      configuration: configuration,
                                      cellSize: cell)
    }

    private func at(_ x: Int, _ z: Int) -> SIMD3<Double> { SIMD3(Double(x) * cell, 0, Double(z) * cell) }

    private func bot(_ kind: Archetype = .assault, at x: Int, _ z: Int, id: Int = 0) throws -> Bot {
        try XCTUnwrap(Bot(id: id, squad: .red, archetype: kind, at: at(x, z), floor: 0,
                          configuration: configuration))
    }

    private func weights(panic: Double = 0.5, discipline: Double = 0.5,
                         aggression: Double = 0.5, selfSacrifice: Double = 0.5) -> BotConfiguration.Weights {
        BotConfiguration.Weights(panic: panic, discipline: discipline,
                                 aggression: aggression, selfSacrifice: selfSacrifice)
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
        var whole = try bot(.scout, at: 1, 0)
        whole.weights = weights(panic: 0.9)
        XCTAssertEqual(Deliberation.choose(for: whole, in: situation).map(isFire), true)

        var wounded = whole
        wounded.health = 5
        let choice = try XCTUnwrap(Deliberation.choose(for: wounded, in: situation))
        XCTAssertTrue(isFlight(choice) || isCover(choice),
                      "a bot at five health with panic 0.9 chose \(choice)")
    }

    func testTheSnakesPositionMovesTheChoice() throws {
        // Out of detection range there is no snake to act on at all; inside it, the
        // nearer it is the more every snake-shaped action is worth.
        let range = try XCTUnwrap(configuration.archetypes[Archetype.assault.rawValue]).detectionRange
        var near = try arena(String(repeating: ".", count: 60))
        near.snake = [at(4, 0)]
        var far = near
        far.snake = [at(Int((range / cell).rounded(.down)) - 1, 0)]
        let bot = try bot(.assault, at: 1, 0)

        let close = try XCTUnwrap(utility(of: isFire, for: bot, in: near))
        let distant = try XCTUnwrap(utility(of: isFire, for: bot, in: far))
        XCTAssertGreaterThan(close, distant)
    }

    func testALineOfFireIsWhatMakesFiringAvailable() throws {
        var blocked = try arena("...#......")
        blocked.snake = [at(6, 0)]
        let bot = try bot(.assault, at: 0, 0)
        XCTAssertNil(utility(of: isFire, for: bot, in: blocked), "a bot fired through a wall")

        var open = try arena("..........")
        open.snake = [at(6, 0)]
        XCTAssertNotNil(utility(of: isFire, for: bot, in: open))
    }

    func testTheDistanceToCoverMovesItsScore() throws {
        // The same wall, once beside the bot and once at the edge of its search: the
        // nearer cover is worth more.
        var near = try arena("..........",
                             ".#........")
        near.snake = [at(9, 0)]
        var far = try arena("..........",
                            "........#.")
        far.snake = [at(9, 0)]
        let bot = try bot(.assault, at: 1, 0)

        let handy = try XCTUnwrap(utility(of: isCover, for: bot, in: near))
        let distant = try XCTUnwrap(utility(of: isCover, for: bot, in: far))
        XCTAssertGreaterThan(handy, distant)
    }

    // MARK: personality multiplies (FR-BOT-090)

    func testAggressionScalesAttackAndPanicScalesThreat() throws {
        var situation = try arena("..........",
                                  ".#........")
        situation.snake = [at(7, 0)]
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
        // same spot fires when it is aggressive and hides when it is frightened.
        XCTAssertEqual(Deliberation.choose(for: fierce, in: situation).map(isFire), true)
        XCTAssertEqual(Deliberation.choose(for: frightened, in: situation).map(isCover), true)
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

    func testOnlyAMedicHeals() throws {
        var situation = try arena("..........")
        var hurt = try bot(.assault, at: 2, 0, id: 1)
        hurt.health = 20
        situation.allies = [hurt]
        let soldier = try bot(.assault, at: 1, 0)
        XCTAssertNil(utility(of: isHeal, for: soldier, in: situation))
    }
}
