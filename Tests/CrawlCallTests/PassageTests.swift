// A map, as drawn, shows the snake no way its body cannot take (FR-MAP-260, ADR-0035).
// The requirement names no kind of place, and the check behind it compares what the eye
// sees with where the snake can be; the cases here are the places that were found
// before the rule was general, and the places that must stay allowed.
//
// file verifies: FR-MAP-260
import XCTest
@testable import CrawlCall

final class PassageTests: XCTestCase {
    private var kit: Kit!
    private var tuning: TuningConfiguration!
    private var setting: Setting!

    override func setUpWithError() throws {
        try super.setUpWithError()
        kit = try Kit.load(named: "blockout", from: .main)
        tuning = try Configurations.load(from: .main).tuning
        setting = try Setting.load(named: "greenholm", from: .main)
    }

    private var body: Passages.Body { .init(radius: tuning.bodyRadius, stepHeight: tuning.stepHeight) }

    /// A map of the floors given, each as `(level, rows)`.
    private func map(_ floors: [(Int, String)]) throws -> (MapSpecification, ScenePlan) {
        let text = "kit blockout\nsetting greenholm\n" + floors.map { "floor \($0.0)\n\($0.1)\n" }.joined()
        let map = try MapParser.parse(text, kit: kit, stepHeight: tuning.stepHeight)
        return (map, ScenePlan.make(map: map, kit: kit, cellSize: tuning.navigationGraphCellSize))
    }

    private func findings(_ rows: String, body: Passages.Body? = nil) throws -> [Passages.Finding] {
        try findings([(0, rows)], body: body)
    }

    private func findings(_ floors: [(Int, String)], body: Passages.Body? = nil) throws -> [Passages.Finding] {
        let (map, plan) = try map(floors)
        return Passages.findings(in: map, plan: plan, edge: setting.edge(around: plan), body: body ?? self.body)
    }

    private func cells(_ found: [Passages.Finding]) -> Set<PieceIndex.Cell> { Set(found.map(\.cell)) }

    // MARK: - What the map may show

    func testOpenGroundAndWhatStandsWellApartShowNoFalseWay() throws {
        XCTAssertEqual(try findings(",,,\n,,,\n,,,"), [])
        // Two walls a metre apart: the body of 0.6 m passes between them.
        XCTAssertEqual(try findings(",,,,,,\n,#..#,\n,,,,,,"), [])
        // A tree a cell in from the water, with a cell to pass it by on every side.
        XCTAssertEqual(try findings(",,,,,\n,,,,,\n,,T,,\n,,,,,\n,,,,,"), [])
    }

    func testWhatStopsNoMovementHidesNoWay() throws {
        XCTAssertEqual(try findings(",*,\n,,,\n,,,"), [], "a shrub is walked through, at the water's edge or not")
    }

    func testARoomWalledRoundAtTheMapsEdgeIsAllowed() throws {
        // The ground the edge draws outside its walls leads nowhere the snake could
        // come from, and inside there is nothing but room.
        XCTAssertEqual(try findings("#####\n#...#\n#...#\n#####"), [])
    }

    func testAGapTheWaterShowsIsNotAWay() throws {
        // Two stretches of map six metres apart: the water shows between them.
        let wide = ",," + String(repeating: " ", count: 12) + ",,"
        XCTAssertEqual(try findings([wide, wide, wide].joined(separator: "\n")), [])
    }

    func testAWallBesideABasementsOpeningIsAllowed() throws {
        XCTAssertEqual(try findings([(-1, "....\n....\n...."), (0, ",,,,\n,# ,\n,,,,")]), [])
    }

    // MARK: - What it may not

    func testAGapBetweenWallsNarrowerThanTheBodyIsFound() throws {
        let found = try findings(",,,,,\n,#.#,\n,,,,,")
        XCTAssertEqual(found.map(\.kind), [.closedGap])
        XCTAssertTrue(cells(found).isSubset(of: [PieceIndex.Cell(x: 1, z: 1), PieceIndex.Cell(x: 3, z: 1)]),
                      "named at \(found), not at a wall of the gap")
    }

    func testTheGapIsMeasuredAgainstTheBodyItIsGiven() throws {
        let rows = ",,,,,\n,#.#,\n,,,,,"
        XCTAssertEqual(try findings(rows, body: .init(radius: 0.2, stepHeight: tuning.stepHeight)), [],
                       "a gap wider than the body was refused")
        XCTAssertFalse(try findings(rows, body: .init(radius: 0.3, stepHeight: tuning.stepHeight)).isEmpty)
    }

    func testPartitionsInAColumnAreFinsWithSlotsBetweenThem() throws {
        // A partition is thin across z, so two in a column stand 0.4 m apart.
        XCTAssertEqual(try findings(",,,\n,=,\n,=,\n,,,").map(\.kind), [.closedGap])
    }

    func testTheSideOfAFlightIsAWallToTheGapBesideIt() throws {
        // A flight along the second row, rows of floor, then a wall.
        func flight(gap: Int) -> [(Int, String)] {
            let ground = [",,,,,,,,,,,", ",>>>>>>>>.,"] + Array(repeating: ",.........,", count: gap)
                + [",#########,", ",,,,,,,,,,,"]
            let above = ["           ", "         . "] + Array(repeating: "           ", count: gap + 2)
            return [(0, ground.joined(separator: "\n")), (1, above.joined(separator: "\n"))]
        }
        XCTAssertTrue(try findings(flight(gap: 1)).contains { $0.kind == .closedGap && $0.level == 0 },
                      "the row between a flight and a wall was taken for a way")
        XCTAssertFalse(try findings(flight(gap: 2)).contains { $0.level == 0 },
                       "two rows beside a flight were refused")
    }

    func testATreeAtTheWatersEdgeIsFound() throws {
        let found = try findings(",T,\n,,,\n,,,")
        XCTAssertEqual(found.map(\.kind), [.closedGap])
        XCTAssertEqual(found.map(\.cell), [PieceIndex.Cell(x: 1, z: 0)], "named by the tree")
    }

    func testATreeCornerToCornerWithTheWaterIsFound() throws {
        // The blockout's south-west corner as it was: the way round the tree runs
        // between its corner and the water's, where no cell is.
        let found = try findings(",,,,\n,,T,\n,,, ")
        XCTAssertTrue(found.contains { $0.kind == .closedGap && $0.cell == PieceIndex.Cell(x: 2, z: 1) }, "\(found)")
    }

    func testAnEmptyCellTheDrawnGroundClosesOverIsFound() throws {
        let hole = try findings(",,,,\n, ,,\n,,,,")
        XCTAssertEqual(hole.map(\.kind), [.unreachableGround])
        XCTAssertEqual(hole.map(\.cell), [PieceIndex.Cell(x: 1, z: 1)])
        // A notch in the map's edge, one cell deep, as the blockout had at its left.
        let notch = try findings(",,,\n ,,\n,,,")
        XCTAssertEqual(notch.map(\.kind), [.unreachableGround])
        XCTAssertEqual(notch.map(\.cell), [PieceIndex.Cell(x: 0, z: 1)])
    }

    func testARoomWhoseOnlyDoorIsTooNarrowIsFound() throws {
        // The eye sees the room and the ground outside as one, through the door; the
        // snake stands on them apart.
        let found = try findings(",,,,,,,\n,#####,\n,#...#,\n,#...#,\n,##.##,\n,,,,,,,\n,,,,,,,")
        XCTAssertTrue(found.contains { $0.kind == .partedGround && $0.cell == PieceIndex.Cell(x: 3, z: 4) }, "\(found)")
    }

    func testAMapShowingAWayNotTakenIsRefusedNamingIt() throws {
        let (map, plan) = try map([(0, ",T,\n,,,\n,,,")])
        XCTAssertThrowsError(try Passages.require(map, plan: plan, setting: setting, body: body)) {
            XCTAssertEqual($0 as? MapParseError, .wayNotTaken(line: 4, column: 2))
        }
    }

    // MARK: - The maps the game ships and the suite uses

    func testTheShippedMapsShowNoWayTheSnakeCannotTake() throws {
        // Read without the launch, which would stop at the first place: every place is
        // named here.
        for name in ["blockout", "room"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: Resource.mapExtension,
                                                    subdirectory: Resource.mapDirectory))
            let map = try MapParser.parse(String(contentsOf: url, encoding: .utf8), kit: kit, stepHeight: tuning.stepHeight)
            let plan = ScenePlan.make(map: map, kit: kit, cellSize: tuning.navigationGraphCellSize)
            let found = Passages.findings(in: map, plan: plan, edge: setting.edge(around: plan), body: body)
            XCTAssertEqual(found, [], "\(name): " + found.map { "\($0.kind) on floor \($0.level) at \($0.cell.x),\($0.cell.z)" }
                .joined(separator: "; "))
        }
    }
}
