// How what a squad knows of the snake moves its bots: a calm squad does not hunt it,
// nor hide or run from it (FR-BOT-180), unless it is close — within the override distance it is the top threat
// whatever else there is (FR-BOT-120) — and an alarmed squad keeps together
// (FR-BOT-190).
//
// verifies: FR-BOT-120, FR-BOT-180, FR-BOT-190
import XCTest
@testable import CrawlCall

final class SquadStateTests: XCTestCase {
    private var shipped: World!
    private let cell = 0.5
    /// The snake's head, as a bot's knowledge numbers its parts.
    private let head = 0

    override func setUpWithError() throws {
        try super.setUpWithError()
        shipped = try Launch.world().get()
    }

    /// The shipped bot configuration with the override distance replaced.
    private func configuration(override metres: Double) throws -> BotConfiguration {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "bot", withExtension: "json", subdirectory: "config"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        json["overrideDistance"] = metres
        return try Configurations.decode(BotConfiguration.self, named: "bot", schema: BotConfiguration.schema,
                                         from: JSONSerialization.data(withJSONObject: json))
    }

    private func world(_ rows: [String], bot: BotConfiguration? = nil) throws -> World {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        let c = shipped.configurations
        return World(configurations: Configurations(snake: c.snake, tuning: c.tuning, view: c.view, bot: bot ?? c.bot,
                                                    match: c.match, scoring: c.scoring),
                     kit: shipped.kit, map: map, setting: shipped.setting,
                     graph: NavigationGraph.derive(from: map, stepHeight: c.tuning.stepHeight),
                     plan: ScenePlan.make(map: map, kit: shipped.kit, cellSize: cell))
    }

    private var strip: [String] { Array(repeating: String(repeating: ".", count: 40), count: 3) }

    private func at(_ x: Double) -> SIMD3<Double> { SIMD3(x, 0, 0.5) }

    private func bot(_ id: Int, _ squad: Squad = .red, _ kind: Archetype = .sniper, at x: Double,
                     in world: World) throws -> Bot {
        var bot = try XCTUnwrap(Bot(id: id, squad: squad, archetype: kind, at: at(x), floor: 0,
                                    configuration: world.configurations.bot))
        bot.facing = .pi / 2
        return bot
    }

    // MARK: a calm squad does not hunt the snake (FR-BOT-180, FR-BOT-120)

    func testACalmSquadDoesNotFireAtTheSnakeBeyondTheOverrideDistanceAndOtherwiseDoes() throws {
        let world = try world(strip)
        let override = world.configurations.bot.overrideDistance
        let range = try XCTUnwrap(world.configurations.bot.archetypes[Archetype.sniper.rawValue]).detectionRange
        XCTAssertGreaterThan(range, override + 1, "the sniper cannot see past the override distance, so this proves nothing")
        let sniper = try bot(0, at: 1, in: world)
        var situation = Deliberation.Situation(plan: world.plan, graph: world.graph,
                                               configuration: world.configurations.bot, cellSize: cell)
        situation.inView = [at(1 + (override + range) / 2)]
        situation.snake = situation.inView
        for (state, fires) in [(Awareness.calm, false), (.alarm, true), (.confirmed, true)] {
            situation.awareness = state
            let target = Deliberation.target(for: sniper, in: situation, worth: { _ in 1 })
            XCTAssertEqual(target != nil, fires, "a \(state) squad's bot got it wrong")
        }
    }

    func testWithinTheOverrideDistanceTheSnakeIsTheTopThreatEvenForACalmSquad() throws {
        let world = try world(strip)
        let override = world.configurations.bot.overrideDistance
        var sniper = try bot(0, at: 1, in: world)
        // An enemy bot nearer still, worth more, and already being fired at: the snake is
        // the target.
        let enemy = try bot(1, .blue, .assault, at: 2, in: world)
        sniper.action = .fire(at: .bot(id: enemy.id))
        var situation = Deliberation.Situation(plan: world.plan, graph: world.graph,
                                               configuration: world.configurations.bot, cellSize: cell)
        situation.enemiesInView = [(id: enemy.id, point: enemy.position)]
        situation.inView = [at(1 + override * 0.9)]
        situation.snake = situation.inView
        situation.awareness = .calm
        let target = Deliberation.target(for: sniper, in: situation, worth: { metres in 10 - metres })
        guard case .snake = target?.target else { return XCTFail("fired at \(String(describing: target))") }
    }

    func testToACalmSquadASnakeBeyondTheOverrideDistanceIsNothingToFireAtHideOrRunFrom() throws {
        let world = try world(strip)
        let override = world.configurations.bot.overrideDistance
        var soldier = try bot(0, .red, .assault, at: 1, in: world)
        let range = try XCTUnwrap(world.configurations.bot.archetypes[Archetype.assault.rawValue]).detectionRange
        XCTAssertGreaterThan(range, override, "the bot cannot see past the override distance, so this proves nothing")
        soldier.knowledge.snake[head] = .init(point: at(1 + (override + range) / 2), time: 5)
        func reacts(_ action: Action?) -> Bool {
            switch action {
            case .fire(.snake)?, .flee?, .takeCover?: return true
            default: return false
            }
        }
        for (state, reacted) in [(Awareness.calm, false), (.confirmed, true)] {
            var bots = [soldier]
            _ = Execution.deliberate(&bots, slots: [soldier.id], world: world, now: 5, awareness: { _ in state })
            XCTAssertEqual(reacts(bots.first?.action), reacted,
                           "a \(state) bot chose \(String(describing: bots.first?.action))")
        }
    }

    func testInAMatchACalmSquadHoldsItsFireAtASnakeBeyondTheOverrideDistance() throws {
        // A short override distance, so that bots see the snake well before it is close:
        // every shot at it in a calm match is from within the distance.
        let override = 2.0
        let rows = Array(repeating: String(repeating: ".", count: 80), count: 3)
        let world = try world(rows, bot: try configuration(override: override))
        var game = Game(world: world, start: NavigationGraph.Node(floor: 0, x: 40, z: 1))
        var seen = false
        for _ in 0..<(60 * 20) {
            game.advance(seconds: 1.0 / 60)
            guard Squad.allCases.allSatisfy({ game.stealth.of($0) == .calm }) else { break }
            seen = seen || game.bots.contains { $0.knowsSnake }
            let body = [game.snake.head] + game.snake.tail
            for shot in game.shots where body.contains(where: { Perception.metres($0, shot.to) < 1e-9 }) {
                XCTAssertLessThanOrEqual(Perception.metres(shot.from, shot.to),
                                         override + world.configurations.bot.eyeHeight + 1e-9,
                                         "a calm squad fired at the snake from afar")
            }
        }
        XCTAssertTrue(seen, "no bot ever saw the snake, so this proves nothing")
    }

    // MARK: an alarmed squad keeps together (FR-BOT-190)

    func testWhileAlarmedAPositionNearASquadmateIsWorthMore() throws {
        let world = try world(strip)
        let me = try bot(0, at: 1, in: world)
        let mate = try bot(1, at: 15, in: world)
        var situation = Deliberation.Situation(plan: world.plan, graph: world.graph,
                                               configuration: world.configurations.bot, cellSize: cell)
        situation.allies = [me, mate]
        let near = NavigationGraph.Node(floor: 0, x: 28, z: 1)   // a metre from the mate
        let far = NavigationGraph.Node(floor: 0, x: 4, z: 1)
        situation.awareness = .alarm
        let term = world.configurations.bot.utilityTermWeights
        XCTAssertEqual(Deliberation.worth(of: near, for: me, in: situation)
                           - Deliberation.worth(of: far, for: me, in: situation), term.together, accuracy: 1e-9)
        for state in [Awareness.calm, .confirmed] {
            situation.awareness = state
            XCTAssertEqual(Deliberation.worth(of: near, for: me, in: situation),
                           Deliberation.worth(of: far, for: me, in: situation), accuracy: 1e-12,
                           "keeping together while \(state)")
        }
    }

    func testAnAlarmedBotRunsTowardsASquadmateRatherThanAwayFromIt() throws {
        // The danger straight ahead, a squadmate to one side: of two ways to run as far,
        // the alarmed bot takes the squadmate's.
        let world = try world(Array(repeating: String(repeating: ".", count: 40), count: 5))
        var situation = Deliberation.Situation(plan: world.plan, graph: world.graph,
                                               configuration: world.configurations.bot, cellSize: cell)
        var me = try XCTUnwrap(Bot(id: 0, squad: .red, archetype: .assault, at: SIMD3(10, 0, 1.5), floor: 0,
                                   configuration: world.configurations.bot))
        me.facing = .pi
        for (mateX, east) in [(18.0, true), (2.0, false)] {
            let mate = try XCTUnwrap(Bot(id: 1, squad: .red, archetype: .assault, at: SIMD3(mateX, 0, 2), floor: 0,
                                         configuration: world.configurations.bot))
            situation.allies = [me, mate]
            situation.awareness = .alarm
            let away = try XCTUnwrap(Deliberation.away(from: SIMD3(10, 0, 0), for: me, in: situation))
            XCTAssertEqual(Double(away.x) * cell > 10, east, "ran away from the squadmate at \(mateX)")
        }
    }
}
