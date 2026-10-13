// The time a weapon keeps for itself: every use counts from its own last one
// (FR-BOT-610), and one whose time has not come is not an action at all
// (FR-BOT-600).
//
// The arena is an open strip, as the knife's own tests use, so that what is being
// measured is the clock and not what stands between anybody.
//
// file verifies: FR-BOT-600, FR-BOT-610
import XCTest
@testable import CrawlCall

final class WeaponTimeTests: XCTestCase {
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

    /// A bot at 5 m with an enemy `metres` further east, each knowing of the other.
    private func pair(apart metres: Double) throws -> [Bot] {
        var shooter = try bot(0, at: 5)
        let enemy = try bot(1, .blue, at: 5 + metres)
        shooter.knowledge.enemies[enemy.id] = .init(point: enemy.position, time: now)
        return [shooter, enemy]
    }

    private func situation(_ bots: [Bot]) throws -> Deliberation.Situation {
        var situation = Deliberation.Situation(plan: world.plan, graph: world.graph,
                                              configuration: configuration,
                                              cellSize: world.configurations.tuning.navigationGraphCellSize)
        let enemy = try element(1, of: bots)
        situation.enemies = [enemy.position]
        situation.enemiesInView = [(id: enemy.id, point: enemy.position)]
        situation.allies = [try element(0, of: bots)]
        situation.now = now
        return situation
    }

    private func has(_ scored: [(action: Action, utility: Double)], _ match: (Action) -> Bool) -> Bool {
        scored.contains { match($0.action) }
    }

    private func isStrike(_ action: Action) -> Bool { if case .strike = action { return true }; return false }
    private func isPrimaryShot(_ action: Action) -> Bool {
        if case .fire(_, let slot) = action { return slot == .primary }
        return false
    }

    // MARK: the clock each use keeps (FR-BOT-610)

    func testAUseNeverTakenIsReadyWheneverItIsAsked() throws {
        let arms = try XCTUnwrap(try element(0, of: try pair(apart: 1)).arms as Arms?)
        for use in Arms.uses {
            XCTAssertTrue(arms.ready(use, at: .zero), "a weapon nobody has used yet was held back at the whistle")
            XCTAssertTrue(arms.ready(use, at: now), "a weapon nobody has used yet was held back")
        }
    }

    func testAUseTakenHoldsThatWeaponBackForItsOwnTimeAndNoLonger() throws {
        var arms = try element(0, of: try pair(apart: 1)).arms
        let between = arms.between(.firearm(.primary))
        XCTAssertGreaterThan(between, .zero, "the primary has no time between shots, and this test proves nothing")
        arms.spend(.shot(.primary), at: now)
        XCTAssertFalse(arms.ready(.shot(.primary), at: now), "it was ready to fire again in the same instant")
        XCTAssertFalse(arms.ready(.shot(.primary), at: now + between / 2),
                       "it was ready to fire again half way through its own time")
        XCTAssertTrue(arms.ready(.shot(.primary), at: now + between), "its time passed and it was still held back")
    }

    func testOneWeaponsUseLeavesEveryOtherWeaponReady() throws {
        var arms = try element(0, of: try pair(apart: 1)).arms
        for taken in Arms.uses where arms.left(of: taken) > .zero
            && arms.between(Arms.piece(of: taken)) > .zero {
            var after = arms
            after.spend(taken, at: now)
            for other in Arms.uses where Arms.piece(of: other) != Arms.piece(of: taken) {
                XCTAssertTrue(after.ready(other, at: now),
                              "using one weapon held another back in the same instant")
            }
        }
        // The pair the maintainer found it by: a shot must not push the knife's next
        // strike away, nor a strike the next shot.
        var fired = arms
        fired.spend(.shot(.primary), at: now)
        XCTAssertTrue(fired.ready(.strike, at: now), "firing pushed the knife's next strike away")
        var struck = arms
        struck.spend(.strike, at: now)
        XCTAssertTrue(struck.ready(.shot(.primary), at: now), "striking pushed the next shot away")
        XCTAssertFalse(struck.ready(.strike, at: now), "the knife was ready to swing again in the same instant")
        arms.spend(.strike, at: now)
        XCTAssertFalse(arms.ready(.strike, at: now + arms.between(.knife) / 2),
                       "the knife was ready half way through its own time")
        XCTAssertTrue(arms.ready(.strike, at: now + arms.between(.knife)),
                      "the knife's time passed and it was still held back")
    }

    func testOneKnifeIsOneClockWhicheverWayItIsUsed() throws {
        var arms = try element(0, of: try pair(apart: 1)).arms
        let between = arms.between(.knife)
        XCTAssertGreaterThan(between, .zero, "the knife has no time of its own, and this test proves nothing")
        XCTAssertTrue(arms.ready(.throwKnife, at: now), "a knife nobody had used could not be thrown")
        arms.spend(.strike, at: now)
        // The knife struck with and the knife thrown are one weapon: a bot that has
        // just struck does not throw away what it is about to strike with again.
        XCTAssertFalse(arms.ready(.throwKnife, at: now), "a knife just struck with was thrown in the same instant")
        XCTAssertFalse(arms.ready(.throwKnife, at: now + between / 2), "it was thrown inside the knife's own time")
        XCTAssertTrue(arms.ready(.throwKnife, at: now + between), "the knife's time passed and it could not be thrown")
    }

    func testAGrenadeHasNoTimeToWaitOutAndTheNextIsReadyAtOnce() throws {
        var arms = try element(0, of: try pair(apart: 1)).arms
        XCTAssertEqual(arms.between(.pouch), .zero, "the pouch was given a time between throws")
        XCTAssertGreaterThan(arms.grenades.left, 1, "this bot carries one grenade, and this test proves nothing")
        arms.spend(.throwGrenade, at: now)
        XCTAssertTrue(arms.ready(.throwGrenade, at: now), "the next grenade had to wait")
    }

    func testAUseWithNothingLeftOfItIsNeverReady() throws {
        var arms = try element(0, of: try pair(apart: 1)).arms
        arms.primary.rounds = .zero
        arms.grenades.left = .zero
        arms.throwKnife()
        for use in Arms.uses where use != .shot(.sidearm) {
            XCTAssertFalse(arms.ready(use, at: now + 1_000), "a weapon with nothing left of it was ready")
        }
        XCTAssertTrue(arms.ready(.shot(.sidearm), at: now), "the pistol it still has was held back")
    }

    func testWhatAUseSpendsIsWhatThatWeaponHas() throws {
        var arms = try element(0, of: try pair(apart: 1)).arms
        let rounds = arms.primary.rounds
        let grenades = arms.grenades.left
        arms.spend(.shot(.primary), at: now)
        XCTAssertEqual(arms.primary.rounds, rounds - 1, "a shot spent something other than one round")
        XCTAssertEqual(arms.grenades.left, grenades, "a shot spent a grenade")
        arms.spend(.strike, at: now)
        XCTAssertNotNil(arms.knife, "a strike cost the bot its knife")
        arms.spend(.throwGrenade, at: now)
        XCTAssertEqual(arms.grenades.left, grenades - 1, "a throw spent something other than one grenade")
        arms.spend(.throwKnife, at: now)
        XCTAssertNil(arms.knife, "the knife was thrown and the bot still has it")
    }

    // MARK: not offered while its time stands (FR-BOT-600)

    func testAKnifeStillOnItsOwnTimeIsNotOfferedAsAStrike() throws {
        var bots = try pair(apart: 1)
        let index = try checkedIndex(0, of: bots)
        let reach = try XCTUnwrap(bots[index].arms.knife).numbers.reach
        XCTAssertGreaterThan(reach, 1, "the enemy this test puts within reach is not")
        XCTAssertTrue(has(Deliberation.scores(for: bots[index], in: try situation(bots)), isStrike),
                      "a bot at the reach of an arm was offered no strike to begin with")

        bots[index].arms.spend(.strike, at: now)
        XCTAssertFalse(has(Deliberation.scores(for: bots[index], in: try situation(bots)), isStrike),
                       "a knife still on its own time was offered as a strike")

        var later = try situation(bots)
        later.now = now + (try element(0, of: bots).arms.between(.knife))
        XCTAssertTrue(has(Deliberation.scores(for: bots[index], in: later), isStrike),
                      "the knife's time passed and the strike was still not offered")
    }

    func testAFirearmStillOnItsOwnTimeIsNotOfferedAsAShot() throws {
        var bots = try pair(apart: 3)
        let index = try checkedIndex(0, of: bots)
        XCTAssertTrue(has(Deliberation.scores(for: bots[index], in: try situation(bots)), isPrimaryShot),
                      "a bot with a loaded primary was offered no shot to begin with")

        bots[index].arms.spend(.shot(.primary), at: now)
        XCTAssertFalse(has(Deliberation.scores(for: bots[index], in: try situation(bots)), isPrimaryShot),
                       "a firearm still on its own time was offered as a shot")

        var later = try situation(bots)
        later.now = now + (try element(0, of: bots).arms.between(.firearm(.primary)))
        XCTAssertTrue(has(Deliberation.scores(for: bots[index], in: later), isPrimaryShot),
                      "the weapon's time passed and the shot was still not offered")
    }

    func testTheSlotThatCannotStrikeIsSpentOnSomethingElseAndNotStoodThrough() throws {
        var bots = try pair(apart: 1)
        let index = try checkedIndex(0, of: bots)
        // Not a full magazine: with one a shot is worth exactly what a strike is, and
        // the tie goes to the shot, which is a different thing to measure (ADR-0086).
        bots[index].arms.primary.rounds = 20
        XCTAssertEqual(Deliberation.choose(for: bots[index], in: try situation(bots)), .strike(at: .bot(id: 1)),
                       "a bot at the reach of an arm did not choose the knife")

        bots[index].arms.spend(.strike, at: now)
        let chosen = try XCTUnwrap(Deliberation.choose(for: bots[index], in: try situation(bots)))
        XCTAssertFalse(isStrike(chosen), "a knife on its own time was chosen again")
        XCTAssertTrue(isPrimaryShot(chosen), "the slot the knife could not have went nowhere: \(chosen)")
    }

    // MARK: through a run of slots, nothing stubbed

    func testOverARunOfSlotsTheKnifeIsSwungOnItsOwnTimeAndTheRestIsFired() throws {
        var bots = try pair(apart: 1)
        let index = try checkedIndex(0, of: bots)
        bots[index].arms.primary.rounds = 20
        bots[index].spendEverySpare()
        // The enemy stands through the whole run, so that what ends it is the clock and
        // not a body: a test of cadence is not a test of how long a bot lives.
        let enemy = try checkedIndex(1, of: bots)
        bots[enemy].health = 10_000
        let between = try element(0, of: bots).arms.between(.knife)
        let seconds = between * 1.2
        var struck: [Double] = []
        var at = now
        while at <= now + seconds {
            bots[index].knowledge.enemies[bots[enemy].id] = .init(point: bots[enemy].position, time: at)
            _ = Execution.deliberate(&bots, slots: [0], world: world, now: at)
            if let action = bots[index].action, isStrike(action) { struck.append(at) }
            at += configuration.deliberationPeriod
        }
        XCTAssertEqual(struck.count, 2, "the knife was swung \(struck.count) times in \(seconds) seconds")
        for (earlier, later) in zip(struck, struck.dropFirst()) {
            XCTAssertGreaterThanOrEqual(later - earlier, between - Firing.cadenceSlack,
                                        "two strikes fell inside the knife's own time")
        }
        XCTAssertLessThan(bots[index].arms.primary.rounds, 20, "the slots between the strikes were stood through")
    }
}
