// Where a bot would rather be when the snake is about: higher than its head
// (FR-BOT-110) and far along its path (FR-BOT-115). Each is varied on its own — the
// other held equal — and watched to move the worth of a position, then the cover and
// the flight a bot chooses.
//
// verifies: FR-BOT-110, FR-BOT-115
import XCTest
@testable import CrawlCall

final class PositionTests: XCTestCase {
    private var kit: Kit!
    private var configuration: BotConfiguration!
    private let cell = 0.5

    override func setUpWithError() throws {
        try super.setUpWithError()
        kit = try Kit.load(named: "blockout", from: .main)
        configuration = try Launch.world().get().configurations.bot
    }

    private func arena(_ text: String) throws -> Deliberation.Situation {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\n" + text, kit: kit)
        return Deliberation.Situation(plan: ScenePlan.make(map: map, kit: kit, cellSize: cell),
                                      graph: NavigationGraph.derive(from: map, stepHeight: ShippedTuning.stepHeight),
                                      configuration: configuration,
                                      cellSize: cell)
    }

    private func at(_ x: Int, _ z: Int, floor: Int = 0) -> SIMD3<Double> {
        SIMD3(Double(x) * cell, Double(floor) * kit.floorHeight, Double(z) * cell)
    }

    private func bot(at point: SIMD3<Double>, floor: Int = 0) throws -> Bot {
        try XCTUnwrap(Bot(id: 0, squad: .red, archetype: .assault, at: point, floor: floor, configuration: configuration))
    }

    private func node(_ x: Int, _ z: Int, floor: Int = 0) -> NavigationGraph.Node {
        NavigationGraph.Node(floor: floor, x: x, z: z)
    }

    /// A flight of eight steps rising east along rows 0–2 to a landing one floor up.
    private let stepped = "floor 0\n....>>>>>>>>.\n....>>>>>>>>.\n....>>>>>>>>.\nfloor 1\n            .\n            .\n            .\n"

    func testAPositionIsWorthOneWhereTheBotKnowsNoSnake() throws {
        let situation = try arena(stepped)
        let soldier = try bot(at: at(0, 1))
        XCTAssertEqual(Deliberation.worth(of: node(12, 1, floor: 1), for: soldier, in: situation), 1, accuracy: 1e-12)
        XCTAssertEqual(Deliberation.worth(of: node(0, 1), for: soldier, in: situation), 1, accuracy: 1e-12)
    }

    func testAPositionAboveTheSnakesHeadIsWorthMoreThanOneLevelWithIt() throws {
        // The path held equal: neither cell in the snake's paths, both as far as a path
        // counts.
        var situation = try arena(stepped)
        situation.snakeHead = at(0, 1)
        let soldier = try bot(at: at(2, 1))
        let level = Deliberation.worth(of: node(1, 1), for: soldier, in: situation)
        let above = Deliberation.worth(of: node(12, 1, floor: 1), for: soldier, in: situation)
        let term = configuration.utilityTermWeights
        XCTAssertEqual(above - level, term.height, accuracy: 1e-9, "a floor up is not worth the height term")
        // Up to a floor, and no more: half a floor is half of it.
        let halfway = Deliberation.worth(of: node(7, 1), for: soldier, in: situation)
        XCTAssertGreaterThan(halfway, level)
        XCTAssertLessThan(halfway, above)
        // Below the head is not worth less than level with it: height only raises.
        situation.snakeHead = at(12, 1, floor: 1)
        XCTAssertEqual(Deliberation.worth(of: node(1, 1), for: soldier, in: situation),
                       Deliberation.worth(of: node(2, 1), for: soldier, in: situation), accuracy: 1e-12)
    }

    func testAPositionFartherAlongTheSnakesPathIsWorthMore() throws {
        var situation = try arena("floor 0\n....................\n....................\n")
        situation.snakeHead = at(0, 0)
        let range = try XCTUnwrap(configuration.archetypes[Archetype.assault.rawValue]).detectionRange
        situation.fromHead = Squads.distances(in: situation.graph, from: node(0, 0))
        let soldier = try bot(at: at(5, 1))
        let near = Deliberation.worth(of: node(2, 0), for: soldier, in: situation)
        let far = Deliberation.worth(of: node(8, 0), for: soldier, in: situation)
        XCTAssertGreaterThan(far, near)
        // The whole term at the bot's detection range along the path, and no more past it.
        let term = configuration.utilityTermWeights
        let steps = Int((range / cell).rounded(.up))
        situation.fromHead = [node(2, 0): steps, node(8, 0): steps * 3]
        XCTAssertEqual(Deliberation.worth(of: node(2, 0), for: soldier, in: situation), 1 + term.snakePath, accuracy: 1e-9)
        XCTAssertEqual(Deliberation.worth(of: node(8, 0), for: soldier, in: situation), 1 + term.snakePath, accuracy: 1e-9)
        // A cell the snake cannot reach at all is as far as a path counts.
        XCTAssertEqual(Deliberation.worth(of: node(5, 1), for: soldier, in: situation), 1 + term.snakePath, accuracy: 1e-9)
    }

    /// Two pillars mirrored about the snake, the bot between them: whatever hides behind
    /// one has its mirror behind the other, as near the bot.
    private let pillars = "floor 0\n...........\n...#...#...\n...........\n...........\n...........\n"

    func testOfTwoCoversAsNearTheOneTheSnakeTakesLongerToReachIsTaken() throws {
        var situation = try arena(pillars)
        situation.snake = [at(5, 0)]
        situation.snakeHead = at(5, 0)
        let soldier = try bot(at: at(5, 3))
        for (longer, side) in [(true, "east"), (false, "west")] {
            situation.fromHead = Dictionary(uniqueKeysWithValues: situation.graph.nodes.map { cell in
                (cell, (cell.x > 5) == longer ? 40 : 2)
            })
            let cover = try XCTUnwrap(Deliberation.cover(for: soldier, from: situation.snake, in: situation),
                                      "no cover behind either pillar")
            XCTAssertEqual(cover.node.x > 5, longer, "the cover taken is not on the \(side), the snake's long way round")
        }
    }

    func testOfTwoWaysToRunAsFarTheOneTheSnakeTakesLongerToReachIsTaken() throws {
        var situation = try arena(pillars)
        situation.snakeHead = at(5, 0)
        let soldier = try bot(at: at(5, 3))
        for longer in [true, false] {
            situation.fromHead = Dictionary(uniqueKeysWithValues: situation.graph.nodes.map { cell in
                (cell, (cell.x > 5) == longer ? 40 : 2)
            })
            let away = try XCTUnwrap(Deliberation.away(from: at(5, 0), for: soldier, in: situation))
            XCTAssertEqual(away.x > 5, longer, "ran to the side the snake reaches at once")
        }
    }

    func testABotAtTheTopOfAFlightRunsUpOntoTheFloorAbove() throws {
        // The walk that finds where to run crosses floors: a bot on the flight's top
        // step, the snake at its foot, gets off onto the landing.
        var situation = try arena(stepped)
        situation.snakeHead = at(0, 1)
        situation.fromHead = Squads.distances(in: situation.graph, from: node(0, 1))
        let top = situation.graph.centre(of: node(11, 1), cellSize: cell, floorHeight: kit.floorHeight)
        let soldier = try bot(at: top)
        let away = try XCTUnwrap(Deliberation.away(from: at(0, 1), for: soldier, in: situation))
        XCTAssertEqual(away.floor, 1, "stayed on the flight rather than going up")
    }
}
