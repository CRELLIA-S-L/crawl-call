// Reloading: one action per firearm (FR-BOT-540), each taking that firearm's own time
// (FR-BOT-550) and spending one of the spare magazines carried for it (FR-BOT-560) —
// and the choice between filling a magazine and closing with what the bot has left
// turning on how brave it is (FR-BOT-090).
//
// The arena is an open strip, so that nothing a wall does is read as something a
// magazine did.
//
// file verifies: FR-BOT-540, FR-BOT-550, FR-BOT-560, FR-BOT-090
import XCTest
@testable import CrawlCall

final class ReloadTests: XCTestCase {
    private var shipped: World!
    private var world: World!
    private let now = 10.0
    private let frame = 1.0 / 60

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
        var made = try XCTUnwrap(Bot(id: id, squad: squad, archetype: .assault, at: SIMD3(x, 0, 0.5), floor: 0,
                                     configuration: configuration))
        made.facing = .pi / 2
        made.knowledge.ways = Set(world.graph.nodes)
        return made
    }

    /// The shipped assault's weights with one of them changed: what isolates the one
    /// FR-BOT-090 is about.
    private func courage(_ value: Double, of bot: Bot) -> BotConfiguration.Weights {
        BotConfiguration.Weights(panic: bot.weights.panic, discipline: bot.weights.discipline,
                                 aggression: bot.weights.aggression, selfSacrifice: bot.weights.selfSacrifice,
                                 courage: value, greed: bot.weights.greed)
    }

    private func situation(_ allies: [Bot] = []) -> Deliberation.Situation {
        var made = Deliberation.Situation(plan: world.plan, graph: world.graph, configuration: configuration,
                                          cellSize: world.configurations.tuning.navigationGraphCellSize)
        made.bodyRadius = world.configurations.tuning.bodyRadius
        made.allies = allies
        return made
    }

    private func reloads(of bot: Bot) -> [Arms.Slot] {
        Deliberation.scores(for: bot, in: situation([bot])).compactMap {
            if case .reload(let slot) = $0.action { return slot }
            return nil
        }
    }

    // MARK: one action per firearm (FR-BOT-540)

    func testEachFirearmThatIsNotFullIsAReloadOfItsOwn() throws {
        var bot = try bot(0, at: 5)
        bot.emptyEveryFirearm()
        XCTAssertEqual(Set(reloads(of: bot)), Set(Arms.Slot.allCases),
                       "two dry firearms were not two reloads")
    }

    func testAFullFirearmIsNoReloadAtAll() throws {
        var bot = try bot(0, at: 5)
        bot.arms.sidearm.rounds = .zero
        XCTAssertEqual(reloads(of: bot), [.sidearm], "the full primary was offered a reload of its own")
    }

    func testAFirearmWithNoSpareMagazineLeftIsNoReloadEither() throws {
        var bot = try bot(0, at: 5)
        bot.emptyEveryFirearm()
        bot.arms.primary.spares = .zero
        XCTAssertEqual(reloads(of: bot), [.sidearm], "a firearm with nothing to fill it from was offered")
    }

    func testTheWeaponWorthMoreIsTheOneFilledFirst() throws {
        // Both dry, both with spares: the scores and not a rule say which magazine
        // matters, and the primary hits harder (INV-BOT-040).
        var bot = try bot(0, at: 5)
        bot.emptyEveryFirearm()
        let scored = Deliberation.scores(for: bot, in: situation([bot]))
        let primary = try XCTUnwrap(scored.first { $0.action == .reload(.primary) }?.utility)
        let sidearm = try XCTUnwrap(scored.first { $0.action == .reload(.sidearm) }?.utility)
        XCTAssertGreaterThan(primary, sidearm, "filling the pistol was worth as much as filling the rifle")
        XCTAssertEqual(Deliberation.choose(for: bot, in: situation([bot])), .reload(.primary))
    }

    func testAHalfSpentMagazineIsWorthLessThanADryOne() throws {
        var dry = try bot(0, at: 5)
        dry.arms.primary.rounds = .zero
        var half = try bot(1, at: 5)
        half.arms.primary.rounds = half.arms.primary.numbers.magazine / 2
        func worth(_ bot: Bot) throws -> Double {
            try XCTUnwrap(Deliberation.scores(for: bot, in: situation([bot]))
                .first { $0.action == .reload(.primary) }?.utility)
        }
        XCTAssertGreaterThan(try worth(dry), try worth(half),
                             "a magazine half spent was worth filling as much as an empty one")
    }

    // MARK: the weapon's own time (FR-BOT-550)

    func testTheMagazineIsStillEmptyTheFrameAfterTheReloadBegan() throws {
        var bots = [try bot(0, at: 5)]
        let index = try checkedIndex(0, of: bots)
        bots[index].arms.primary.rounds = .zero
        _ = Execution.deliberate(&bots, slots: [0], world: world, now: now)
        XCTAssertEqual(try element(0, of: bots).action, .reload(.primary), "it did not reload")
        let numbers = try element(0, of: bots).arms.primary.numbers
        XCTAssertGreaterThan(numbers.reloadTime, frame, "the reload is quicker than a frame, so this proves nothing")
        Execution.frames(1, of: &bots, world: world, from: now)
        XCTAssertEqual(try element(0, of: bots).arms.primary.rounds, .zero,
                       "the magazine filled in the frame the reload began")
        XCTAssertNotNil(try element(0, of: bots).reloading, "the reload was forgotten in the frame it began")
    }

    func testTheMagazineFillsOnceTheWeaponsOwnTimeHasPassed() throws {
        var bots = [try bot(0, at: 5)]
        let index = try checkedIndex(0, of: bots)
        bots[index].arms.primary.rounds = .zero
        let numbers = bots[index].arms.primary.numbers
        _ = Execution.deliberate(&bots, slots: [0], world: world, now: now)
        Execution.frames(1, of: &bots, world: world, from: now + numbers.reloadTime - frame)
        XCTAssertEqual(try element(0, of: bots).arms.primary.rounds, .zero, "it filled before its time")
        Execution.frames(1, of: &bots, world: world, from: now + numbers.reloadTime)
        XCTAssertEqual(try element(0, of: bots).arms.primary.rounds, numbers.magazine, "it never filled")
        XCTAssertNil(try element(0, of: bots).action, "the reload is over and the bot is still at it")
        XCTAssertNil(try element(0, of: bots).reloading)
    }

    func testThePistolFillsSoonerThanTheRifle() throws {
        // Each weapon's own time and not one time for the bot (FR-BOT-550, IF-BOT-010).
        var bots = [try bot(0, at: 5)]
        let index = try checkedIndex(0, of: bots)
        bots[index].arms.primary.spares = .zero
        bots[index].arms.sidearm.rounds = .zero
        let pistol = bots[index].arms.sidearm.numbers
        let rifle = bots[index].arms.primary.numbers
        XCTAssertLessThan(pistol.reloadTime, rifle.reloadTime, "the two take the same time, so this proves nothing")
        _ = Execution.deliberate(&bots, slots: [0], world: world, now: now)
        XCTAssertEqual(try element(0, of: bots).action, .reload(.sidearm))
        Execution.frames(1, of: &bots, world: world, from: now + pistol.reloadTime)
        XCTAssertEqual(try element(0, of: bots).arms.sidearm.rounds, pistol.magazine,
                       "the pistol waited out the rifle's time")
    }

    func testAReloadGivenUpForSomethingElseIsLostAndStartsAgain() throws {
        // It begins to reload; an enemy comes within reach of its knife and it strikes
        // instead, which ends the reload; the enemy gone, it begins again — and the
        // magazine fills a reload time after the second beginning, not the first.
        var bots = [try bot(0, at: 5), try bot(1, .blue, at: 6)]
        let index = try checkedIndex(0, of: bots)
        bots[index].arms.primary.rounds = .zero
        bots[index].weights = courage(0.9, of: bots[index])
        let numbers = bots[index].arms.primary.numbers
        _ = Execution.deliberate(&bots, slots: [0], world: world, now: now)
        XCTAssertEqual(try element(0, of: bots).action, .reload(.primary), "it did not begin to reload")

        let seen = now + numbers.reloadTime / 2
        let rival = try element(1, of: bots)
        bots[index].knowledge.enemies = [rival.id: .init(point: rival.position, time: seen)]
        _ = Execution.deliberate(&bots, slots: [0], world: world, now: seen)
        XCTAssertEqual(try element(0, of: bots).action, .strike(at: .bot(id: 1)), "the enemy at its elbow was ignored")
        XCTAssertNil(try element(0, of: bots).reloading, "it kept the reload it walked away from")

        // The enemy forgotten, it reloads again from the beginning.
        bots[index].knowledge.enemies = [:]
        let again = seen + frame
        _ = Execution.deliberate(&bots, slots: [0], world: world, now: again)
        XCTAssertEqual(try element(0, of: bots).action, .reload(.primary), "it did not begin again")
        Execution.frames(1, of: &bots, world: world, from: now + numbers.reloadTime)
        XCTAssertEqual(try element(0, of: bots).arms.primary.rounds, .zero,
                       "the abandoned reload counted towards the second one")
        Execution.frames(1, of: &bots, world: world, from: again + numbers.reloadTime)
        XCTAssertEqual(try element(0, of: bots).arms.primary.rounds, numbers.magazine,
                       "the second reload never finished")
    }

    func testAReloadDoesNotHoldTheBotWhereItStands() throws {
        // Unlike the snake's meal (FR-SNAKE-090): a bot reloading walks to the cell it
        // reloads in, and a bot frozen for two seconds while the snake arrives is the
        // standing still the concept calls the signature stupidity.
        var bots = [try bot(0, at: 5)]
        let index = try checkedIndex(0, of: bots)
        bots[index].arms.primary.rounds = .zero
        bots[index].action = .reload(.primary)
        bots[index].reloading = Reload(slot: .primary, due: now + 2)
        let refuge = NavigationGraph.Node(floor: 0, x: 14, z: 1)
        bots[index].post = NavigationGraph.Node(floor: 0, x: 13, z: 1)
        bots[index].refuge = refuge
        let from = Execution.cell(of: try element(0, of: bots), world: world)
        XCTAssertNotEqual(from, refuge, "it starts in the cell it reloads in, so this proves nothing")
        Execution.frames(60, of: &bots, world: world, from: now)
        XCTAssertEqual(Execution.cell(of: try element(0, of: bots), world: world), refuge,
                       "a reloading bot stood where it was instead of walking to the cell it reloads in")
    }

    // MARK: a limited number of spares (FR-BOT-560)

    func testEachReloadSpendsOneSpareMagazine() throws {
        var bots = [try bot(0, at: 5)]
        let index = try checkedIndex(0, of: bots)
        let numbers = bots[index].arms.primary.numbers
        let spares = bots[index].arms.primary.spares
        XCTAssertGreaterThan(spares, .zero, "the shipped rifle carries no spare at all")
        bots[index].arms.primary.rounds = .zero
        _ = Execution.deliberate(&bots, slots: [0], world: world, now: now)
        Execution.frames(1, of: &bots, world: world, from: now + numbers.reloadTime)
        XCTAssertEqual(try element(0, of: bots).arms.primary.rounds, numbers.magazine)
        XCTAssertEqual(try element(0, of: bots).arms.primary.spares, spares - 1,
                       "filling the magazine cost something other than one spare")
    }

    func testWithTheLastSpareSpentTheWeaponStaysEmpty() throws {
        var bots = [try bot(0, at: 5)]
        let index = try checkedIndex(0, of: bots)
        let numbers = bots[index].arms.primary.numbers
        let spares = bots[index].arms.primary.spares
        // Empty it and fill it as many times as it has spares, each time waiting out
        // the weapon's own time.
        var at = now
        for round in 1...spares {
            bots[index].arms.primary.rounds = .zero
            _ = Execution.deliberate(&bots, slots: [0], world: world, now: at)
            XCTAssertEqual(try element(0, of: bots).action, .reload(.primary),
                           "it would not reload with \(spares - round + 1) spares left")
            at += numbers.reloadTime
            Execution.frames(1, of: &bots, world: world, from: at)
            XCTAssertEqual(try element(0, of: bots).arms.primary.rounds, numbers.magazine,
                           "reload \(round) of \(spares) never finished")
            at += frame
        }
        XCTAssertEqual(try element(0, of: bots).arms.primary.spares, .zero, "the spares were never spent")

        // And now the magazine it has is the last one it will have.
        bots[index].arms.primary.rounds = .zero
        XCTAssertFalse(reloads(of: try element(0, of: bots)).contains(.primary),
                       "a bot out of spares was offered a reload")
        _ = Execution.deliberate(&bots, slots: [0], world: world, now: at)
        XCTAssertNotEqual(try element(0, of: bots).action, .reload(.primary), "it reloaded from nothing")
        Execution.frames(Int(numbers.reloadTime / frame) + 2, of: &bots, world: world, from: at)
        XCTAssertEqual(try element(0, of: bots).arms.primary.rounds, .zero, "the magazine filled itself")
    }

    // MARK: courage decides whether to pay (FR-BOT-090)

    func testABraveBotClosesWithItsKnifeWhereATimidOneReloads() throws {
        // Two bots differing in nothing but courage — 0.7, the assault's, and 0.3, the
        // scout's — each with a dry rifle and an enemy at its elbow.
        var brave = try bot(0, at: 5)
        var timid = try bot(0, at: 5)
        brave.weights = courage(0.7, of: brave)
        timid.weights = courage(0.3, of: timid)
        let enemy = try bot(1, .blue, at: 6)
        func choice(_ bot: Bot) -> Action? {
            var seen = situation([bot])
            seen.enemies = [enemy.position]
            seen.enemiesInView = [(id: enemy.id, point: enemy.position)]
            return Deliberation.choose(for: bot, in: seen)
        }
        brave.arms.primary.rounds = .zero
        timid.arms.primary.rounds = .zero
        XCTAssertEqual(choice(brave), .strike(at: .bot(id: 1)), "the brave bot hid to reload")
        XCTAssertEqual(choice(timid), .reload(.primary), "the timid bot charged in")
    }

    func testCourageOnlyTakesAShareOfTheWishToReload() throws {
        // A fearless bot still fills its magazine when there is nothing else to do.
        var fearless = try bot(0, at: 5)
        fearless.weights = courage(Fraction.whole, of: fearless)
        fearless.arms.primary.rounds = .zero
        XCTAssertEqual(Deliberation.choose(for: fearless, in: situation([fearless])), .reload(.primary),
                       "a bot of whole courage would not reload at all")
    }
}
