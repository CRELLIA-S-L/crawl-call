// A bot walks straight where it can (FR-BOT-270): the test of a straight, level way
// for its body, and routes walked on the shipped map — straight across open floor,
// cell by cell round what is in the way, never over a cell nobody can stand on.
//
// verifies: FR-BOT-270
import simd
import XCTest
@testable import CrawlCall

final class BotPathTests: XCTestCase {
    private var world: World!
    private var cell: Double { world.configurations.tuning.navigationGraphCellSize }
    private var radius: Double { world.configurations.tuning.bodyRadius }

    override func setUpWithError() throws {
        try super.setUpWithError()
        world = try Launch.world().get()
    }

    private func graph(_ text: String) throws -> NavigationGraph {
        let map = try MapParser.parse(text, kit: world.kit)
        return NavigationGraph.derive(from: map, stepHeight: world.configurations.tuning.stepHeight)
    }

    private func point(_ x: Int, _ z: Int, y: Double = 0) -> SIMD3<Double> {
        SIMD3(Double(x) * cell, y, Double(z) * cell)
    }

    private func open(_ graph: NavigationGraph, _ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Bool {
        Execution.isOpen(from: a, to: b, floor: 0, over: graph, cellSize: cell,
                         floorHeight: world.kit.floorHeight, radius: radius)
    }

    func testAStraightWayIsOpenOnlyWhereTheBodyPassesOverLevelGround() throws {
        let floor = try graph("kit blockout\nsetting greenholm\nfloor 0\n" + Array(repeating: "..........", count: 8).joined(separator: "\n") + "\n")
        XCTAssertTrue(open(floor, point(1, 1), point(8, 6)), "open floor is not open")

        // A wall across the way closes it.
        let walled = try graph("kit blockout\nsetting greenholm\nfloor 0\n..........\n..........\n..........\n#####.....\n..........\n..........\n")
        XCTAssertFalse(open(walled, point(1, 1), point(1, 5)))
        // Beside a wall nearer than the body's radius, the body does not fit.
        XCTAssertFalse(open(walled, point(0, 2), point(4, 2)), "the body passed a wall a quarter of a metre off its line")
        XCTAssertTrue(open(walled, point(0, 1), point(4, 1)))

        // Up a step, the way is not level.
        let stepped = try graph("kit blockout\nsetting greenholm\nfloor 0\n....>>>>>>>>.\n....>>>>>>>>.\n....>>>>>>>>.\nfloor 1\n            .\n            .\n            .\n")
        XCTAssertFalse(open(stepped, point(0, 1), point(6, 1, y: world.kit.floorHeight / 8 * 3)))
    }

    /// A bot walked frame by frame from one cell of the shipped map's ground floor to
    /// another, and every place it stood.
    private func walk(from start: NavigationGraph.Node, to goal: NavigationGraph.Node) throws -> [SIMD3<Double>] {
        XCTAssertTrue(world.graph.isWalkable(start) && world.graph.isWalkable(goal), "the map moved, so the test proves nothing")
        var bot = try XCTUnwrap(Bot(id: 0, squad: .red, archetype: .assault, at: point(start.x, start.z),
                                    floor: 0, configuration: world.configurations.bot))
        bot.action = .flee(to: goal)
        bot.path = Route.between(start, goal, in: world.graph)
        XCTAssertFalse(bot.path.isEmpty)
        var bots = [bot]
        var places: [SIMD3<Double>] = []
        for _ in 0..<600 {
            Execution.walk(&bots, seconds: 1.0 / 60, world: world)
            let now = try element(0, of: bots)
            places.append(now.position)
            if now.path.isEmpty { break }
        }
        return places
    }

    func testABotCrossesOpenFloorInAStraightLine() throws {
        // Across the room's north side, six cells along and one across: the line from
        // start to goal, not an L.
        let start = NavigationGraph.Node(floor: 0, x: 6, z: 6), goal = NavigationGraph.Node(floor: 0, x: 20, z: 7)
        let places = try walk(from: start, to: goal)
        let a = SIMD2(Double(start.x) * cell, Double(start.z) * cell), b = SIMD2(Double(goal.x) * cell, Double(goal.z) * cell)
        let along = simd_normalize(b - a)
        let farthest = places.map { p -> Double in
            let off = SIMD2(p.x, p.z) - a
            return abs(off.x * along.y - off.y * along.x)
        }.max() ?? .infinity
        XCTAssertLessThan(farthest, 0.02, "the bot strayed \(farthest) m off the straight line")
        let end = try XCTUnwrap(places.last)
        XCTAssertEqual(end.x, b.x, accuracy: 1e-6)
        XCTAssertEqual(end.z, b.y, accuracy: 1e-6)
    }

    func testABotGoesRoundWhatIsInTheWayAndNeverOverACellNobodyStandsOn() throws {
        // From the west of the partition in column 14 to its east, through its doorway.
        let start = NavigationGraph.Node(floor: 0, x: 10, z: 6), goal = NavigationGraph.Node(floor: 0, x: 18, z: 14)
        let places = try walk(from: start, to: goal)
        for p in places {
            let under = NavigationGraph.Node(floor: 0, x: Int((p.x / cell).rounded()), z: Int((p.z / cell).rounded()))
            XCTAssertTrue(world.graph.isWalkable(under), "the bot stood over \(under), which nobody can stand on")
        }
        let end = try XCTUnwrap(places.last)
        XCTAssertEqual(end.x, Double(goal.x) * cell, accuracy: 1e-6)
        XCTAssertEqual(end.z, Double(goal.z) * cell, accuracy: 1e-6)
    }
}
