// A flight of stairs: drawn as arrows (IF-MAP-010), raised in equal rises to the floor
// above (FR-MAP-150), refused when too steep (FR-MAP-160), joined into the graph by
// the step height (FR-MAP-020), built as blocks, and climbed by the snake and the bots.
//
// verifies: IF-MAP-010, FR-MAP-020, FR-MAP-150, FR-MAP-160, FR-MAP-025
import XCTest
@testable import CrawlCall

final class FlightTests: XCTestCase {
    private var kit: Kit!
    private var tuning: TuningConfiguration!

    override func setUpWithError() throws {
        try super.setUpWithError()
        kit = try Kit.load(named: "blockout", from: .main)
        tuning = try Configurations.load(from: .main).tuning
    }

    private let cell = 0.5

    /// A floor of four cells in a row and a flight of `steps` arrows east of it,
    /// rising east onto a floor above that begins beyond the flight.
    private func text(steps: Int, arrow: Character = ">") -> String {
        let flight = String(repeating: arrow, count: steps)
        let ground = "...." + flight + "."
        let above = String(repeating: " ", count: 4 + steps) + ".."
        return "kit blockout\nsetting greenholm\nfloor 0\n\(ground)\nfloor 1\n\(above)\n"
    }

    private func parse(_ text: String) throws -> MapSpecification {
        try MapParser.parse(text, kit: kit, stepHeight: tuning.stepHeight)
    }

    // MARK: IF-MAP-010, FR-MAP-150 — arrows are steps rising to the floor above

    func testArrowsAreStepsCountedFromTheBottomOfTheFlight() throws {
        let map = try parse(text(steps: 8))
        let steps = map.placements.filter { $0.step != nil }.sorted { $0.x < $1.x }
        XCTAssertEqual(steps.map { $0.step?.index }, Array(1...8))
        XCTAssertTrue(steps.allSatisfy { $0.step?.count == 8 && $0.walkable && $0.module == kit.step?.name })
    }

    func testStepsRiseInEqualRisesAndTheTopIsLevelWithTheFloorAbove() throws {
        let map = try parse(text(steps: 8))
        let steps = map.placements.filter { $0.step != nil }.sorted { $0.x < $1.x }
        let heights = steps.map(map.height(of:))
        let rise = kit.floorHeight / 8
        for (index, height) in heights.enumerated() {
            XCTAssertEqual(height, rise * Double(index + 1), accuracy: 1e-9)
        }
        let beyond = try XCTUnwrap(map.placements.first { $0.floor == 1 && $0.x == 4 + 8 })
        XCTAssertEqual(try XCTUnwrap(heights.last), map.height(of: beyond), accuracy: 1e-9)
    }

    func testEveryArrowRisesTheWayItPoints() throws {
        // The same flight drawn each way round: its first step is always the one no
        // arrow of the flight leads up to.
        let west = try parse("kit blockout\nsetting greenholm\nfloor 0\n.<<<<<<<<....\nfloor 1\n..           \n")
        XCTAssertEqual(west.placements.first { $0.x == 8 }?.step?.index, 1)
        XCTAssertEqual(west.placements.first { $0.x == 1 }?.step?.index, 8)
        let north = try parse("kit blockout\nsetting greenholm\nfloor 0\n.\n^\n^\n^\n^\n^\n^\n^\n^\n.\nfloor 1\n.\n \n \n \n \n \n \n \n \n \n")
        XCTAssertEqual(north.placements.first { $0.z == 8 }?.step?.index, 1)
        XCTAssertEqual(north.placements.first { $0.z == 1 }?.step?.index, 8)
        let south = try parse("kit blockout\nsetting greenholm\nfloor 0\n.\nv\nv\nv\nv\nv\nv\nv\nv\n.\nfloor 1\n \n \n \n \n \n \n \n \n \n.\n")
        XCTAssertEqual(south.placements.first { $0.z == 1 }?.step?.index, 1)
        XCTAssertEqual(south.placements.first { $0.z == 8 }?.step?.index, 8)
    }

    func testTwoFlightsSideBySideAreTwoFlights() throws {
        let map = try parse("kit blockout\nsetting greenholm\nfloor 0\n>>>>>>>>.\n>>>>>>>>.\nfloor 1\n        .\n        .\n")
        XCTAssertEqual(map.placements.filter { $0.step?.index == 1 }.count, 2)
    }

    func testAFlightThatRisesToNothingIsRefusedWithItsTop() {
        // The floor above has no walkable cell beyond the top step.
        XCTAssertThrowsError(try parse("kit blockout\nsetting greenholm\nfloor 0\n.>>>>>>>>.\nfloor 1\n         #\n")) {
            XCTAssertEqual($0 as? MapParseError, .flightLeadsNowhere(floor: 0, line: 4, column: 9))
        }
        // And a flight on the top floor has no floor above at all.
        XCTAssertThrowsError(try parse("kit blockout\nsetting greenholm\nfloor 0\n.>>>>>>>>.\n")) {
            XCTAssertEqual($0 as? MapParseError, .flightLeadsNowhere(floor: 0, line: 4, column: 9))
        }
    }

    // MARK: FR-MAP-160 — a flight too steep to climb is refused

    func testAFlightTooSteepToClimbIsRefusedNamingItsLineAndRise() throws {
        // Seven steps over a floor of three metres rise 0.43 m each, more than the
        // step height; eight rise 0.375 m, which is not.
        let steep = 7
        let rise = kit.floorHeight / Double(steep)
        XCTAssertGreaterThan(rise, tuning.stepHeight, "the shipped numbers changed; choose another count")
        XCTAssertThrowsError(try parse(text(steps: steep))) { error in
            XCTAssertEqual(error as? MapParseError,
                           .flightTooSteep(line: 4, rise: rise, allowed: tuning.stepHeight))
            XCTAssertTrue(String(describing: error).hasPrefix("MAP_FLIGHT_TOO_STEEP: line 4"), "\(error)")
        }
        let fewest = Int((kit.floorHeight / tuning.stepHeight).rounded(.up))
        XCTAssertNoThrow(try parse(text(steps: fewest)))
    }

    func testAFlightIsTooSteepOnlyAgainstAStepHeight() throws {
        // The map does not carry the step height; the parser is handed it, and one not
        // handed it refuses nothing.
        let text = text(steps: 4)
        XCTAssertThrowsError(try MapParser.parse(text, kit: kit, stepHeight: tuning.stepHeight))
        XCTAssertNoThrow(try MapParser.parse(text, kit: kit), "without a step height nothing is too steep")
    }

    func testTheLaunchRefusesAMapWithAFlightTooSteep() throws {
        // End to end through the launch, which parses with the tuning's step height: a
        // bundle of the shipped files whose map has a flight of four steps.
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let main = try XCTUnwrap(Bundle.main.resourceURL)
        for directory in ["config", "maps"] {
            try FileManager.default.copyItem(at: main.appendingPathComponent(directory),
                                             to: root.appendingPathComponent(directory))
        }
        try text(steps: 4).write(to: root.appendingPathComponent("maps/steep.map"), atomically: true, encoding: .utf8)
        switch Launch.world(from: try XCTUnwrap(Bundle(url: root)), map: "steep") {
        case .success: XCTFail("a flight too steep to climb started a match")
        case .failure(let error):
            XCTAssertEqual(error as? MapParseError,
                           .flightTooSteep(line: 4, rise: kit.floorHeight / 4, allowed: tuning.stepHeight))
        }
    }

    func testAKitWhoseStepModuleIsNotInItsLegendIsRefused() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "legend", withExtension: "json", subdirectory: "config/kit/blockout"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        json["stepModule"] = "?"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folder = root.appendingPathComponent("config/kit/odd")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        try JSONSerialization.data(withJSONObject: json).write(to: folder.appendingPathComponent("legend.json"))
        XCTAssertThrowsError(try Kit.load(named: "odd", from: try XCTUnwrap(Bundle(url: root)))) {
            XCTAssertEqual($0 as? Kit.KitError, .stepModuleNotInLegend("?"))
        }
    }

    // MARK: FR-MAP-020 — nodes at their heights, joined a step apart

    func testTheGraphHoldsEachStepAtItsHeightAndJoinsTheFlightToBothFloors() throws {
        let map = try parse(text(steps: 8))
        let graph = NavigationGraph.derive(from: map, stepHeight: tuning.stepHeight)
        let rise = kit.floorHeight / 8
        for x in 4..<12 {
            let node = NavigationGraph.Node(floor: 0, x: x, z: 0)
            XCTAssertEqual(graph.height(of: node, floorHeight: kit.floorHeight), rise * Double(x - 3), accuracy: 1e-9)
        }
        // The bottom step joins the floor it stands on; the top step the floor above.
        XCTAssertTrue(graph.neighbours(of: .init(floor: 0, x: 3, z: 0)).contains(.init(floor: 0, x: 4, z: 0)))
        XCTAssertTrue(graph.neighbours(of: .init(floor: 0, x: 11, z: 0)).contains(.init(floor: 1, x: 12, z: 0)))
        XCTAssertEqual(graph.floorsReachable(from: .init(floor: 0, x: 0, z: 0)), [0, 1])
    }

    func testTheSideOfATallStepIsNoWayOnOrOff() throws {
        // A floor row alongside the flight: beside the low steps a bot steps on, beside
        // the high ones there is no edge — more than a step apart.
        let map = try parse("kit blockout\nsetting greenholm\nfloor 0\n....>>>>>>>>.\n.............\nfloor 1\n            .\n             \n")
        let graph = NavigationGraph.derive(from: map, stepHeight: tuning.stepHeight)
        let low = NavigationGraph.Node(floor: 0, x: 4, z: 0)      // 0.375 m
        let high = NavigationGraph.Node(floor: 0, x: 8, z: 0)     // 1.875 m
        XCTAssertTrue(graph.neighbours(of: low).contains(.init(floor: 0, x: 4, z: 1)))
        XCTAssertFalse(graph.neighbours(of: high).contains(.init(floor: 0, x: 8, z: 1)))
    }

    // MARK: FR-MAP-150 in the scene — a step is a block up to its height

    func testAStepIsABlockFromTheFloorSlabUpToItsHeight() throws {
        let map = try parse(text(steps: 8))
        let plan = ScenePlan.make(map: map, kit: kit, cellSize: cell)
        let slab = try element(1, of: XCTUnwrap(kit.floor).size)
        for placement in map.placements where placement.step != nil {
            let piece = try XCTUnwrap(plan.pieces.first {
                abs($0.centre.x - Double(placement.x) * cell) < 1e-9 && $0.module == kit.step?.name
            })
            XCTAssertEqual(piece.centre.y + piece.size.y / 2, map.height(of: placement), accuracy: 1e-9)
            XCTAssertEqual(piece.centre.y - piece.size.y / 2, -slab, accuracy: 1e-9)
        }
    }

    // MARK: the snake on a flight (FR-SNAKE-010, FR-MAP-025)

    private func surfaces(_ text: String) throws -> Surfaces {
        let map = try parse(text)
        return Surfaces(graph: NavigationGraph.derive(from: map, stepHeight: tuning.stepHeight),
                        kit: kit, tuning: tuning, map: map)
    }

    func testTheSnakeWalksUpAFlightOntoTheFloorAbove() throws {
        let s = try surfaces(text(steps: 8))
        var body = Snake(head: SIMD3(0, 0, 0), floor: 0, segments: 4, segmentSpacing: cell)
        var heights: [Double] = []
        for _ in 0..<240 {
            body.advance(direction: SIMD2(1, 0), speed: 3, seconds: 1.0 / 60, over: s)
            heights.append(body.head.y)
        }
        XCTAssertEqual(body.floor, 1, "the head did not reach the floor above")
        XCTAssertEqual(body.head.y, kit.floorHeight, accuracy: 1e-9)
        // Up through the heights in between, never higher than where it ends.
        XCTAssertGreaterThan(heights.filter { $0 > 1e-9 && $0 < kit.floorHeight - 1e-9 }.count, 30)
        XCTAssertLessThanOrEqual(try XCTUnwrap(heights.max()), kit.floorHeight + 1e-9)
        // And back down it to the ground.
        for _ in 0..<240 {
            body.advance(direction: SIMD2(-1, 0), speed: 3, seconds: 1.0 / 60, over: s)
        }
        XCTAssertEqual(body.floor, 0)
        XCTAssertEqual(body.head.y, 0, accuracy: 1e-9)
    }

    func testTheBodyStopsAgainstTheSideOfAStepTallerThanAStep() throws {
        // Walking along the floor beside the flight and turning into it where the
        // steps are tall: the body meets the step's side as it would a wall.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n....>>>>>>>>.\n.............\n.............\nfloor 1\n            .\n             \n             \n")
        let high = SIMD3(8 * cell, 0, 2 * cell)
        XCTAssertNotNil(s.clearance(at: SIMD3(8 * cell, 0, cell), feet: 0), "the tall step is not in the body's way")
        var body = Snake(head: high, floor: 0, segments: 4, segmentSpacing: cell)
        for _ in 0..<60 {
            body.advance(direction: SIMD2(0, -1), speed: 3, seconds: 1.0 / 60, over: s)
        }
        XCTAssertEqual(body.head.y, 0, accuracy: 1e-9, "the head climbed onto a step taller than a step")
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(s.clearance(at: body.head, feet: 0)).metres, -1e-9,
                                    "the body is inside the step")
    }

    func testTheSnakeDropsOffTheSideOfAHighStep() throws {
        // FR-SNAKE-220: the side of a flight is a ledge like a balcony's edge.
        let s = try surfaces("kit blockout\nsetting greenholm\nfloor 0\n....>>>>>>>>.\n.............\nfloor 1\n            .\n             \n")
        let rise = kit.floorHeight / 8
        var body = Snake(head: SIMD3(8 * cell, rise * 5, 0), floor: 0, segments: 4, segmentSpacing: cell)
        for _ in 0..<60 {
            body.advance(direction: SIMD2(0, 1), speed: 3, seconds: 1.0 / 60, over: s)
        }
        XCTAssertEqual(body.head.y, 0, accuracy: 1e-9, "the head did not come down off the step")
        XCTAssertGreaterThan(body.head.z, cell / 2)
    }

    // MARK: the bots on a flight

    func testABotWalksUpAFlightStepByStep() throws {
        let world = try Launch.world().get()
        let foot = try XCTUnwrap(world.map.placements.first { $0.step?.index == 1 })
        let top = try XCTUnwrap(world.map.placements.first { $0.step.map { $0.index == $0.count } ?? false })
        let from = NavigationGraph.Node(floor: 0, x: foot.x - 1, z: foot.z)
        let to = NavigationGraph.Node(floor: 1, x: top.x + 2, z: top.z)
        let path = Route.between(from, to, in: world.graph)
        XCTAssertFalse(path.isEmpty, "no route up the flight")
        let heights = path.map { world.graph.height(of: $0, floorHeight: world.kit.floorHeight) }
        // Up the flight, never by more than a step, and never back down.
        for (a, b) in zip(heights, heights.dropFirst()) {
            XCTAssertLessThanOrEqual(b - a, world.configurations.tuning.stepHeight + 1e-9)
            XCTAssertGreaterThanOrEqual(b, a - 1e-9)
        }
        XCTAssertEqual(try XCTUnwrap(heights.last), world.kit.floorHeight, accuracy: 1e-9)
        // Where a bot stands on a step is the step's height, not its floor's.
        let middle = NavigationGraph.Node(floor: 0, x: foot.x + 3, z: foot.z)
        let centre = world.graph.centre(of: middle, cellSize: cell, floorHeight: world.kit.floorHeight)
        XCTAssertEqual(centre.y, world.kit.floorHeight / Double(foot.step?.count ?? 1) * 4, accuracy: 1e-9)
    }
}

/// The shipped tuning, for a test that needs one of its numbers rather than a copy of
/// it: a test that carried its own would pass the day the maintainer changed the one
/// that matters.
enum ShippedTuning {
    /// The tallest step the snake and the bots climb (IF-MAP-020, FR-MAP-025).
    static let stepHeight: Double = (try? Configurations.load(from: .main).tuning.stepHeight) ?? .nan
}
