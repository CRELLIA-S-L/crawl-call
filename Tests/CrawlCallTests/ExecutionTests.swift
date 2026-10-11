// The two clocks and what they drive: deliberation on a fixed step (FR-BOT-150)
// handed out by need (FR-BOT-160), one route computed a frame (FR-BOT-165), every
// bot moving every frame (INV-BOT-010), a shot costing a round and dealing its
// damage (FR-BOT-060), and the snake paying for it out of its tail (FR-SNAKE-070).
//
// file verifies: FR-BOT-060, FR-BOT-150, FR-BOT-160, FR-BOT-165, FR-SNAKE-070, INV-BOT-010
import XCTest
@testable import CrawlCall

final class SlotsTests: XCTestCase {
    private var configuration: BotConfiguration!

    override func setUpWithError() throws {
        try super.setUpWithError()
        configuration = try Launch.world().get().configurations.bot
    }

    func testTheSameSecondBuysTheSameThinkingAtAnyFrameRate() {
        // What the requirement claims is the equality, and that is asserted first:
        // the same simulated second is the same number of steps at 30, 60 and 120
        // frames a second.
        let period = 0.2
        func steps(frames: Int, seconds: Int) -> Int {
            var slots = Slots()
            var total = 0
            for _ in 0..<(frames * seconds) { total += slots.steps(after: 1.0 / Double(frames), period: period) }
            return total
        }
        XCTAssertEqual(steps(frames: 60, seconds: 1), steps(frames: 30, seconds: 1))
        XCTAssertEqual(steps(frames: 60, seconds: 1), steps(frames: 120, seconds: 1))

        // And the count is the one the period asks for, give or take the step that
        // falls exactly on the boundary: sixty frames of a sixtieth sum to a hair
        // under a second, so the fifth step arrives a hair late rather than never.
        // Over ten seconds that hair must not have grown into lost thinking.
        for frames in [30, 60, 120] {
            XCTAssertTrue((49...50).contains(steps(frames: frames, seconds: 10)),
                          "\(frames) fps deliberated \(steps(frames: frames, seconds: 10)) times in ten seconds")
        }
    }

    func testTimeTooShortForAStepIsCarriedRatherThanLost() {
        var slots = Slots()
        XCTAssertEqual(slots.steps(after: 0.15, period: 0.2), 0)
        XCTAssertEqual(slots.steps(after: 0.15, period: 0.2), 1, "the carried time was dropped")
    }

    private func bot(_ id: Int, at x: Double, knows: Bool = false) throws -> Bot {
        var made = try XCTUnwrap(Bot(id: id, squad: .red, archetype: .assault,
                                     at: SIMD3(x, 0, 0), floor: 0, configuration: configuration))
        if knows { made.knowledge.snake = [0: .init(point: .zero, time: 0)] }
        return made
    }

    func testASlotGoesToWhoeverHasWaitedLongest() throws {
        var slots = Slots()
        let bots = [try bot(0, at: 0), try bot(1, at: 1), try bot(2, at: 2), try bot(3, at: 3)]
        let first = slots.next(among: bots, snake: [], configuration: configuration)
        XCTAssertEqual(first.count, configuration.perFrameSlotMaximum)
        let second = slots.next(among: bots, snake: [], configuration: configuration)
        XCTAssertTrue(Set(first).isDisjoint(with: Set(second)),
                      "the same bots deliberated twice while others waited")
    }

    func testABotThatHasSeenTheSnakeOutranksOneThatHasNot() throws {
        // Three idle bots and one that has seen the snake, two slots a step. Three
        // times the importance means the watcher's claim is back above everyone
        // else's the moment it has waited a single step, so it is in every round;
        // a queue that counted waiting alone would give it every other one.
        var bots = [try bot(0, at: 0), try bot(1, at: 1), try bot(2, at: 2), try bot(3, at: 3, knows: true)]
        var slots = Slots()
        let first = slots.next(among: bots, snake: [], configuration: configuration)
        let second = slots.next(among: bots, snake: [], configuration: configuration)
        let third = slots.next(among: bots, snake: [], configuration: configuration)
        XCTAssertTrue(first.contains(3) && second.contains(3) && third.contains(3),
                      "the watcher took its turn like an idle bot: \(first), \(second), \(third)")

        // With nobody watching, the same queue goes round instead — which is what
        // makes the assertion above about importance and not about the queue.
        bots[try checkedIndex(3, of: bots)].knowledge = Knowledge()
        var calm = Slots()
        let calmFirst = calm.next(among: bots, snake: [], configuration: configuration)
        let calmSecond = calm.next(among: bots, snake: [], configuration: configuration)
        XCTAssertTrue(Set(calmFirst).isDisjoint(with: Set(calmSecond)),
                      "an idle bot thought twice while another waited")
    }
}

final class ExecutionTests: XCTestCase {
    private func world() throws -> World { try Launch.world().get() }

    private func bot(_ id: Int = 0, at node: NavigationGraph.Node, in world: World,
                     kind: Archetype = .assault) throws -> Bot {
        let cell = world.configurations.tuning.navigationGraphCellSize
        return try XCTUnwrap(Bot(id: id, squad: .red, archetype: kind,
                                 at: SIMD3(Double(node.x) * cell, Double(node.floor) * world.kit.floorHeight,
                                           Double(node.z) * cell),
                                 floor: node.floor, configuration: world.configurations.bot))
    }

    /// Two walkable cells of the shipped map, some way apart on the ground floor.
    private func cells(in world: World) -> [NavigationGraph.Node] {
        world.graph.nodes.filter { $0.floor == 0 }.sorted { ($0.z, $0.x) < ($1.z, $1.x) }
    }

    func testABotSentWhereItAlreadyStandsHasSpentItsAction() throws {
        // Going somewhere is over once the bot is there, and there is where it stands:
        // it is left with nothing to do, as a bot with no route is, and chooses again.
        let world = try world()
        let here = try element(0, of: cells(in: world))
        var standing = try bot(at: here, in: world)
        standing.action = .takeCover(at: here)
        var bots = [standing]
        Execution.walk(&bots, seconds: 1.0 / 60, world: world)
        XCTAssertNil(try element(0, of: bots).action, "the bot is still going where it stands")
        XCTAssertEqual(try element(0, of: bots).speed, 0)
    }

    func testEveryBotWalksEveryFrame() throws {
        // INV-BOT-010: movement is not what the deliberation budget rations.
        let world = try world()
        let ground = cells(in: world)
        let goal = try XCTUnwrap(ground.last)
        var bots = [try bot(0, at: element(0, of: ground), in: world),
                    try bot(1, at: element(1, of: ground), in: world)]
        for index in bots.indices {
            bots[index].action = .flee(to: goal)
            bots[index].path = Route.between(
                NavigationGraph.Node(floor: 0,
                                     x: Int((bots[index].position.x / world.configurations.tuning.navigationGraphCellSize).rounded()),
                                     z: Int((bots[index].position.z / world.configurations.tuning.navigationGraphCellSize).rounded())),
                goal, in: world.graph)
        }
        let before = bots.map(\.position)
        Execution.walk(&bots, seconds: 1.0 / 60, world: world)
        for (index, was) in before.enumerated() {
            XCTAssertNotEqual(bots[index].position, was, "bot \(index) stood still for a frame")
        }
    }

    func testOnlyOneRouteIsComputedInAFrame() throws {
        // FR-BOT-165: the second bot keeps waiting rather than paying for a second
        // search in the same frame.
        let world = try world()
        let ground = cells(in: world)
        let goal = try XCTUnwrap(ground.last)
        var bots = [try bot(0, at: element(0, of: ground), in: world),
                    try bot(1, at: element(1, of: ground), in: world)]
        bots[try checkedIndex(0, of: bots)].action = .flee(to: goal)
        bots[try checkedIndex(1, of: bots)].action = .flee(to: goal)
        Execution.walk(&bots, seconds: 1.0 / 60, world: world)
        XCTAssertFalse(try element(0, of: bots).path.isEmpty)
        XCTAssertTrue(try element(1, of: bots).path.isEmpty, "two routes were computed in one frame")
        // Next frame it is the second bot's turn.
        Execution.walk(&bots, seconds: 1.0 / 60, world: world)
        XCTAssertFalse(try element(1, of: bots).path.isEmpty)
    }

    func testABotThatDecidesToMoveActuallyGetsSomewhere() throws {
        // The chain end to end: a slot chooses, a frame routes, frames walk. A bot
        // whose path were cleared faster than it could be walked would stand and
        // twitch, and the chain would still look right one call at a time.
        let world = try world()
        let ground = cells(in: world)
        var bots = [try bot(0, at: element(0, of: ground), in: world)]
        bots[try checkedIndex(0, of: bots)].knowledge.snake = [0: .init(point: .zero, time: 0)]
        bots[try checkedIndex(0, of: bots)].health = 5  // frightened enough to run
        bots[try checkedIndex(0, of: bots)].weights = BotConfiguration.Weights(panic: 0.9, discipline: 0.5,
                                                   aggression: 0.1, selfSacrifice: 0.5)
        let where0 = try element(0, of: bots).position
        let snake = [try element(0, of: bots).position + SIMD3(1, 0, 0)]

        var slots = Slots()
        let modules = Perception.modules(of: world.map)
        for frame in 0..<120 {
            // It looks round as a match has it look, so that it knows somewhere to run
            // to (FR-BOT-220, FR-BOT-230).
            if frame % 12 == 0 {
                Perception.lookAtMap(&bots[try checkedIndex(0, of: bots)], world: world, modules: modules,
                                     now: Double(frame) / 60)
            }
            let steps = slots.steps(after: 1.0 / 60, period: world.configurations.bot.deliberationPeriod)
            for _ in 0..<steps {
                let holders = slots.next(among: bots, snake: snake, configuration: world.configurations.bot)
                _ = Execution.deliberate(&bots, slots: holders, snake: snake, world: world)
            }
            Execution.walk(&bots, seconds: 1.0 / 60, world: world,
                           routeOrder: slots.order(among: bots, snake: snake,
                                                   configuration: world.configurations.bot))
        }
        let moved = Perception.metres(where0, try element(0, of: bots).position)
        XCTAssertGreaterThan(moved, 1.0, "the bot decided to run and covered \(moved) m in two seconds")
    }

    func testAFiringBotSpendsARoundAndDealsItsDamage() throws {
        let world = try world()
        let ground = cells(in: world)
        let here = try element(0, of: ground)
        let cell = world.configurations.tuning.navigationGraphCellSize
        var bots = [try bot(0, at: here, in: world)]
        bots[try checkedIndex(0, of: bots)].knowledge.snake = [0: .init(point: .zero, time: 0)]
        let target = SIMD3(Double(here.x) * cell + cell, 0, Double(here.z) * cell)
        let before = try element(0, of: bots).ammunition

        let volley = Execution.deliberate(&bots, slots: [0], snake: [target], world: world)
        let entry = try XCTUnwrap(world.configurations.bot.archetypes[Archetype.assault.rawValue])
        XCTAssertEqual(try element(0, of: bots).action, .fire(at: .snake(at: target)))
        let struck = Flight.land(volley.rounds, bots: &bots, snake: [target], world: world)
        XCTAssertEqual(struck.damage, entry.weaponDamage)
        XCTAssertEqual(try element(0, of: bots).ammunition, before - 1)
    }

    func testABotThatHasNotSeenTheSnakeDoesNotFireAtIt() throws {
        let world = try world()
        let here = try element(0, of: cells(in: world))
        let cell = world.configurations.tuning.navigationGraphCellSize
        var bots = [try bot(0, at: here, in: world)]
        let target = SIMD3(Double(here.x) * cell + cell, 0, Double(here.z) * cell)
        XCTAssertTrue(Execution.deliberate(&bots, slots: [0], snake: [target], world: world).rounds.isEmpty)
        // With nothing it knows of to fire at, whatever it does is not firing; left idle, it
        // goes to look round (FR-BOT-370).
        if case .fire = try element(0, of: bots).action { XCTFail("fired at a snake it has not seen") }
    }

    func testAnEmptyMagazineIsReloadedRatherThanFired() throws {
        let world = try world()
        let here = try element(0, of: cells(in: world))
        let cell = world.configurations.tuning.navigationGraphCellSize
        var bots = [try bot(0, at: here, in: world)]
        bots[try checkedIndex(0, of: bots)].knowledge.snake = [0: .init(point: .zero, time: 0)]
        bots[try checkedIndex(0, of: bots)].ammunition = 0
        let target = SIMD3(Double(here.x) * cell + cell, 0, Double(here.z) * cell)
        XCTAssertTrue(Execution.deliberate(&bots, slots: [0], snake: [target], world: world).rounds.isEmpty)
        XCTAssertEqual(try element(0, of: bots).action, .reload)
        XCTAssertEqual(try element(0, of: bots).ammunition,
                       try XCTUnwrap(world.configurations.bot.archetypes[Archetype.assault.rawValue]).magazine)
    }
}

final class SnakeDamageTests: XCTestCase {
    private func snake(segments: Int = 6) -> Snake {
        Snake(head: .zero, floor: 0, segments: segments, segmentSpacing: 0.6)
    }

    func testDamageShortOfASegmentTakesNothingYet() {
        var body = snake()
        XCTAssertEqual(body.take(damage: 8, perSegment: 10), 0)
        XCTAssertEqual(body.segments, 6)
    }

    func testWhatIsLeftOverIsCountedAgainstTheNextHit() {
        // The shipped numbers: 8 a shot against 10 a segment. Two shots are worth a
        // segment; a rounding that forgot the first would make every shot harmless.
        var body = snake()
        XCTAssertEqual(body.take(damage: 8, perSegment: 10), 0)
        XCTAssertEqual(body.take(damage: 8, perSegment: 10), 1)
        XCTAssertEqual(body.segments, 5)
        // And the six units left over carry on: four more make the next ten.
        XCTAssertEqual(body.take(damage: 4, perSegment: 10), 1)
        XCTAssertEqual(body.segments, 4)
    }

    func testOneHitCanTakeSeveralSegments() {
        var body = snake()
        XCTAssertEqual(body.take(damage: 35, perSegment: 10), 3)
        XCTAssertEqual(body.segments, 3)
    }

    func testTheTailCannotGoNegative() {
        var body = snake(segments: 1)
        XCTAssertEqual(body.take(damage: 100, perSegment: 10), 1)
        XCTAssertEqual(body.segments, 0)
        XCTAssertEqual(body.take(damage: 100, perSegment: 10), 0)
        XCTAssertEqual(body.segments, 0)
    }
}
