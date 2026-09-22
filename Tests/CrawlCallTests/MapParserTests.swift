// The map file as IF-MAP-010 describes it, and FR-TOOL-010's other half: a file that
// is wrong is rejected naming the line and the reason.
//
// verifies: IF-MAP-010, FR-TOOL-010, FR-MAP-100
import XCTest
@testable import CrawlCall

final class MapParserTests: XCTestCase {
    private lazy var kit: Kit = {
        try! Kit.load(named: "blockout", from: .main)
    }()

    private let good = """
    ; a two-floor scrap
    kit blockout
    transition 2,1 0 1
    floor 0
    ....
    .##.
    ....
    floor 1
    ..
    ./
    """

    // MARK: what a map is

    func testAMapParsesIntoFloorsTransitionsAndPlacements() throws {
        let map = try MapParser.parse(good, kit: kit)
        XCTAssertEqual(map.kit, "blockout")
        XCTAssertEqual(map.floors.map(\.level), [0, 1])
        XCTAssertEqual(map.transitions, [.init(x: 2, z: 1, from: 0, to: 1)])
        // 12 cells on floor 0 and 4 on floor 1, every one of them a module here.
        XCTAssertEqual(map.placements.count, 16)
        XCTAssertEqual(map.placements.filter { $0.module == "wall" }.count, 2)
        XCTAssertEqual(map.placements.filter { $0.floor == 1 && $0.module == "stair" }.count, 1)
    }

    func testAPlacementSitsAtTheCellItsCharacterOccupies() throws {
        let map = try MapParser.parse(good, kit: kit)
        let stair = try XCTUnwrap(map.placements.first { $0.module == "stair" })
        XCTAssertEqual(stair.floor, 1)
        XCTAssertEqual(stair.x, 1)          // second column
        XCTAssertEqual(stair.z, 1)          // second row
        XCTAssertTrue(stair.walkable)
        let walls = map.placements.filter { $0.module == "wall" }.map { [$0.x, $0.z] }
        XCTAssertEqual(walls, [[1, 1], [2, 1]])
        XCTAssertFalse(try XCTUnwrap(map.placements.first { $0.module == "wall" }).walkable)
    }

    func testEmptySpacePlacesNothingAndIsNotAnUnknownCharacter() throws {
        let map = try MapParser.parse("kit blockout\nfloor 0\n. .\n", kit: kit)
        XCTAssertEqual(map.placements.count, 2)
        XCTAssertEqual(map.placements.map(\.x), [0, 2])
        XCTAssertEqual(map.floors[0].rows, [". ."])   // the row is kept as written
    }

    func testARowOfSpacesIsARowOfEmptyCellsAndNotABlankLine() throws {
        // A floor that starts with cells nothing stands on — a balcony over the far
        // half of the room. Trimming those rows away would move everything below them.
        let map = try MapParser.parse("kit blockout\nfloor 1\n    \n  ..\n", kit: kit)
        XCTAssertEqual(map.floors[0].rows.count, 2)
        XCTAssertEqual(map.floors[0].rows[0], "    ")
        XCTAssertEqual(map.placements.map(\.z), [1, 1])   // both on the second row
        XCTAssertEqual(map.placements.map(\.x), [2, 3])
    }

    func testCommentsAndBlankLinesAreIgnored() throws {
        let map = try MapParser.parse("""
        ; header

        kit blockout

        floor 0
        ..
        """, kit: kit)
        XCTAssertEqual(map.placements.count, 2)
    }

    // MARK: what a rejection says

    private func rejects(_ text: String, _ expected: MapParseError,
                         file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try MapParser.parse(text, kit: kit), file: file, line: line) { error in
            XCTAssertEqual(error as? MapParseError, expected, file: file, line: line)
        }
    }

    func testAFileWithNoKitIsRejected() {
        rejects("floor 0\n..\n", .noKit)
    }

    func testAFileWithNoFloorsIsRejected() {
        rejects("kit blockout\n", .noFloors)
    }

    func testASecondKitLineIsRejectedWithItsLine() {
        rejects("kit blockout\nkit other\nfloor 0\n..\n", .repeatedKit(line: 2))
    }

    func testAnUnknownDirectiveIsRejectedWithItsLine() {
        rejects("kit blockout\nceiling 2\nfloor 0\n..\n", .unknownDirective("ceiling 2", line: 2))
    }

    func testAGridRowBeforeAnyFloorIsRejected() {
        rejects("kit blockout\n....\nfloor 0\n..\n", .gridBeforeAnyFloor(line: 2))
    }

    func testTheSameFloorTwiceIsRejected() {
        rejects("kit blockout\nfloor 0\n..\nfloor 0\n..\n", .repeatedFloor(0, line: 4))
    }

    func testAFloorThatIsNotANumberIsRejected() {
        rejects("kit blockout\nfloor ground\n..\n", .badFloorNumber("ground", line: 2))
    }

    func testAMalformedTransitionIsRejectedWithItsText() {
        rejects("kit blockout\ntransition 2 0 1\nfloor 0\n..\n", .badTransition("transition 2 0 1", line: 2))
    }

    func testATransitionToAFloorTheFileDoesNotDeclareIsRejected() {
        rejects("kit blockout\ntransition 0,0 0 4\nfloor 0\n..\n", .transitionToUnknownFloor(4, line: 2))
    }

    func testARaggedGridIsRejectedWithBothWidths() {
        rejects("kit blockout\nfloor 0\n....\n..\n", .raggedGrid(floor: 0, line: 4, expected: 4, found: 2))
    }

    func testACharacterTheLegendDoesNotNameIsRejectedWithItsColumn() {
        rejects("kit blockout\nfloor 0\n..x.\n", .unknownCharacter("x", floor: 0, line: 3, column: 3))
    }

    func testAFloorWithNoGridUnderItIsRejected() {
        rejects("kit blockout\nfloor 0\nfloor 1\n..\n", .emptyFloor(0, line: 2))
    }

    func testEveryRejectionNamesItsLineInWords() {
        // FR-TOOL-010 asks for the line and the reason, so the text a person reads
        // has to carry the number, not just the error value.
        XCTAssertTrue(MapParseError.raggedGrid(floor: 0, line: 7, expected: 4, found: 2)
            .description.contains("line 7"))
        XCTAssertTrue(MapParseError.unknownCharacter("x", floor: 1, line: 9, column: 3)
            .description.contains("line 9"))
        XCTAssertTrue(MapParseError.unknownCharacter("x", floor: 1, line: 9, column: 3)
            .description.contains("column 3"))
    }

    // MARK: the kit

    func testTheShippedKitLoadsAndKnowsItsCharacters() throws {
        XCTAssertEqual(kit.floorHeight, 3.0)
        XCTAssertNotNil(kit.module(for: "."))
        XCTAssertEqual(kit.module(for: ".")?.name, "floor")
        XCTAssertTrue(kit.module(for: ".")?.walkable ?? false)
        XCTAssertFalse(kit.module(for: "#")?.walkable ?? true)
        XCTAssertNil(kit.module(for: "x"))
        XCTAssertNil(kit.module(for: " "))
    }

    func testAKitThatIsNotInTheBundleIsNamedRatherThanCrashing() {
        XCTAssertThrowsError(try Kit.load(named: "nosuchkit", from: .main)) { error in
            XCTAssertEqual(error as? Kit.KitError, .missing(name: "nosuchkit"))
        }
    }
}

/// The map the stage-1 slice actually ships with.
///
/// verifies: IF-MAP-010, FR-TOOL-010, FR-MAP-010, FR-MAP-020, FR-TOOL-020, FR-TOOL-030
final class ShippedMapTests: XCTestCase {
    private lazy var kit: Kit = { try! Kit.load(named: "blockout", from: .main) }()

    private func shippedMap() throws -> MapSpecification {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "blockout", withExtension: "map",
                                                subdirectory: "maps"))
        return try MapParser.parse(try String(contentsOf: url, encoding: .utf8), kit: kit)
    }

    func testTheShippedMapParses() throws {
        let map = try shippedMap()
        XCTAssertEqual(map.kit, "blockout")
        XCTAssertEqual(map.floors.count, 2)
        XCTAssertEqual(map.floors.map(\.rows.count), [16, 16])
        XCTAssertTrue(map.floors.allSatisfy { $0.rows.allSatisfy { $0.count == 24 } })
    }

    func testItHasTwoFloorsJoinedByATransitionTheSnakeCanTraverse() throws {
        // FR-MAP-010, read off the map rather than asserted about it.
        let map = try shippedMap()
        XCTAssertGreaterThanOrEqual(Set(map.floors.map(\.level)).count, 2)
        XCTAssertFalse(map.transitions.isEmpty)

        let graph = NavigationGraph.derive(from: map)
        let transition = try XCTUnwrap(map.transitions.first)
        let bottom = NavigationGraph.Node(floor: transition.from, x: transition.x, z: transition.z)
        XCTAssertTrue(graph.isWalkable(bottom), "the transition's lower end is not walkable")
        XCTAssertTrue(graph.isWalkable(.init(floor: transition.to, x: transition.x, z: transition.z)),
                      "the transition's upper end is not walkable")
        XCTAssertEqual(graph.floorsReachable(from: bottom), [0, 1])
    }

    func testEveryWalkableCellOfTheShippedMapIsReachableFromTheGround() throws {
        // A pocket nobody can walk into is a map bug, and the kind an eye misses.
        let map = try shippedMap()
        let graph = NavigationGraph.derive(from: map)
        let start = try XCTUnwrap(graph.nodes.first { $0.floor == 0 })
        var seen: Set<NavigationGraph.Node> = [start]
        var queue = [start]
        while let node = queue.popLast() {
            for next in graph.neighbours(of: node) where !seen.contains(next) {
                seen.insert(next); queue.append(next)
            }
        }
        XCTAssertEqual(seen.count, graph.nodeCount,
                       "\(graph.nodeCount - seen.count) walkable cells cannot be reached")
    }

    func testTheSceneIsPlacedOverTheSameCellsTheGraphKnows() throws {
        // FR-TOOL-020 and FR-TOOL-030 read the same map; if they disagreed, bots would
        // path over geometry that is not there.
        let map = try shippedMap()
        let cell = try Configurations.load(from: .main).tuning.navigationGraphCellSize
        let plan = ScenePlan.make(map: map, kit: kit, cellSize: cell)
        let graph = NavigationGraph.derive(from: map)
        // The graph is built from the map's cells, not from the scene's pieces — and
        // it has to stay that way now that a floor piece also appears under a wall,
        // where nobody may walk. So the comparison is against the walkable cells.
        let walkableCells = map.placements.filter(\.walkable)
        XCTAssertEqual(walkableCells.count, graph.nodeCount)
        // And every one of them has a surface under it in the scene.
        for walkable in walkableCells {
            let x = Double(walkable.x) * cell
            let z = Double(walkable.z) * cell
            let surface = plan.pieces.contains { piece in
                abs(piece.centre.x - x) < 1e-9 && abs(piece.centre.z - z) < 1e-9
                    && abs(piece.centre.y + piece.size.y / 2 - Double(walkable.floor) * kit.floorHeight) < 1e-9
            }
            XCTAssertTrue(surface, "cell \(walkable.x),\(walkable.z) on floor \(walkable.floor) has nothing to stand on")
        }
    }
}

/// `kitName` reads the header on its own, before the legend is in hand, so that the
/// game knows which kit to load. Two readers of one header can drift apart; these
/// keep them together.
///
/// verifies: IF-MAP-010, FR-TOOL-010
final class MapHeaderTests: XCTestCase {
    private lazy var kit: Kit = { try! Kit.load(named: "blockout", from: .main) }()

    func testTheKitIsReadBeforeAnythingElse() throws {
        XCTAssertEqual(try MapParser.kitName(in: "; note\n\nkit blockout\nfloor 0\n..\n"), "blockout")
    }

    func testAFileWithNoKitLineSaysSoRatherThanGuessing() {
        XCTAssertThrowsError(try MapParser.kitName(in: "floor 0\n..\n")) { error in
            XCTAssertEqual(error as? MapParseError, .noKit)
        }
    }

    func testAKitNamedAfterTheFirstFloorIsNotAHeader() {
        // The header ends where the grids begin; a `kit` line below them is a mistake
        // the full parse also refuses, and the two readers agree about it.
        XCTAssertThrowsError(try MapParser.kitName(in: "floor 0\n..\nkit blockout\n")) { error in
            XCTAssertEqual(error as? MapParseError, .noKit)
        }
    }

    func testBothReadersAgreeOnTheShippedMap() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "blockout", withExtension: "map",
                                                subdirectory: "maps"))
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(try MapParser.kitName(in: text), try MapParser.parse(text, kit: kit).kit)
    }

    func testAFileWrittenOnWindowsReadsTheSame() throws {
        let unix = "kit blockout\nfloor 0\n.#.\n. .\n"
        let windows = unix.replacingOccurrences(of: "\n", with: "\r\n")
        let a = try MapParser.parse(unix, kit: kit)
        let b = try MapParser.parse(windows, kit: kit)
        XCTAssertEqual(a, b)
        XCTAssertEqual(try MapParser.kitName(in: windows), "blockout")
    }
}
