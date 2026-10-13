// The knife: struck at the reach of an arm (FR-BOT-510) and thrown a little further
// at the cost of having one at all (FR-BOT-520).
//
// The arena is an open strip, so that what the knife does is not confused with what
// stands between anybody.
//
// file verifies: FR-BOT-080, FR-BOT-510, FR-BOT-520
import XCTest
@testable import CrawlCall

final class KnifeTests: XCTestCase {
    private var shipped: World!
    private var world: World!
    private let now = 10.0

    override func setUpWithError() throws {
        try super.setUpWithError()
        shipped = try Launch.world().get()
        let rows = Array(repeating: String(repeating: ".", count: 80), count: 3)
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        let cell = shipped.configurations.tuning.navigationGraphCellSize
        world = World(configurations: shipped.configurations, kit: shipped.kit, map: map, setting: shipped.setting,
                      graph: NavigationGraph.derive(from: map, stepHeight: shipped.configurations.tuning.stepHeight),
                      plan: ScenePlan.make(map: map, kit: shipped.kit, cellSize: cell))
    }

    private var configuration: BotConfiguration { world.configurations.bot }

    private func bot(_ id: Int, _ squad: Squad = .red, at x: Double) throws -> Bot {
        var bot = try XCTUnwrap(Bot(id: id, squad: squad, archetype: .assault, at: SIMD3(x, 0, 0.5), floor: 0,
                                    configuration: configuration))
        bot.facing = .pi / 2
        return bot
    }

    /// A shooter at 5 m seeing an enemy `metres` away, with as much of its primary left
    /// as asked for.
    private func pair(apart metres: Double, rounds: Int) throws -> [Bot] {
        var shooter = try bot(0, at: 5)
        let enemy = try bot(1, .blue, at: 5 + metres)
        shooter.knowledge.enemies[enemy.id] = .init(point: enemy.position, time: now)
        shooter.arms.primary.rounds = rounds
        return [shooter, enemy]
    }

    private func knife(of bot: Bot) throws -> BotConfiguration.Knife {
        try XCTUnwrap(bot.arms.knife).numbers
    }

    // MARK: at the reach of an arm (FR-BOT-510)

    func testAStrikeWithinReachDealsTheKnifesDamageToWhatItStruck() throws {
        var bots = try pair(apart: 1, rounds: 15)
        let reach = try knife(of: try element(0, of: bots)).reach
        XCTAssertGreaterThan(reach, 1, "the enemy this test puts within reach is not")
        let whole = try element(1, of: bots).health
        _ = Execution.deliberate(&bots, slots: [0], world: world, now: now)
        XCTAssertEqual(try element(0, of: bots).action, .strike(at: .bot(id: 1)), "it did not strike")
        XCTAssertEqual(try element(1, of: bots).health, whole - (try knife(of: try element(0, of: bots)).damage),
                       "the enemy took something other than the knife's damage")
        XCTAssertNotNil(try element(0, of: bots).arms.knife, "striking cost the bot its knife")
    }

    func testBeyondItsReachTheKnifeIsNoActionAtAll() throws {
        let bots = try pair(apart: 3, rounds: 15)
        let shooter = try element(0, of: bots)
        XCTAssertLessThan(try knife(of: shooter).reach, 3)
        var situation = Deliberation.Situation(plan: world.plan, graph: world.graph,
                                               configuration: configuration,
                                               cellSize: world.configurations.tuning.navigationGraphCellSize)
        situation.enemies = [try element(1, of: bots).position]
        situation.enemiesInView = [(id: 1, point: try element(1, of: bots).position)]
        situation.allies = [shooter]
        let scored = Deliberation.scores(for: shooter, in: situation)
        XCTAssertNil(scored.first { if case .strike = $0.action { return true }; return false },
                     "a bot three metres off was offered a strike with a knife an arm long")
    }

    func testAStrikeIsSwungOnTheKnifesOwnTimeAndNotAtEverySlot() throws {
        var bots = try pair(apart: 1, rounds: 15)
        let numbers = try knife(of: try element(0, of: bots))
        XCTAssertGreaterThan(numbers.timeBetweenStrikes, configuration.deliberationPeriod,
                             "the knife is quicker than a slot, and this test proves nothing")
        let whole = try element(1, of: bots).health
        for step in 0...1 {
            let at = now + Double(step) * configuration.deliberationPeriod
            let shooter = try checkedIndex(0, of: bots)
            let enemy = try element(1, of: bots)
            bots[shooter].knowledge.enemies[enemy.id] = .init(point: enemy.position, time: at)
            _ = Execution.deliberate(&bots, slots: [0], world: world, now: at)
        }
        XCTAssertEqual(try element(1, of: bots).health, whole - numbers.damage,
                       "the knife was swung twice inside its own second")
        // And once its time has passed it is swung again.
        let later = now + numbers.timeBetweenStrikes
        let shooter = try checkedIndex(0, of: bots)
        let enemy = try element(1, of: bots)
        bots[shooter].knowledge.enemies[enemy.id] = .init(point: enemy.position, time: later)
        _ = Execution.deliberate(&bots, slots: [0], world: world, now: later)
        XCTAssertEqual(try element(1, of: bots).health, whole - 2 * numbers.damage, "it never struck again")
    }

    // MARK: thrown and gone (FR-BOT-520)

    func testAThrownKnifeLeavesTheBotWhateverItStruck() throws {
        // Everything else spent and no spare magazine left to reload with (FR-BOT-540,
        // FR-BOT-560), so that the knife is the last thing the bot has to throw.
        var bots = try pair(apart: 3, rounds: 0)
        let index = try checkedIndex(0, of: bots)
        bots[index].arms.sidearm.rounds = .zero
        bots[index].arms.grenades.left = .zero
        bots[index].spendEverySpare()
        let numbers = try knife(of: try element(0, of: bots))
        let volley = Execution.deliberate(&bots, slots: [0], world: world, now: now)
        XCTAssertEqual(try element(0, of: bots).action, .throwKnife(at: .bot(id: 1)), "it did not throw the knife")
        XCTAssertNil(try element(0, of: bots).arms.knife, "it threw the knife and still has it")
        XCTAssertEqual(try element(0, of: volley.rounds).damage, numbers.damage,
                       "what flew carried something other than the knife's damage")

        // It is gone whether it struck or not: the enemy is taken out of the arena
        // before anything lands, and the bot is still without a knife.
        var alone = [try element(0, of: bots)]
        var flying = volley.rounds
        while !flying.isEmpty {
            _ = Flight.fly(&flying, seconds: 1.0 / 60, bots: &alone, snake: [], plan: world.plan,
                           configuration: configuration, bodyRadius: world.configurations.tuning.bodyRadius)
        }
        XCTAssertNil(try element(0, of: alone).arms.knife, "a knife that struck nothing came back")
        XCTAssertEqual(try element(0, of: bots).arms.knife, nil)
    }

    func testWithTheKnifeGoneNeitherStrikingNorThrowingIsAnActionAnyMore() throws {
        var bots = try pair(apart: 1, rounds: 15)
        let index = try checkedIndex(0, of: bots)
        bots[index].arms.throwKnife()
        var situation = Deliberation.Situation(plan: world.plan, graph: world.graph,
                                               configuration: configuration,
                                               cellSize: world.configurations.tuning.navigationGraphCellSize)
        situation.enemies = [try element(1, of: bots).position]
        situation.enemiesInView = [(id: 1, point: try element(1, of: bots).position)]
        situation.allies = [try element(0, of: bots)]
        let scored = Deliberation.scores(for: try element(0, of: bots), in: situation)
        XCTAssertNil(scored.first { if case .strike = $0.action { return true }; return false },
                     "a bot with no knife was offered a strike")
        XCTAssertNil(scored.first { if case .throwKnife = $0.action { return true }; return false },
                     "a bot with no knife was offered a throw")
    }
}
