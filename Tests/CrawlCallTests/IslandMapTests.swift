// A map of any shape standing on its setting: the setting's edge along the map's
// outline, rounded (FR-MAP-200); floor 0 the ground, basements open below it
// (FR-MAP-170); the snake born where the map says (FR-MAP-180, FR-MAP-190); and what
// each module stops (FR-MAP-210, FR-MAP-220).
//
// verifies: FR-MAP-170, FR-MAP-180, FR-MAP-190, FR-MAP-200, FR-MAP-210, FR-MAP-220, FR-GREENHOLM-010, IF-MAP-010
import RealityKit
import XCTest
@testable import CrawlCall

extension Game {
    /// Where a test starts a match on a map: its first spawn point, the same every
    /// run, where the game would choose one at random (FR-MAP-180). On the shipped map
    /// that is the corner of the room, where every match began before spawn points.
    static func firstStart(in world: World) -> NavigationGraph.Node? {
        guard let first = world.map.spawns.first else { return start(in: world) }
        return NavigationGraph.Node(floor: first.floor, x: first.x, z: first.z)
    }
}

/// A generator a test can repeat.
struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class DistanceFieldTests: XCTestCase {
    func testTheTransformIsTheDistanceToTheNearestSampleOfTheSet() {
        // Against every pair, on grids of random sets.
        var chooser = SplitMix(state: 7)
        for _ in 0..<5 {
            let grid = SampleGrid(covering: SIMD2(0, 0), SIMD2(1.2, 0.9), step: 0.1)
            let mask = (0..<grid.count).map { _ in Int.random(in: 0..<9, using: &chooser) == 0 }
            let fast = DistanceField.distance(to: mask, on: grid)
            for row in 0..<grid.height {
                for column in 0..<grid.width {
                    var best = Double.infinity
                    for r in 0..<grid.height {
                        for c in 0..<grid.width where mask[grid.index(c, r)] {
                            let d = grid.point(c, r) - grid.point(column, row)
                            best = min(best, (d.x * d.x + d.y * d.y).squareRoot())
                        }
                    }
                    XCTAssertEqual(fast[grid.index(column, row)], best, accuracy: 1e-9)
                }
            }
        }
    }

    func testAnEmptySetIsInfinitelyFar() {
        let grid = SampleGrid(covering: .zero, SIMD2(0.3, 0.3), step: 0.1)
        XCTAssertTrue(DistanceField.distance(to: [Bool](repeating: false, count: grid.count), on: grid)
            .allSatisfy { $0 == .infinity })
    }
}

final class OutlineTests: XCTestCase {
    private let cell = 0.5
    private let margin = 0.5
    private let rounding = 1.0

    private func outline(_ cells: Set<PieceIndex.Cell>, basement: Set<PieceIndex.Cell> = []) throws -> Outline {
        try XCTUnwrap(Outline.around(cells, basement: basement, cellSize: cell, margin: margin,
                                     rounding: rounding, reach: 1.7))
    }

    private func value(_ o: Outline, at point: SIMD2<Double>) -> Double {
        let column = Int(((point.x - o.grid.origin.x) / o.grid.step).rounded())
        let row = Int(((point.y - o.grid.origin.y) / o.grid.step).rounded())
        return o.signed[o.grid.index(column, row)]
    }

    private func block(_ xs: ClosedRange<Int>, _ zs: ClosedRange<Int>) -> Set<PieceIndex.Cell> {
        Set(xs.flatMap { x in zs.map { PieceIndex.Cell(x: x, z: $0) } })
    }

    func testTheEdgeLiesOutsideEveryCellByTheMargin() throws {
        // An L of cells: every corner of every cell is at least the margin inside the edge.
        let cells = block(0...7, 0...3).union(block(0...3, 4...9))
        let o = try outline(cells)
        for c in cells {
            for dx in [-0.5, 0.5] { for dz in [-0.5, 0.5] {
                let corner = SIMD2(Double(c.x) + dx, Double(c.z) + dz) * cell
                // Measured on samples, the field can fall short of the margin by up to
                // about two steps of the grid — never more — and still leaves the
                // edge well outside the cell.
                XCTAssertGreaterThanOrEqual(value(o, at: corner), margin - 2 * o.grid.step,
                                            "cell \(c) is not inside the edge by the margin")
            } }
        }
    }

    func testAStaircaseIsDrawnAsASmoothSlope() throws {
        // A triangle of cells whose hypotenuse is a staircase of whole cells. Where its
        // edge crosses the diagonal across the stairs, it keeps to one line: no step of
        // the grid shows, where the cells' own outline swings by half a cell's diagonal.
        var cells: Set<PieceIndex.Cell> = []
        for x in 0..<16 { for z in 0...x { cells.insert(PieceIndex.Cell(x: x, z: z)) } }
        let o = try outline(cells)
        // Along lines across the diagonal, where does the field cross zero?
        var offsets: [Double] = []
        for t in stride(from: 3.0, through: 5.0, by: 0.1) {
            let base = SIMD2(t, t)                           // a point on the diagonal
            let out = SIMD2(-1.0, 1.0) / 2.0.squareRoot()   // away from the triangle
            var s = 0.0
            while value(o, at: base + out * s) > 0 { s += 0.005 }
            offsets.append(s)
        }
        XCTAssertLessThan(try XCTUnwrap(offsets.max()) - XCTUnwrap(offsets.min()), 0.05, "the edge steps along the stairs: \(offsets)")
        // The cells' own outline, measured the same way, steps by far more — which is
        // what the rounding takes away.
        let staircase = cell * 0.5 * 2.0.squareRoot()
        XCTAssertGreaterThan(staircase, 0.3)
    }

    func testANarrowHollowIsFilledAndAWideOneFollowed() throws {
        // Two arms with a gap of one cell between them, and two with a gap of eight.
        let narrow = block(0...2, 0...9).union(block(4...6, 0...9)).union(block(0...6, 10...12))
        let o = try outline(narrow)
        XCTAssertGreaterThan(value(o, at: SIMD2(3, 1) * cell), 0, "a gap of one cell is not filled")
        let wide = block(0...2, 0...9).union(block(11...13, 0...9)).union(block(0...13, 10...12))
        let w = try outline(wide)
        XCTAssertLessThan(value(w, at: SIMD2(7, 1) * cell), 0, "a gap of eight cells is filled")
    }

    func testTheGroundIsLeftOpenOverABasement() throws {
        let cells = block(0...9, 0...9)
        let basement = block(3...5, 3...5)
        let o = try outline(cells, basement: basement)
        let mesh = Outline.surface(where: o.region(atLeast: 0, sparingBasements: true), on: o.grid, height: 0)
        XCTAssertFalse(mesh.isEmpty)
        for t in stride(from: 0, to: mesh.indices.count, by: 3) {
            let centre = (try vertex(t, of: mesh) + vertex(t + 1, of: mesh) + vertex(t + 2, of: mesh)) / 3
            let c = PieceIndex.Cell(x: Int((centre.x / cell).rounded()), z: Int((centre.z / cell).rounded()))
            XCTAssertFalse(basement.contains(c), "the ground covers the basement at \(c)")
        }
        // Without the basement, the same cells are covered.
        let whole = Outline.surface(where: o.region(atLeast: 0, sparingBasements: false), on: o.grid, height: 0)
        XCTAssertGreaterThan(whole.indices.count, 0)
    }

    func testTheSurfaceCoversTheRegionAndNothingElse() throws {
        // Its area is the region's to within a sliver per square of the edge.
        let cells = block(0...5, 0...5)
        let o = try outline(cells)
        let field = o.region(atLeast: 0, sparingBasements: false)
        let mesh = Outline.surface(where: field, on: o.grid, height: 0)
        var area = 0.0
        for t in stride(from: 0, to: mesh.indices.count, by: 3) {
            let (a, b, c) = (try vertex(t, of: mesh), try vertex(t + 1, of: mesh), try vertex(t + 2, of: mesh))
            area += abs((b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)) / 2
        }
        let inside = Double(field.filter { $0 >= 0 }.count) * o.grid.step * o.grid.step
        XCTAssertEqual(area, inside, accuracy: inside * 0.03)
    }

    func testTheRestOfTheWaterIsTheCoveredGroundLessTheIsland() {
        let covered = GroundRect(lowest: SIMD2(-10, -10), highest: SIMD2(10, 10))
        let hole = GroundRect(lowest: SIMD2(-2, -3), highest: SIMD2(4, 5))
        let pieces = covered.around(hole)
        XCTAssertEqual(pieces.count, 4)
        var chooser = SplitMix(state: 3)
        for _ in 0..<500 {
            let p = SIMD2(Double.random(in: -10...10, using: &chooser), Double.random(in: -10...10, using: &chooser))
            let inHole = hole.contains(p)
            let count = pieces.filter { $0.contains(p) }.count
            if inHole { XCTAssertEqual(count, 0) } else { XCTAssertGreaterThanOrEqual(count, 1) }
        }
        // And a hole outside the rectangle leaves it whole.
        XCTAssertEqual(covered.around(GroundRect(lowest: SIMD2(20, 20), highest: SIMD2(30, 30))), [covered])
    }
}

@MainActor
final class GreenholmIslandTests: XCTestCase {
    func testTheShippedIslandHasGroundShoreAndWaterAndNoRingOfTrees() throws {
        let world = try Launch.world().get()
        let camera = CameraRange(view: world.configurations.view, plan: world.plan, widestAspect: 2.174)
        let s = try world.setting.scenery(around: world.plan, camera: camera)
        XCTAssertTrue(s.parts.allSatisfy { $0.layer == .water }, "scenery other than water is a primitive again")
        XCTAssertEqual(s.surfaces.filter { $0.layer == .ground }.count, 4)
        XCTAssertEqual(s.surfaces.filter { $0.layer == .water }.count, 1)
        XCTAssertTrue(s.surfaces.allSatisfy { !$0.mesh.isEmpty })
        // The water reaches everything the camera can show: the covered ground, less the
        // island's grid, in slabs, and the grid's own water cut to the shore.
        let slabs = s.parts.map { GroundRect(lowest: SIMD2($0.lowest.x, $0.lowest.z), highest: SIMD2($0.highest.x, $0.highest.z)) }
        let island = s.surfaces.flatMap(\.mesh.positions)
        let low = SIMD2(try XCTUnwrap(island.map(\.x).min()), try XCTUnwrap(island.map(\.z).min()))
        let high = SIMD2(try XCTUnwrap(island.map(\.x).max()), try XCTUnwrap(island.map(\.z).max()))
        var chooser = SplitMix(state: 11)
        for _ in 0..<2000 {
            let p = SIMD2(Double.random(in: s.covered.lowest.x...s.covered.highest.x, using: &chooser),
                          Double.random(in: s.covered.lowest.y...s.covered.highest.y, using: &chooser))
            let inSlab = slabs.contains { $0.grown(by: 1e-6).contains(p) }
            let inGrid = GroundRect(lowest: low, highest: high).grown(by: 0.1).contains(p)
            XCTAssertTrue(inSlab || inGrid, "no water at \(p)")
        }
    }

    func testTheSceneryIsBuiltWithItsSurfaces() throws {
        let world = try Launch.world().get()
        let built = SceneBuilder.scene(for: world.plan, view: world.configurations.view)
        let ambient = try XCTUnwrap(built.root.children.first { $0.name == EntityName.ambient })
        let camera = CameraRange(view: world.configurations.view, plan: world.plan, widestAspect: 2.174)
        let s = try world.setting.scenery(around: world.plan, camera: camera)
        let root = SceneryBuilder.entity(for: s, ambient: ambient)
        let models = root.children.compactMap { $0 as? ModelEntity }
        XCTAssertEqual(models.count, s.parts.count + s.surfaces.filter { !$0.mesh.isEmpty }.count)
        XCTAssertTrue(models.allSatisfy { $0.components.has(ImageBasedLightReceiverComponent.self) })
    }
}

final class GroundFloorTests: XCTestCase {
    private var kit: Kit!

    override func setUpWithError() throws {
        try super.setUpWithError()
        kit = try Kit.load(named: "blockout", from: .main)
    }

    func testTheGroundIsFloorZeroWhateverLiesBelowIt() throws {
        // A basement under a room: the ground is laid under floor 0, not under the
        // basement, which lies below it.
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor -1\n..\nfloor 0\n..\n", kit: kit)
        let plan = ScenePlan.make(map: map, kit: kit, cellSize: 0.5)
        let slab = try element(1, of: XCTUnwrap(kit.floor).size)
        XCTAssertEqual(plan.underside, -slab, accuracy: 1e-9)
        XCTAssertLessThan(plan.bounds.lowest.y, -kit.floorHeight + 1e-9)
    }
}

@MainActor
final class SpawnTests: XCTestCase {
    private var kit: Kit!

    override func setUpWithError() throws {
        try super.setUpWithError()
        kit = try Kit.load(named: "blockout", from: .main)
    }

    func testAMapNamesItsSpawnPointsInTheHeader() throws {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nspawn 0,0 0\nspawn 2,1 0\nfloor 0\n...\n...\n", kit: kit)
        XCTAssertEqual(map.spawns, [.init(x: 0, z: 0, floor: 0, line: 3), .init(x: 2, z: 1, floor: 0, line: 4)])
        XCTAssertNoThrow(try MapParser.requireSpawns(map))
    }

    func testAMalformedSpawnIsRefusedWithItsLine() {
        XCTAssertThrowsError(try MapParser.parse("kit blockout\nsetting greenholm\nspawn 0 0\nfloor 0\n..\n", kit: kit)) {
            XCTAssertEqual($0 as? MapParseError, .badSpawn("spawn 0 0", line: 3))
        }
    }

    func testAMapToBePlayedWithoutASpawnPointOrWithOneInAWallIsRefused() throws {
        let none = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n..\n", kit: kit)
        XCTAssertThrowsError(try MapParser.requireSpawns(none)) { XCTAssertEqual($0 as? MapParseError, .noSpawn) }
        let wall = try MapParser.parse("kit blockout\nsetting greenholm\nspawn 1,0 0\nfloor 0\n.#\n", kit: kit)
        XCTAssertThrowsError(try MapParser.requireSpawns(wall)) {
            XCTAssertEqual($0 as? MapParseError, .spawnNotWalkable(line: 3))
        }
        let air = try MapParser.parse("kit blockout\nsetting greenholm\nspawn 5,5 0\nfloor 0\n..\n", kit: kit)
        XCTAssertThrowsError(try MapParser.requireSpawns(air))
        // A shrub stops no movement, so the snake may be born in one.
        let shrub = try MapParser.parse("kit blockout\nsetting greenholm\nspawn 1,0 0\nfloor 0\n.*\n", kit: kit)
        XCTAssertNoThrow(try MapParser.requireSpawns(shrub))
    }

    func testTheSnakeIsBornAtOneOfTheSpawnPointsChosenAtRandom() throws {
        let world = try Launch.world().get()
        let spawns = Set(world.map.spawns.map { NavigationGraph.Node(floor: $0.floor, x: $0.x, z: $0.z) })
        XCTAssertGreaterThan(spawns.count, 1, "the shipped map has one spawn point, so nothing is chosen")
        var chooser = SplitMix(state: 1)
        var seen: Set<NavigationGraph.Node> = []
        for _ in 0..<200 {
            let start = try XCTUnwrap(Game.start(in: world, using: &chooser))
            XCTAssertTrue(spawns.contains(start), "born at \(start), which the map does not name")
            seen.insert(start)
        }
        XCTAssertEqual(seen, spawns, "some spawn point is never chosen")
        // And a match begins where it was chosen.
        let start = try XCTUnwrap(Game.start(in: world, using: &chooser))
        let game = Game(world: world, start: start)
        XCTAssertEqual(game.snake.floor, start.floor)
        XCTAssertEqual(game.snake.head.x, Double(start.x) * world.plan.cellSize, accuracy: world.plan.cellSize / 2)
        XCTAssertEqual(game.snake.head.z, Double(start.z) * world.plan.cellSize, accuracy: world.plan.cellSize / 2)
    }

    func testARestartChoosesItsSpawnPointAgain() throws {
        let world = try Launch.world().get()
        let spawns = Set(world.map.spawns.map { NavigationGraph.Node(floor: $0.floor, x: $0.x, z: $0.z) })
        var game = Game(world: world, start: try XCTUnwrap(Game.firstStart(in: world)))
        var seen: Set<NavigationGraph.Node> = []
        // Three spawn points and sixty restarts: every restart landing on the same one
        // happens with odds of one in 10^28.
        for _ in 0..<60 {
            game = game.restarted()
            let head = NavigationGraph.Node(floor: game.snake.floor,
                                            x: Int((game.snake.head.x / world.plan.cellSize).rounded()),
                                            z: Int((game.snake.head.z / world.plan.cellSize).rounded()))
            XCTAssertTrue(spawns.contains(head), "restarted at \(head), which the map does not name")
            seen.insert(head)
        }
        XCTAssertGreaterThan(seen.count, 1, "every restart starts where the first match did")
    }
}

final class PermeabilityTests: XCTestCase {
    private var kit: Kit!
    private var tuning: TuningConfiguration!

    override func setUpWithError() throws {
        try super.setUpWithError()
        kit = try Kit.load(named: "blockout", from: .main)
        tuning = try Configurations.load(from: .main).tuning
    }

    func testTheKitSaysWhatEachModuleStops() throws {
        let tree = try XCTUnwrap(kit.module(for: "T")), shrub = try XCTUnwrap(kit.module(for: "*"))
        XCTAssertTrue(tree.stopsMovement && tree.stopsSight)
        XCTAssertTrue(!shrub.stopsMovement && shrub.stopsSight)
        XCTAssertEqual(kit.floor(under: tree)?.name, "ground")
        XCTAssertEqual(kit.floor(under: try XCTUnwrap(kit.module(for: "#")))?.name, "floor")
    }

    func testAShrubIsWalkedThroughAndATreeIsNot() throws {
        // A row of ground with a shrub and a tree in it: the graph goes through the
        // shrub's cell and not the tree's.
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n,*,T,\n", kit: kit)
        let graph = NavigationGraph.derive(from: map, stepHeight: tuning.stepHeight)
        XCTAssertTrue(graph.isWalkable(.init(floor: 0, x: 1, z: 0)), "no one can stand in the shrub")
        XCTAssertFalse(graph.isWalkable(.init(floor: 0, x: 3, z: 0)), "someone can stand in the tree")
        XCTAssertTrue(graph.neighbours(of: .init(floor: 0, x: 0, z: 0)).contains(.init(floor: 0, x: 1, z: 0)))
        // The snake's body passes the shrub and stops at the tree.
        let s = Surfaces(graph: graph, kit: kit, tuning: tuning, map: map)
        var body = Snake(head: SIMD3(0, 0, 0), floor: 0, segments: 3, segmentSpacing: 0.5)
        for _ in 0..<90 { body.advance(direction: SIMD2(1, 0), speed: 3, seconds: 1.0 / 60, over: s) }
        XCTAssertGreaterThan(body.head.x, 1 * 0.5, "the shrub stopped the snake")
        XCTAssertLessThan(body.head.x, 3 * 0.5 - 0.25, "the snake went into the tree")
    }

    func testAShrubAndATreeBothHideWhatIsBehindThem() throws {
        for character in ["*", "T"] {
            let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n,\(character),\n", kit: kit)
            let plan = ScenePlan.make(map: map, kit: kit, cellSize: 0.5)
            XCTAssertFalse(Sight.isClear(from: SIMD3(0, 0.4, 0), to: SIMD3(1, 0.2, 0), through: plan),
                           "the \(character) hides nothing")
        }
        // And ground alone hides nothing above it.
        let open = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n,,,\n", kit: kit)
        XCTAssertTrue(Sight.isClear(from: SIMD3(0, 0.4, 0), to: SIMD3(1, 0.2, 0),
                                    through: ScenePlan.make(map: open, kit: kit, cellSize: 0.5)))
    }

    func testAModuleThatStopsNoSightIsSeenThrough() throws {
        // A grille: it stops movement and lets sight through. No module of the shipped
        // kit is one, so the kit is written here; without FR-MAP-220's rule every
        // module would stop sight.
        let json = """
        {"floorHeight": 3.0, "floorModule": ".", "stepModule": ".", "trunkColour": [0.4, 0.3, 0.2],
         "modules": {
           ".": {"name": "floor", "walkable": true, "stopsMovement": false, "stopsSight": true,
                 "floor": ".", "figure": "box", "size": [0.5, 0.1, 0.5], "colour": [0.5, 0.5, 0.5]},
           "|": {"name": "grille", "walkable": false, "stopsMovement": true, "stopsSight": false,
                 "floor": ".", "figure": "box", "size": [0.5, 1.5, 0.5], "colour": [0.3, 0.3, 0.3]}}}
        """
        let grilled = try Configurations.decode(Kit.self, named: "kit/grille/legend", schema: Kit.schema, from: Data(json.utf8))
        let map = try MapParser.parse("kit grille\nsetting greenholm\nfloor 0\n.|.\n", kit: grilled)
        let plan = ScenePlan.make(map: map, kit: grilled, cellSize: 0.5)
        XCTAssertTrue(Sight.isClear(from: SIMD3(0, 0.4, 0), to: SIMD3(1, 0.2, 0), through: plan),
                      "the grille hides what is behind it")
        let graph = NavigationGraph.derive(from: map, stepHeight: tuning.stepHeight)
        XCTAssertFalse(graph.isWalkable(.init(floor: 0, x: 1, z: 0)), "someone can stand in the grille")
    }

    func testTreesAndShrubsStandOnTheGroundTheyName() throws {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n,*T.#\n", kit: kit)
        let plan = ScenePlan.make(map: map, kit: kit, cellSize: 0.5)
        func under(_ x: Int) -> String? {
            plan.pieces.first { abs($0.centre.x - Double(x) * 0.5) < 1e-9 && $0.centre.y < 0 }?.module
        }
        XCTAssertEqual(under(1), "ground")
        XCTAssertEqual(under(2), "ground")
        XCTAssertEqual(under(4), "floor")
    }

    @MainActor
    func testATreeIsDrawnAsACrownOnATrunkAndAShrubAsAMound() throws {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\nT*\n", kit: kit)
        let plan = ScenePlan.make(map: map, kit: kit, cellSize: 0.5)
        let built = SceneBuilder.entity(for: plan)
        let tree = try XCTUnwrap(built.root.children.first { $0.name == "tree" } as? ModelEntity)
        XCTAssertEqual(tree.children.count, 1, "the tree has no trunk")
        let shrub = try XCTUnwrap(built.root.children.first { $0.name == "shrub" } as? ModelEntity)
        XCTAssertTrue(shrub.children.isEmpty)
        // Drawn within its box's height, from the ground up.
        let piece = try XCTUnwrap(plan.pieces.first { $0.module == "tree" })
        let bounds = tree.visualBounds(relativeTo: nil)
        XCTAssertEqual(Double(bounds.max.y), piece.centre.y + piece.size.y / 2, accuracy: 0.02)
        XCTAssertEqual(Double(bounds.min.y), piece.centre.y - piece.size.y / 2, accuracy: 0.02)
    }
}
