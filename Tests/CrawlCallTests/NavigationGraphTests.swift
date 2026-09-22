// One node per walkable cell and floor, an edge for every transition between floors
// (FR-MAP-020), derived from the grids and the transitions (FR-TOOL-030).
//
// verifies: FR-TOOL-030, FR-MAP-020
import XCTest
@testable import CrawlCall

final class NavigationGraphTests: XCTestCase {
    private lazy var kit: Kit = { try! Kit.load(named: "blockout", from: .main) }()

    private func graph(_ text: String) throws -> NavigationGraph {
        NavigationGraph.derive(from: try MapParser.parse(text, kit: kit))
    }

    func testEveryWalkableCellBecomesANodeAndNothingElseDoes() throws {
        let g = try graph("""
        kit blockout
        floor 0
        ..#.
        .oo.
        """)
        // Eight cells: four floor on the top row minus one wall, and two floor cells
        // on the bottom row; crates and walls are not walkable.
        XCTAssertEqual(g.nodeCount, 5)
        XCTAssertTrue(g.isWalkable(.init(floor: 0, x: 0, z: 0)))
        XCTAssertFalse(g.isWalkable(.init(floor: 0, x: 2, z: 0)))   // the wall
        XCTAssertFalse(g.isWalkable(.init(floor: 0, x: 1, z: 1)))   // a crate
    }

    func testNeighboursAreTheFourOrthogonalCellsAndNotTheDiagonal() throws {
        let g = try graph("""
        kit blockout
        floor 0
        ...
        ...
        ...
        """)
        let middle = NavigationGraph.Node(floor: 0, x: 1, z: 1)
        XCTAssertEqual(g.neighbours(of: middle), [
            .init(floor: 0, x: 0, z: 1), .init(floor: 0, x: 2, z: 1),
            .init(floor: 0, x: 1, z: 0), .init(floor: 0, x: 1, z: 2),
        ])
        XCTAssertFalse(g.neighbours(of: middle).contains(.init(floor: 0, x: 0, z: 0)))
    }

    func testAWallBetweenTwoCellsLeavesThemUnlinked() throws {
        let g = try graph("kit blockout\nfloor 0\n.#.\n")
        XCTAssertTrue(g.neighbours(of: .init(floor: 0, x: 0, z: 0)).isEmpty)
        XCTAssertEqual(g.edgeCount, 0)
    }

    func testATransitionIsTheEdgeBetweenTwoFloors() throws {
        let text = """
        kit blockout
        transition 1,0 0 1
        floor 0
        ../
        floor 1
        ../
        """
        let g = try graph(text)
        // The two stair cells are one edge apart, so both floors are one walk.
        XCTAssertEqual(g.floorsReachable(from: .init(floor: 0, x: 0, z: 0)), [0, 1])
    }

    func testWithoutItsTransitionLineTheFloorsAreSeparate() throws {
        // The same map with the transition removed: the geometry alone does not join
        // floors, which is what makes the header's transition list load-bearing.
        let g = try graph("""
        kit blockout
        floor 0
        ../
        floor 1
        ../
        """)
        XCTAssertEqual(g.floorsReachable(from: .init(floor: 0, x: 0, z: 0)), [0])
    }

    func testATransitionOntoSomethingUnwalkableMakesNoEdge() throws {
        // Reporting this is FR-TOOL-040's job; the graph's part is not to invent a way
        // through a wall.
        let g = try graph("""
        kit blockout
        transition 1,0 0 1
        floor 0
        ...
        floor 1
        .#.
        """)
        XCTAssertEqual(g.floorsReachable(from: .init(floor: 0, x: 0, z: 0)), [0])
    }

    func testEdgesAreTwoWay() throws {
        let g = try graph("kit blockout\nfloor 0\n..\n")
        let a = NavigationGraph.Node(floor: 0, x: 0, z: 0)
        let b = NavigationGraph.Node(floor: 0, x: 1, z: 0)
        XCTAssertTrue(g.neighbours(of: a).contains(b))
        XCTAssertTrue(g.neighbours(of: b).contains(a))
        XCTAssertEqual(g.edgeCount, 1)
    }

    func testAnEmptyCellIsNotANode() throws {
        let g = try graph("kit blockout\nfloor 0\n. .\n")
        XCTAssertEqual(g.nodeCount, 2)
        XCTAssertFalse(g.isWalkable(.init(floor: 0, x: 1, z: 0)))
        XCTAssertEqual(g.edgeCount, 0)      // the gap leaves them unlinked
    }
}
