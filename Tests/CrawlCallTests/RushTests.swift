// Closing with what a weapon does not reach (FR-BOT-570): a bot whose rifle is dry,
// whose pouch is empty and whose enemy stands beyond the pistol goes to a cell from
// which the pistol reaches — and with nothing but a knife left, to the cell beside it.
//
// The arena is an open strip, so that the ground between a bot and its enemy is ground
// and not a wall.
//
// file verifies: FR-BOT-570
import XCTest
@testable import CrawlCall

final class RushTests: XCTestCase {
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
    private var cell: Double { world.configurations.tuning.navigationGraphCellSize }

    private func bot(_ id: Int, _ squad: Squad = .red, at x: Double) throws -> Bot {
        var made = try XCTUnwrap(Bot(id: id, squad: squad, archetype: .assault, at: SIMD3(x, 0, 0.5), floor: 0,
                                     configuration: configuration))
        made.facing = .pi / 2
        made.knowledge.ways = Set(world.graph.nodes)
        return made
    }

    /// A bot with nothing left but its sidearm: the rifle dry and the pouch empty.
    private func withSidearmOnly(_ bot: Bot) -> Bot {
        var armed = bot
        armed.arms.primary.rounds = .zero
        armed.arms.primary.spares = .zero
        armed.arms.grenades.left = .zero
        return armed
    }

    private func situation(_ bot: Bot, enemy: Bot) -> Deliberation.Situation {
        var made = Deliberation.Situation(plan: world.plan, graph: world.graph, configuration: configuration,
                                          cellSize: cell)
        made.bodyRadius = world.configurations.tuning.bodyRadius
        made.allies = [bot]
        made.enemies = [enemy.position]
        made.enemiesInView = [(id: enemy.id, point: enemy.position)]
        return made
    }

    private func closing(_ bot: Bot, _ enemy: Bot) -> (target: Target, node: NavigationGraph.Node, utility: Double)? {
        for scored in Deliberation.scores(for: bot, in: situation(bot, enemy: enemy)) {
            if case .close(let target, let node) = scored.action {
                return (target: target, node: node, utility: scored.utility)
            }
        }
        return nil
    }

    // MARK: the cell it would reach from

    func testWithOnlyAPistolAndAnEnemyBeyondItTheBotGoesToWhereThePistolReaches() throws {
        let enemy = try bot(1, .blue, at: 13)
        let runner = withSidearmOnly(try bot(0, at: 5))
        let range = runner.arms.sidearm.numbers.range
        XCTAssertLessThan(range, Perception.metres(runner.position, enemy.position),
                          "the enemy is already within the pistol, so this proves nothing")
        let rush = try XCTUnwrap(closing(runner, enemy), "it was offered no way to close with the enemy")
        XCTAssertEqual(rush.target, .bot(id: 1))
        let there = Deliberation.centre(of: rush.node, in: situation(runner, enemy: enemy))
        XCTAssertLessThanOrEqual(Perception.metres(there, enemy.position), range,
                                 "the cell it would run to is still out of the pistol's range")
        XCTAssertGreaterThan(rush.utility, .zero, "the rush was offered at nothing")
    }

    func testTheRushIsWhatTheBotChooses() throws {
        let enemy = try bot(1, .blue, at: 13)
        let runner = withSidearmOnly(try bot(0, at: 5))
        guard case .close = try XCTUnwrap(Deliberation.choose(for: runner, in: situation(runner, enemy: enemy)))
        else { return XCTFail("it chose \(String(describing: Deliberation.choose(for: runner, in: situation(runner, enemy: enemy))))") }
    }

    func testACellFurtherOffIsWorthLessThanOneNearer() throws {
        // The same rush from two distances: crossing the ground costs what it gains.
        let near = try bot(1, .blue, at: 12)
        let far = try bot(1, .blue, at: 14)
        let runner = withSidearmOnly(try bot(0, at: 5))
        let close = try XCTUnwrap(closing(runner, near), "no rush at the nearer enemy")
        let distant = try XCTUnwrap(closing(runner, far), "no rush at the further enemy")
        XCTAssertGreaterThan(close.utility, distant.utility,
                             "running four metres was worth as much as running two")
    }

    // MARK: what is not a rush

    func testAWeaponThatReachesIsAShotAndNotARush() throws {
        let enemy = try bot(1, .blue, at: 10)
        let armed = try bot(0, at: 5)
        XCTAssertGreaterThan(armed.arms.primary.numbers.range, Perception.metres(armed.position, enemy.position),
                             "the rifle does not reach, so this proves nothing")
        XCTAssertNil(closing(armed, enemy), "a bot whose rifle reaches was offered a rush")
    }

    func testAGrenadeInThePouchIsSomethingThatReaches() throws {
        var runner = withSidearmOnly(try bot(0, at: 5))
        runner.arms.grenades.left = 1
        let enemy = try bot(1, .blue, at: 13)
        XCTAssertGreaterThan(runner.arms.grenades.numbers.throwRange,
                             Perception.metres(runner.position, enemy.position),
                             "the grenade does not reach either, so this proves nothing")
        XCTAssertNil(closing(runner, enemy), "a bot with a grenade to throw ran in instead")
    }

    func testAnEnemyOutOfReachOfEverythingAndOfTheWalkIsNoRushEither() throws {
        // Beyond the cover search distance there is no cell to run to within reach, and
        // the action is simply not on the list.
        var runner = withSidearmOnly(try bot(0, at: 5))
        runner.arms.sidearm.rounds = .zero
        runner.arms.knife = nil
        let enemy = try bot(1, .blue, at: 40)
        XCTAssertNil(closing(runner, enemy), "a bot with nothing at all was offered a rush")
    }

    // MARK: the knife rush

    func testWithNothingButAKnifeTheBotRunsToTheCellBesideTheEnemy() throws {
        var runner = withSidearmOnly(try bot(0, at: 5))
        runner.arms.sidearm.rounds = .zero
        runner.arms.sidearm.spares = .zero
        let enemy = try bot(1, .blue, at: 8)
        let knife = try XCTUnwrap(runner.arms.knife).numbers
        XCTAssertLessThan(knife.reach, Perception.metres(runner.position, enemy.position))
        let rush = try XCTUnwrap(closing(runner, enemy), "a bot with a knife and nothing else stood still")
        let seen = situation(runner, enemy: enemy)
        let there = Deliberation.centre(of: rush.node, in: seen)
        XCTAssertLessThanOrEqual(Perception.metres(there, enemy.position), knife.reach,
                                 "the cell it would run to is out of the knife's reach")
        // Beside the enemy and never the enemy's own cell, which it holds (FR-BOT-530).
        let standing = try XCTUnwrap(Deliberation.cell(of: enemy.position, graph: world.graph, cellSize: cell,
                                                       floorHeight: world.plan.floorHeight))
        XCTAssertNotEqual(rush.node, standing, "it ran at the cell the enemy is standing in")
    }

    // MARK: the whole frame

    func testTheBotWalksTheWayItChoseAndFiresOnceItIsThere() throws {
        var bots = [withSidearmOnly(try bot(0, at: 5)), try bot(1, .blue, at: 13)]
        let index = try checkedIndex(0, of: bots)
        let enemy = try element(1, of: bots)
        bots[index].knowledge.enemies = [enemy.id: .init(point: enemy.position, time: now)]
        _ = Execution.deliberate(&bots, slots: [0], world: world, now: now)
        guard case .close(_, let node) = try XCTUnwrap(try element(0, of: bots).action) else {
            return XCTFail("it did not set out, it chose \(String(describing: try element(0, of: bots).action))")
        }
        XCTAssertEqual(Execution.destination(of: try element(0, of: bots)), node, "the rush sends it nowhere")
        // Three seconds of frames: it arrives, and the action is spent by arriving.
        for step in 0..<180 {
            let at = now + Double(step) / 60
            Execution.fill(&bots, now: at)
            Execution.walk(&bots, seconds: 1.0 / 60, world: world, now: at)
        }
        XCTAssertEqual(Execution.cell(of: try element(0, of: bots), world: world), node, "it never got there")
        XCTAssertLessThanOrEqual(Perception.metres(try element(0, of: bots).position,
                                                   try element(1, of: bots).position),
                                 try element(0, of: bots).arms.sidearm.numbers.range,
                                 "it ran and the enemy is still out of the pistol's range")
        // And from there the pistol is what it fires.
        let rival = try element(1, of: bots)
        bots[index].knowledge.enemies = [rival.id: .init(point: rival.position, time: now + 3)]
        let volley = Execution.deliberate(&bots, slots: [0], world: world, now: now + 3)
        XCTAssertEqual(try element(0, of: bots).action, .fire(at: .bot(id: 1), with: .sidearm),
                       "having run into range it did not fire")
        XCTAssertEqual(volley.rounds.count, 1, "it fired nothing")
    }
}
