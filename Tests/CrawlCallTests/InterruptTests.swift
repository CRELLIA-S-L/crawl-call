// Events that give a bot a slot at once rather than in its turn (FR-BOT-170): each one
// found when it happens and not again while it lasts, the bot it happened to put ahead
// of the queue, and — in a match — deciding in the very next frame.
//
// verifies: FR-BOT-170
import XCTest
@testable import CrawlCall

final class InterruptTests: XCTestCase {
    private var shipped: World!
    private var world: World!
    private let now = 10.0
    /// The snake's head, as a bot's knowledge numbers its parts; the watching bot's id;
    /// the eaten bot's id.
    private let head = 0
    private let watching = 0
    private let eaten = 1

    override func setUpWithError() throws {
        try super.setUpWithError()
        shipped = try Launch.world().get()
        // An open strip, forty metres long: nothing stands between anybody.
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
    private func bot(_ id: Int, _ squad: Squad = .red, at x: Double) throws -> Bot {
        var bot = try XCTUnwrap(Bot(id: id, squad: squad, archetype: .assault, at: SIMD3(x, 0, 0.5), floor: 0,
                                    configuration: configuration))
        bot.facing = .pi / 2
        return bot
    }

    private func find(_ interrupts: inout Interrupts, before: [Bot], after: [Bot], meal: Int? = nil) -> [Int: Interrupt] {
        interrupts.find(before: Interrupts.glance(before), after: after, meal: meal, plan: world.plan, configuration: configuration, now: now)
    }

    func testABotThatIsHitIsInterrupted() throws {
        let whole = try bot(0, at: 5)
        var hurt = whole
        hurt.health -= 1
        var interrupts = Interrupts()
        XCTAssertEqual(find(&interrupts, before: [whole], after: [hurt]), [0: .hit])
        XCTAssertEqual(find(&interrupts, before: [hurt], after: [hurt]), [:], "hit again without being hit")
    }

    func testABotWhoseMagazineRunsDryIsInterruptedOnce() throws {
        var last = try bot(0, at: 5)
        last.ammunition = 1
        var dry = last
        dry.ammunition = 0
        var interrupts = Interrupts()
        XCTAssertEqual(find(&interrupts, before: [last], after: [dry]), [0: .magazineEmpty])
        XCTAssertEqual(find(&interrupts, before: [dry], after: [dry]), [:])
    }

    func testTheSnakeComingIntoTheInterruptDistanceInterruptsOnceUntilItLeavesAndComesBack() throws {
        var watcher = try bot(0, at: 5)
        let within = configuration.interruptDistance * 0.5
        var interrupts = Interrupts()
        // Seen, but farther than the interrupt distance: nothing.
        watcher.knowledge.snake[head] = .init(point: SIMD3(5 + configuration.interruptDistance * 1.5, 0, 0.5), time: now)
        XCTAssertEqual(find(&interrupts, before: [watcher], after: [watcher]), [:])
        // Coming within it: once.
        watcher.knowledge.snake[head] = .init(point: SIMD3(5 + within, 0, 0.5), time: now)
        XCTAssertEqual(find(&interrupts, before: [watcher], after: [watcher]), [0: .snakeClose])
        XCTAssertEqual(find(&interrupts, before: [watcher], after: [watcher]), [:], "interrupted every frame the snake stays")
        // Remembered where it was but not seen now: it has gone from view.
        watcher.knowledge.snake[head] = .init(point: SIMD3(5 + within, 0, 0.5), time: now - 1)
        XCTAssertEqual(find(&interrupts, before: [watcher], after: [watcher]), [:])
        // Back in view within the distance: once more.
        watcher.knowledge.snake[head] = .init(point: SIMD3(5 + within, 0, 0.5), time: now)
        XCTAssertEqual(find(&interrupts, before: [watcher], after: [watcher]), [0: .snakeClose])
    }

    func testAnAllyDyingInViewInterruptsAndOneBehindOrAnEnemyDoesNot() throws {
        let watcher = try bot(0, at: 5)
        let ally = try bot(1, at: 9)
        var fallen = ally
        fallen.health = 0
        var interrupts = Interrupts()
        XCTAssertEqual(find(&interrupts, before: [watcher, ally], after: [watcher, fallen])[watching], .allyDied)
        // Eaten, and gone from the match, is dying too.
        XCTAssertEqual(find(&interrupts, before: [watcher, ally], after: [watcher])[watching], .allyDied)
        // Behind it, out of its field of view: not seen.
        let behind = try bot(2, at: 1)
        var behindFallen = behind
        behindFallen.health = 0
        XCTAssertNil(find(&interrupts, before: [watcher, behind], after: [watcher, behindFallen])[watching])
        // An enemy's death is not an ally's.
        let enemy = try bot(3, .blue, at: 9)
        var enemyFallen = enemy
        enemyFallen.health = 0
        XCTAssertNil(find(&interrupts, before: [watcher, enemy], after: [watcher, enemyFallen])[watching])
    }

    func testAMealInViewInterruptsEachWitnessOnceAndANewMealAgain() throws {
        let watcher = try bot(0, at: 5)
        let prey = try bot(1, .blue, at: 9)
        let other = try bot(2, .blue, at: 8)
        var interrupts = Interrupts()
        XCTAssertEqual(find(&interrupts, before: [watcher, prey, other], after: [watcher, prey, other], meal: 1)[watching], .sawEating)
        XCTAssertNil(find(&interrupts, before: [watcher, prey, other], after: [watcher, prey, other], meal: 1)[watching],
                     "the same meal seen twice")
        XCTAssertNil(find(&interrupts, before: [watcher, other], after: [watcher, other])[watching])
        let second = find(&interrupts, before: [watcher, other], after: [watcher, other], meal: 2)
        XCTAssertEqual(second[watching], .sawEating, "\(second)")
        // A meal beyond what the bot can see is not witnessed.
        let range = try XCTUnwrap(configuration.archetypes[Archetype.assault.rawValue]).detectionRange
        let far = try bot(3, .blue, at: 5 + range + 1)
        var unseen = Interrupts()
        XCTAssertNil(find(&unseen, before: [watcher, far], after: [watcher, far], meal: 3)[watching])
        // The prey does not witness its own meal.
        var fresh = Interrupts()
        XCTAssertNil(find(&fresh, before: [prey], after: [prey], meal: 1)[eaten])
    }

    func testAnInterruptedBotGoesAheadOfTheQueue() throws {
        let bots = try (0..<6).map { try bot($0, at: Double($0)) }
        var slots = Slots()
        // Bot 5 would come last by the queue's order; interrupted, it comes first.
        let plain = slots.order(among: bots, snake: [], configuration: configuration)
        XCTAssertEqual(plain.last, 5)
        XCTAssertGreaterThan(configuration.perFrameSlotMaximum, 0)
        XCTAssertEqual(slots.next(among: bots, snake: [], configuration: configuration, ahead: [5]).first, 5)
    }

    func testASlotAheadOfTheQueueDecidesButDoesNotFireFasterThanOnceAPeriod() throws {
        let period = configuration.deliberationPeriod
        var shooter = try bot(0, at: 5)
        let enemy = try bot(1, .blue, at: 8)
        shooter.knowledge.enemies[enemy.id] = .init(point: enemy.position, time: now)
        shooter.lastShot = now - period * 0.5
        var bots = [shooter, enemy]
        let held = Execution.deliberate(&bots, slots: [shooter.id], world: world, now: now, interrupted: [shooter.id])
        XCTAssertEqual(bots.first?.action, .fire(at: .bot(id: enemy.id)), "the interrupted bot did not decide")
        XCTAssertTrue(held.shots.isEmpty, "fired again half a period after its last shot")
        XCTAssertEqual(bots.first?.ammunition, shooter.ammunition)
        // In its own turn, or more than a period on, it fires.
        bots = [shooter, enemy]
        XCTAssertEqual(Execution.deliberate(&bots, slots: [shooter.id], world: world, now: now).shots.count, 1)
        shooter.lastShot = now - period * 1.5
        bots = [shooter, enemy]
        XCTAssertEqual(Execution.deliberate(&bots, slots: [shooter.id], world: world, now: now,
                                            interrupted: [shooter.id]).shots.count, 1)
        XCTAssertEqual(bots.first?.lastShot ?? .nan, now, accuracy: 1e-12)
    }

    func testInAMatchTheBotThatSawTheSnakeComeCloseDecidesInTheNextFrame() throws {
        var game = Game(world: world, start: NavigationGraph.Node(floor: 0, x: 30, z: 1))
        game.apply(.move(direction: SIMD2(-1, 0)))
        let frame = 1.0 / 60
        var waiting: Int?
        for _ in 0..<1200 where waiting == nil {
            game.advance(seconds: frame)
            waiting = game.interrupted.first { $0.value == .snakeClose }?.key
        }
        let id = try XCTUnwrap(waiting, "no bot saw the snake come within the interrupt distance")
        let report = game.advance(seconds: frame)
        XCTAssertNil(game.interrupted[id], "the interrupted bot is still waiting after a frame")
        XCTAssertGreaterThan(report.deliberations, 0)
    }
}
