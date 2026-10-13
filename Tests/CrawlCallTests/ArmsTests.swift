// What a bot carries (FR-BOT-440), that the numbers of a shot are the fired weapon's
// and not the bot's (FR-BOT-450), that each weapon which reaches is an action of its
// own (FR-BOT-460), and the bound the shipped table has to keep (INV-BOT-040).
//
// The arena is an open strip, forty metres of it, so that nothing stands between
// anybody and every distance in the test is the one that was asked for.
//
// file verifies: FR-BOT-080, FR-BOT-440, FR-BOT-450, FR-BOT-460, INV-BOT-040, IF-BOT-010
import XCTest
@testable import CrawlCall

final class ArmsTests: XCTestCase {
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

    /// A bot on the strip's middle line at `x` metres, facing +x.
    private func bot(_ id: Int, _ squad: Squad = .red, at x: Double, _ archetype: Archetype = .assault) throws -> Bot {
        var bot = try XCTUnwrap(Bot(id: id, squad: squad, archetype: archetype, at: SIMD3(x, 0, 0.5), floor: 0,
                                    configuration: configuration))
        bot.facing = .pi / 2
        return bot
    }

    /// A shooter at 5 m that knows of an enemy it is looking at, and that enemy.
    private func pair(_ archetype: Archetype = .assault, apart metres: Double) throws -> [Bot] {
        var shooter = try bot(0, at: 5, archetype)
        let enemy = try bot(1, .blue, at: 5 + metres)
        shooter.knowledge.enemies[enemy.id] = .init(point: enemy.position, time: now)
        return [shooter, enemy]
    }

    private func entry(_ archetype: Archetype) throws -> BotConfiguration.Archetype {
        try XCTUnwrap(configuration.archetypes[archetype.rawValue])
    }

    // MARK: what a bot carries (FR-BOT-440)

    func testASpawnedBotCarriesTheFourWeaponsItsArchetypeNames() throws {
        for archetype in Archetype.allCases {
            let named = try entry(archetype).arms
            let arms = try bot(0, at: 5, archetype).arms
            XCTAssertEqual(arms.primary.name, named.primary, "\(archetype) went out with the wrong primary")
            XCTAssertEqual(arms.sidearm.name, named.sidearm, "\(archetype) went out with the wrong sidearm")
            XCTAssertEqual(arms.grenades.name, named.grenade)
            XCTAssertEqual(arms.grenades.left, named.grenadesCarried,
                           "\(archetype) went out with the wrong number of grenades")
            XCTAssertEqual(arms.knife?.name, named.knife, "\(archetype) went out with no knife")
            // Both firearms loaded, and each from its own catalogue entry.
            for slot in Arms.Slot.allCases {
                let firearm = arms[slot]
                XCTAssertEqual(firearm.numbers, configuration.weapons.firearms[firearm.name],
                               "\(archetype)'s \(firearm.name) does not carry the catalogue's numbers")
                XCTAssertEqual(firearm.rounds, firearm.numbers.magazine,
                               "\(archetype) went out with a part-empty \(firearm.name)")
            }
        }
    }

    func testAnArchetypeNamingAWeaponTheCatalogueDoesNotHoldArmsNobody() throws {
        // A typo in the table is a configuration error at the spawn and not a bot that
        // goes out unarmed, the same as an archetype with no entry at all.
        let named = try entry(.assault).arms
        let missing = BotConfiguration.Arms(primary: "sledgehammer", sidearm: named.sidearm,
                                            grenade: named.grenade, grenadesCarried: named.grenadesCarried,
                                            knife: named.knife)
        XCTAssertNil(Arms(missing, from: configuration.weapons), "a weapon nobody has was handed out")
        XCTAssertNotNil(Arms(named, from: configuration.weapons), "the shipped table itself does not resolve")
    }

    // MARK: the bound over the table (INV-BOT-040)

    func testEveryArchetypesPrimaryOutreachesAndOuthitsItsSidearm() throws {
        for archetype in Archetype.allCases {
            let arms = try bot(0, at: 5, archetype).arms
            XCTAssertGreaterThan(arms.primary.numbers.range, arms.sidearm.numbers.range,
                                 "\(archetype)'s \(arms.sidearm.name) reaches as far as its \(arms.primary.name)")
            XCTAssertGreaterThan(arms.primary.numbers.damage, arms.sidearm.numbers.damage,
                                 "\(archetype)'s \(arms.sidearm.name) hits as hard as its \(arms.primary.name)")
            // Which is what makes the primary the weapon a bot reaches for first.
            XCTAssertEqual(arms.strength(of: .primary), 1, accuracy: 1e-12)
            XCTAssertLessThan(arms.strength(of: .sidearm), 1)
        }
    }

    // MARK: a shot's numbers are the weapon's (FR-BOT-450)

    func testTheDamageOfARoundIsTheFiredWeaponsAndNotTheBotsOwn() throws {
        // Two bots of different kinds, the same scene, the same distance: the rounds
        // differ by exactly what their primaries differ by.
        var assault = try pair(.assault, apart: 3)
        var sniper = try pair(.sniper, apart: 3)
        let first = Execution.deliberate(&assault, slots: [0], world: world, now: now)
        let second = Execution.deliberate(&sniper, slots: [0], world: world, now: now)
        let itsOwn = { (bots: [Bot]) in try element(0, of: bots).arms.primary.numbers.damage }
        XCTAssertEqual(try element(0, of: first.rounds).damage, try itsOwn(assault))
        XCTAssertEqual(try element(0, of: second.rounds).damage, try itsOwn(sniper))
        XCTAssertNotEqual(try itsOwn(assault), try itsOwn(sniper),
                          "the two primaries deal the same, and this test proves nothing")
    }

    func testTheMagazineSpentIsTheFiredWeaponsOwn() throws {
        var assault = try pair(.assault, apart: 3)
        var sniper = try pair(.sniper, apart: 3)
        _ = Execution.deliberate(&assault, slots: [0], world: world, now: now)
        _ = Execution.deliberate(&sniper, slots: [0], world: world, now: now)
        for bots in [assault, sniper] {
            let shooter = try element(0, of: bots)
            XCTAssertEqual(shooter.arms.primary.rounds, shooter.arms.primary.numbers.magazine - 1,
                           "a round came out of somewhere other than the weapon fired")
            XCTAssertEqual(shooter.arms.sidearm.rounds, shooter.arms.sidearm.numbers.magazine,
                           "firing the primary spent a round of the sidearm")
        }
        XCTAssertNotEqual(try element(0, of: assault).arms.primary.numbers.magazine,
                          try element(0, of: sniper).arms.primary.numbers.magazine,
                          "the two magazines are the same size, and this test proves nothing")
    }

    func testAWeaponSlowerThanASlotFiresOnItsOwnCadenceAndNotEverySlot() throws {
        // The assault's automatic may fire at every slot; the sniper's rifle waits out
        // its own second. Two slots a deliberation period apart, and the difference is
        // the weapon's and nothing else's.
        let period = configuration.deliberationPeriod
        var assault = try pair(.assault, apart: 3)
        var sniper = try pair(.sniper, apart: 3)
        XCTAssertLessThanOrEqual(try element(0, of: assault).arms.primary.numbers.timeBetweenShots, period)
        XCTAssertGreaterThan(try element(0, of: sniper).arms.primary.numbers.timeBetweenShots, period)
        var fired = (assault: 0, sniper: 0)
        for step in 0...1 {
            let at = now + Double(step) * period
            fired.assault += try slot(&assault, at: at).rounds.count
            fired.sniper += try slot(&sniper, at: at).rounds.count
        }
        XCTAssertEqual(fired.assault, 2, "the automatic skipped a slot it could have fired in")
        XCTAssertEqual(fired.sniper, 1, "the rifle fired twice inside its own second")
        // And once its second has passed it fires again.
        let cadence = try element(0, of: sniper).arms.primary.numbers.timeBetweenShots
        XCTAssertEqual(try slot(&sniper, at: now + cadence).rounds.count, 1, "the rifle never fired again")
    }

    // MARK: each weapon that reaches is an action of its own (FR-BOT-460)

    func testBothFirearmsAreScoredWhereBothReachAndThePrimaryIsTheOneChosen() throws {
        let bots = try pair(.assault, apart: 3)
        let shooter = try element(0, of: bots)
        let situation = try seeing(enemy: try element(1, of: bots), from: shooter)
        let firing = Deliberation.scores(for: shooter, in: situation).filter { isFire($0.action) }
        XCTAssertEqual(firing.count, 2, "two firearms in reach were not two actions")
        XCTAssertEqual(firing.map(\.action), [.fire(at: .bot(id: 1), with: .primary),
                                              .fire(at: .bot(id: 1), with: .sidearm)])
        let best = try XCTUnwrap(firing.max { $0.utility < $1.utility })
        XCTAssertEqual(best.action, .fire(at: .bot(id: 1), with: .primary),
                       "the sidearm outscored the primary with both full")
        XCTAssertEqual(Deliberation.choose(for: shooter, in: situation), best.action)
    }

    func testATargetBeyondASidearmsReachIsNoActionForIt() throws {
        // Seven metres: inside the assault's automatic, outside its pistol.
        let bots = try pair(.assault, apart: 7)
        let shooter = try element(0, of: bots)
        XCTAssertGreaterThan(7, shooter.arms.sidearm.numbers.range)
        XCTAssertLessThan(7, shooter.arms.primary.numbers.range)
        let situation = try seeing(enemy: try element(1, of: bots), from: shooter)
        let firing = Deliberation.scores(for: shooter, in: situation).filter { isFire($0.action) }
        XCTAssertEqual(firing.map(\.action), [.fire(at: .bot(id: 1), with: .primary)],
                       "the pistol was offered a target it cannot reach")
    }

    func testAnEmptyWeaponIsNoActionAndTheOtherStillIs() throws {
        var bots = try pair(.assault, apart: 3)
        let index = try checkedIndex(0, of: bots)
        bots[index].arms.primary.rounds = .zero
        let shooter = try element(0, of: bots)
        let situation = try seeing(enemy: try element(1, of: bots), from: shooter)
        let firing = Deliberation.scores(for: shooter, in: situation).filter { isFire($0.action) }
        XCTAssertEqual(firing.map(\.action), [.fire(at: .bot(id: 1), with: .sidearm)],
                       "an empty primary was still offered as an action")
    }

    func testWithNoReloadToBeHadABotWithADryPrimaryFiresItsSidearm() throws {
        // A bot with every spare magazine spent: reloading is not on its list at all
        // (FR-BOT-540, FR-BOT-560), and what it has left is the sidearm. It is also the
        // one case in which the sidearm is what the scores choose (ADR-0086).
        // Three metres: inside the pistol and outside the knife. With the pouch empty
        // as well, the sidearm is the only thing the bot has left to do.
        var bots = try pair(.assault, apart: 3)
        let index = try checkedIndex(0, of: bots)
        bots[index].arms.primary.rounds = .zero
        bots[index].arms.grenades.left = .zero
        bots[index].spendEverySpare()
        XCTAssertLessThan(try XCTUnwrap(try element(0, of: bots).arms.knife).numbers.reach, 3)
        let volley = Execution.deliberate(&bots, slots: [0], world: world, now: now)
        XCTAssertEqual(try element(0, of: bots).action, .fire(at: .bot(id: 1), with: .sidearm))
        let sidearm = try element(0, of: bots).arms.sidearm
        XCTAssertEqual(try element(0, of: volley.rounds).damage, sidearm.numbers.damage,
                       "the round carried something other than the pistol's damage")
        XCTAssertEqual(sidearm.rounds, sidearm.numbers.magazine - 1, "the round came out of the wrong magazine")
    }

    /// One deliberation slot at `at`, with the shooter seeing the enemy where it
    /// stands at that moment: a bot fires only at what it sees now (FR-BOT-220), and a
    /// sighting a tenth of a second old is not a sighting now.
    private func slot(_ bots: inout [Bot], at: Double) throws -> Execution.Volley {
        let shooter = try checkedIndex(0, of: bots)
        let enemy = try element(1, of: bots)
        bots[shooter].knowledge.enemies[enemy.id] = .init(point: enemy.position, time: at)
        return Execution.deliberate(&bots, slots: [0], world: world, now: at)
    }

    private func isFire(_ action: Action) -> Bool { if case .fire = action { return true }; return false }

    /// What the shooter sees: the enemy in view where it stands, and the shooter's own
    /// knowledge of it.
    private func seeing(enemy: Bot, from shooter: Bot) throws -> Deliberation.Situation {
        var situation = Deliberation.Situation(plan: world.plan, graph: world.graph,
                                               configuration: configuration,
                                               cellSize: world.configurations.tuning.navigationGraphCellSize)
        situation.enemies = [enemy.position]
        situation.enemiesInView = [(id: enemy.id, point: enemy.position)]
        situation.allies = [shooter]
        return situation
    }
}
