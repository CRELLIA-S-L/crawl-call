// The coordinates a map turns into (FR-TOOL-020).
//
// verifies: FR-TOOL-020
import RealityKit
import XCTest
@testable import CrawlCall

final class ScenePlanTests: XCTestCase {
    private lazy var kit: Kit = { try! Kit.load(named: "blockout", from: .main) }()

    private func plan(_ text: String, cell: Double = 0.5) throws -> ScenePlan {
        ScenePlan.make(map: try MapParser.parse(text, kit: kit), kit: kit, cellSize: cell)
    }

    func testACellsPositionIsItsIndexTimesTheCellSize() throws {
        let p = try plan("kit blockout\nsetting greenholm\nfloor 0\n...\n...\n")
        let corner = try XCTUnwrap(p.pieces.first)
        XCTAssertEqual(corner.centre.x, 0, accuracy: 1e-9)
        XCTAssertEqual(corner.centre.z, 0, accuracy: 1e-9)
        let far = p.pieces[p.pieces.count - 1]
        XCTAssertEqual(far.centre.x, 2 * 0.5, accuracy: 1e-9)   // third column
        XCTAssertEqual(far.centre.z, 1 * 0.5, accuracy: 1e-9)   // second row
    }

    func testAFloorSlabHangsBelowItsWalkingSurfaceAndAWallStandsOnIt() throws {
        let p = try plan("kit blockout\nsetting greenholm\nfloor 0\n.#\n")
        let slab = try XCTUnwrap(p.pieces.first { $0.module == "floor" })
        let wall = try XCTUnwrap(p.pieces.first { $0.module == "wall" })
        // The slab is 0.1 thick, so its centre is half of that below zero.
        XCTAssertEqual(slab.centre.y, -0.05, accuracy: 1e-9)
        // A wall stands on the surface, so its centre is half its own height above it
        // — less the overlap that keeps its underside out of the slab's plane. Its
        // height is read from the kit and not written here: the kit is where the
        // number lives, and a test that carried a copy of it would fail the day the
        // maintainer changed the one that matters.
        let height = try XCTUnwrap(kit.module(for: "#")).size[1]
        XCTAssertEqual(wall.size.y, height, accuracy: 1e-9)
        XCTAssertEqual(wall.centre.y, height / 2 - MapGrid.surfaceOverlap, accuracy: 1e-9)
        // Which is what matters: the two faces are not in one plane.
        let wallBottom = wall.centre.y - wall.size.y / 2
        XCTAssertLessThan(wallBottom, slab.centre.y + slab.size.y / 2)
    }

    func testTheUpperFloorSitsOneFloorHeightAbove() throws {
        let p = try plan("kit blockout\nsetting greenholm\nfloor 0\n.\nfloor 1\n.\n")
        let ys = p.pieces.map(\.centre.y).sorted()
        XCTAssertEqual(ys.first!, -0.05, accuracy: 1e-9)
        XCTAssertEqual(ys.last!, kit.floorHeight - 0.05, accuracy: 1e-9)
    }

    func testTheCellSizeComesFromTheCallerNotTheKit() throws {
        let p = try plan("kit blockout\nsetting greenholm\nfloor 0\n..\n", cell: 1.25)
        XCTAssertEqual(p.pieces[1].centre.x, 1.25, accuracy: 1e-9)
        XCTAssertEqual(p.cellSize, 1.25)
    }

    func testEverySizeComesFromTheKitsLegend() throws {
        let p = try plan("kit blockout\nsetting greenholm\nfloor 0\n.#o=/\n")
        // Five cells, of which the wall, the crate and the partition are not walkable
        // and each gains the floor it stands on; the stair is walkable and is its own
        // surface, so it gains nothing (FR-TOOL-020).
        XCTAssertEqual(p.pieces.count, 8)
        for piece in p.pieces {
            let module = kit.modules.values.first { $0.name == piece.module }
            XCTAssertEqual(piece.size, SIMD3(module!.size[0], module!.size[1], module!.size[2]))
        }
    }

    func testEmptyCellsProduceNoPieces() throws {
        let p = try plan("kit blockout\nsetting greenholm\nfloor 0\n. .\n")
        XCTAssertEqual(p.pieces.count, 2)
    }
}

/// What the camera has to aim at when there is no snake to follow yet, and the colours
/// the kit gives every module.
///
/// verifies: FR-TOOL-020, FR-MAP-100
final class ScenePlanBoundsTests: XCTestCase {
    private lazy var kit: Kit = { try! Kit.load(named: "blockout", from: .main) }()

    func testTheBoundsCoverEveryPieceIncludingItsThickness() throws {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n..\n", kit: kit)
        let plan = ScenePlan.make(map: map, kit: kit, cellSize: 0.5)
        // Two 0.5 × 0.1 × 0.5 slabs, the second half a metre along x, tops at y = 0.
        XCTAssertEqual(plan.bounds.lowest.x, -0.25, accuracy: 1e-9)
        XCTAssertEqual(plan.bounds.highest.x, 0.75, accuracy: 1e-9)
        XCTAssertEqual(plan.bounds.highest.y, 0, accuracy: 1e-9)
        XCTAssertEqual(plan.bounds.lowest.y, -0.1, accuracy: 1e-9)
        XCTAssertEqual(plan.bounds.centre.x, 0.25, accuracy: 1e-9)
        XCTAssertEqual(plan.bounds.extent.x, 1.0, accuracy: 1e-9)
    }

    func testAnEmptyPlanHasEmptyBoundsRatherThanCrashing() {
        let plan = ScenePlan(pieces: [], cellSize: 0.5, floorHeight: 3)
        XCTAssertEqual(plan.bounds.centre, .zero)
        XCTAssertEqual(plan.bounds.extent, .zero)
    }

    func testEveryPieceCarriesTheColourItsModuleDeclares() throws {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n.#o=/\n", kit: kit)
        let plan = ScenePlan.make(map: map, kit: kit, cellSize: 0.5)
        for piece in plan.pieces {
            let module = try XCTUnwrap(kit.modules.values.first { $0.name == piece.module })
            XCTAssertEqual(piece.colour, SIMD3(module.colour[0], module.colour[1], module.colour[2]))
        }
        // The kit tells the modules apart, which is the point of having colours at all.
        XCTAssertEqual(Set(plan.pieces.map { "\($0.colour)" }).count, 5)
    }

    func testTheShippedMapIsWiderThanItIsDeepAndStandsOnTheOrigin() throws {
        let world = try Launch.world().get()
        XCTAssertEqual(world.plan.bounds.lowest.x, -0.25, accuracy: 1e-9)
        XCTAssertEqual(world.plan.bounds.extent.x, 12.0, accuracy: 1e-9)   // 24 cells of 0.5
        XCTAssertEqual(world.plan.bounds.extent.z, 8.0, accuracy: 1e-9)    // 16 cells of 0.5
    }
}

/// The scene as RealityKit gets it: the map, the light that makes it readable and the
/// camera it is seen through, all present and wired.
///
/// verifies: FR-TOOL-020, FR-VIEW-010, FR-VIEW-130
@MainActor
final class SceneBuilderTests: XCTestCase {
    private func scene() throws -> Entity {
        let world = try Launch.world().get()
        return SceneBuilder.scene(for: world.plan, view: world.configurations.view).root
    }

    func testTheSceneCarriesTheMapTheLightsTheAmbientAndTheCamera() throws {
        let names = try scene().children.map(\.name).sorted()
        XCTAssertEqual(names, ["ambient", "camera", "light", "map"])
    }

    func testEveryPieceOfTheMapIsAModelThatReceivesTheAmbientLight() throws {
        let world = try Launch.world().get()
        let scene = try scene()
        let map = try XCTUnwrap(scene.children.first { $0.name == "map" })
        let ambient = try XCTUnwrap(scene.children.first { $0.name == "ambient" })
        // Every piece the plan holds, which is now the cells plus the floors implied
        // under whatever stands on them.
        XCTAssertEqual(map.children.count, world.plan.pieces.count)
        XCTAssertGreaterThan(map.children.count, 454)
        // Without this component a model is lit only by the directional lights, and
        // whatever they miss renders black — which FR-VIEW-130 forbids.
        for model in map.children {
            let receiver = model.components[ImageBasedLightReceiverComponent.self]
            XCTAssertEqual(receiver?.imageBasedLight, ambient, "\(model.name) receives no ambient light")
        }
    }

    func testTheCameraSitsAtThePitchTheConfigurationSets() throws {
        let world = try Launch.world().get()
        let scene = SceneBuilder.scene(for: world.plan, view: world.configurations.view).root
        let camera = try XCTUnwrap(scene.children.first { $0.name == "camera" })
        // Pitch read back off the orientation, in degrees below the horizontal.
        let forward = camera.orientation.act(SIMD3<Float>(0, 0, -1))
        let pitch = -asin(forward.y) * 180 / .pi
        XCTAssertEqual(Double(pitch), world.configurations.view.cameraPitch, accuracy: 0.001)
        // And it stands back from the map rather than inside it.
        XCTAssertGreaterThan(camera.position.z, Float(world.plan.bounds.highest.z))
    }

    func testTheCameraHasNoYawAtAll() throws {
        // The other half of FR-VIEW-010: the yaw does not change, which is what lets
        // height and sight lines be learnt once. A camera that starts turned would
        // make "does not change" true and the requirement pointless.
        let world = try Launch.world().get()
        let camera = try XCTUnwrap(SceneView.camera(for: world.plan, view: world.configurations.view)
            as Entity?)
        let forward = camera.orientation.act(SIMD3<Float>(0, 0, -1))
        // Looking straight down the -Z axis in plan: no sideways component.
        XCTAssertEqual(forward.x, 0, accuracy: 1e-6)
        XCTAssertLessThan(forward.z, 0)
        // The camera's own right stays the world's right: a rotation about X alone.
        let right = camera.orientation.act(SIMD3<Float>(1, 0, 0))
        XCTAssertEqual(right.x, 1, accuracy: 1e-5)
        XCTAssertEqual(right.y, 0, accuracy: 1e-6)
        XCTAssertEqual(right.z, 0, accuracy: 1e-6)
    }

    func testTheSceneIsLitByOneDaylightSourceThatCastsShadows() throws {
        // FR-VIEW-130 asks for a single source: two would cast two shadow directions
        // and the shapes would stop reading as one diorama.
        let scene = try scene()
        let directional = scene.children.compactMap { $0 as? DirectionalLight }
        XCTAssertEqual(directional.count, 1)
        let sun = try XCTUnwrap(directional.first)
        XCTAssertNotNil(sun.shadow)
        XCTAssertGreaterThan(sun.light.intensity, 0)
    }

    func testTheAmbientLightIsAnImageBasedOneSoNothingReadsBlack() throws {
        // The other half of FR-VIEW-130: what the sun misses still has to be visible.
        let ambient = try XCTUnwrap(try scene().children.first { $0.name == "ambient" })
        let component = ambient.components[ImageBasedLightComponent.self]
        XCTAssertNotNil(component, "the scene has no ambient light")
        // The component's own "no source" case, not a missing component: that is the
        // assertion above.
        if case ImageBasedLightComponent.Source.none? = component?.source {
            XCTFail("the ambient light carries no environment")
        }
    }
}

/// A cell holds one module, so the floor under a wall is the assembler's to place
/// (FR-TOOL-020). Without it the scene has a hole wherever anything stands.
///
/// verifies: FR-TOOL-020
final class ImpliedFloorTests: XCTestCase {
    private lazy var kit: Kit = { try! Kit.load(named: "blockout", from: .main) }()

    private func plan(_ text: String) throws -> ScenePlan {
        ScenePlan.make(map: try MapParser.parse(text, kit: kit), kit: kit, cellSize: 0.5)
    }

    func testAWallCellAlsoGetsAFloorUnderIt() throws {
        let p = try plan("kit blockout\nsetting greenholm\nfloor 0\n#\n")
        XCTAssertEqual(p.pieces.count, 2)
        let floor = try XCTUnwrap(p.pieces.first { $0.module == "floor" })
        let wall = try XCTUnwrap(p.pieces.first { $0.module == "wall" })
        XCTAssertEqual(floor.centre.x, wall.centre.x, accuracy: 1e-9)
        XCTAssertEqual(floor.centre.z, wall.centre.z, accuracy: 1e-9)
        // The floor's top is the surface the wall stands on.
        XCTAssertEqual(floor.centre.y + floor.size.y / 2, 0, accuracy: 1e-9)
    }

    func testAWalkableCellIsNotGivenASecondFloor() throws {
        let p = try plan("kit blockout\nsetting greenholm\nfloor 0\n.\n")
        XCTAssertEqual(p.pieces.count, 1)
    }

    func testEmptySpaceGetsNoFloorEither() throws {
        let p = try plan("kit blockout\nsetting greenholm\nfloor 0\n# #\n")
        XCTAssertEqual(p.pieces.filter { $0.module == "floor" }.count, 2)
        XCTAssertEqual(p.pieces.count, 4)     // two walls, each on its own floor
    }

    func testTheShippedMapHasNoCellWhereSomethingStandsOnNothing() throws {
        let world = try Launch.world().get()
        // Every piece that is not the floor has a floor piece under its own cell.
        let kit = world.kit
        func isWalkable(_ module: String) -> Bool {
            kit.modules.values.first { $0.name == module }?.walkable ?? false
        }
        let floors = world.plan.pieces.filter { $0.module == "floor" }
        // A walkable module is a surface itself and stands on nothing; everything else
        // has to have one under it.
        for piece in world.plan.pieces where !isWalkable(piece.module) {
            let base = piece.centre.y - piece.size.y / 2 + MapGrid.surfaceOverlap
            let stands = floors.contains { floor in
                abs(floor.centre.x - piece.centre.x) < 1e-9
                    && abs(floor.centre.z - piece.centre.z) < 1e-9
                    && abs(floor.centre.y + floor.size.y / 2 - base) < 1e-6
            }
            XCTAssertTrue(stands, "\(piece.module) at \(piece.centre) stands on nothing")
        }
    }
}

/// A tail rests on surfaces, so the surfaces under a route have to meet (FR-MAP-090).
///
/// verifies: FR-MAP-090
final class TailSurfaceTests: XCTestCase {
    private lazy var kit: Kit = { try! Kit.load(named: "blockout", from: .main) }()

    private func kitWithFloorWidth(_ width: Double) throws -> Kit {
        let json = """
        {"floorHeight": 3.0, "floorModule": ".", "stepModule": ".",
         "modules": {".": {"name": "floor", "walkable": true,
                           "size": [\(width), 0.1, \(width)], "colour": [0.5, 0.5, 0.5]}}}
        """
        return try Configurations.decode(Kit.self, named: "kit/test/legend",
                                         schema: Kit.schema, from: Data(json.utf8))
    }

    private func gap(floorWidth: Double, cell: Double = 0.5) throws -> Double {
        let kit = try kitWithFloorWidth(floorWidth)
        let map = try MapParser.parse("kit test\nsetting greenholm\nfloor 0\n..\n..\n", kit: kit)
        return ScenePlan.make(map: map, kit: kit, cellSize: cell)
            .widestGap(along: NavigationGraph.derive(from: map, stepHeight: ShippedTuning.stepHeight))
    }

    func testAFloorModuleThatFillsItsCellLeavesNoGap() throws {
        XCTAssertEqual(try gap(floorWidth: 0.5), 0, accuracy: 1e-9)
    }

    func testANarrowerFloorModuleLeavesTheDifference() throws {
        // Half-metre cells, forty-centimetre slabs: ten centimetres of nothing.
        XCTAssertEqual(try gap(floorWidth: 0.4), 0.1, accuracy: 1e-9)
    }

    func testTheShippedMapIsWithinTheTolerance() throws {
        let world = try Launch.world().get()
        let widest = world.plan.widestGap(along: world.graph)
        XCTAssertLessThanOrEqual(widest, world.configurations.tuning.tailGapTolerance,
                                 "the widest gap is \(widest) m against a tolerance of \(world.configurations.tuning.tailGapTolerance) m")
    }

    func testAGapWiderThanTheToleranceIsVisibleToTheCheck() throws {
        // The check earns its place only if it can fail: a kit with slabs half the
        // width of a cell leaves a quarter of a metre, past the shipped tolerance.
        let tolerance = try Configurations.load(from: .main).tuning.tailGapTolerance
        XCTAssertGreaterThan(try gap(floorWidth: 0.2), tolerance)
    }
}

/// The camera holds still while the snake moves inside the frame, and moves when it
/// would leave it (FR-VIEW-020).
///
/// verifies: FR-VIEW-020
final class CameraFollowTests: XCTestCase {
    private let region = ViewConfiguration.CentralRegion(width: 0.4, height: 0.4)
    private let distance = 12.0
    private let fov = 50.0

    private var halfZone: Double {
        SceneView.groundSpan(distance: distance, fieldOfViewDegrees: fov) * 0.4 / 2
    }
    /// An arena wider than anything these tests walk, so that the rule under test is
    /// the central region and not the edge the camera stops at.
    private let open = ScenePlan.Bounds(lowest: SIMD3(-1000, 0, -1000),
                                        highest: SIMD3(1000, 0, 1000))

    func testTheGroundSpanFollowsFromTheFieldOfView() {
        // Two sides of a triangle: half the span over the distance is tan(fov / 2).
        let span = SceneView.groundSpan(distance: 10, fieldOfViewDegrees: 90)
        XCTAssertEqual(span, 20, accuracy: 1e-9)      // tan 45° = 1
    }

    func testAHeadInsideTheRegionLeavesTheCameraWhereItIs() {
        let focus = SIMD3(0.0, 0.0, 0.0)
        let head = SIMD3(halfZone * 0.5, 0.0, 0.0)
        let moved = SceneView.focus(keeping: head, inside: region, from: focus,
                                    distance: distance, fieldOfViewDegrees: fov, within: open)
        XCTAssertEqual(moved.x, focus.x, accuracy: 1e-9)
        XCTAssertEqual(moved.z, focus.z, accuracy: 1e-9)
    }

    func testAHeadPastTheRegionPullsTheCameraJustEnough() {
        let focus = SIMD3(0.0, 0.0, 0.0)
        let head = SIMD3(halfZone + 3, 0.0, 0.0)
        let moved = SceneView.focus(keeping: head, inside: region, from: focus,
                                    distance: distance, fieldOfViewDegrees: fov, within: open)
        // The head ends up on the boundary, not in the middle: the picture moves as
        // little as it can.
        XCTAssertEqual(head.x - moved.x, halfZone, accuracy: 1e-9)
    }

    func testTheHeadNeverLeavesTheRegionHoweverFarItWalks() {
        var focus = SIMD3(0.0, 0.0, 0.0)
        var head = SIMD3(0.0, 0.0, 0.0)
        for _ in 0..<200 {
            head.x += 0.31
            head.z += 0.17
            focus = SceneView.focus(keeping: head, inside: region, from: focus,
                                    distance: distance, fieldOfViewDegrees: fov, within: open)
            XCTAssertLessThanOrEqual(abs(head.x - focus.x), halfZone + 1e-9)
            XCTAssertLessThanOrEqual(abs(head.z - focus.z), halfZone + 1e-9)
        }
        XCTAssertGreaterThan(focus.x, 0)      // it did follow
    }

    func testTheCameraStopsAtTheArenasEdgeRatherThanShowingTheVoid() {
        // A match begins in a corner: obeying the region alone would centre the
        // picture on the head and spend half the screen on ground that is not there.
        let span = SceneView.groundSpan(distance: distance, fieldOfViewDegrees: fov)
        let arena = ScenePlan.Bounds(lowest: SIMD3(0, 0, 0), highest: SIMD3(span * 3, 0, span * 3))
        let corner = SIMD3(0.0, 0.0, 0.0)
        let moved = SceneView.focus(keeping: corner, inside: region, from: corner,
                                    distance: distance, fieldOfViewDegrees: fov, within: arena)
        XCTAssertGreaterThanOrEqual(moved.x, arena.lowest.x + span / 2 - 1e-9)
        XCTAssertGreaterThanOrEqual(moved.z, arena.lowest.z + span / 2 - 1e-9)
        // And it stops, rather than centring on the arena: the head is still what the
        // camera is about.
        XCTAssertLessThan(moved.x, arena.centre.x)
    }

    func testAnArenaNarrowerThanTheFrameIsCentredInIt() {
        let span = SceneView.groundSpan(distance: distance, fieldOfViewDegrees: fov)
        let small = ScenePlan.Bounds(lowest: SIMD3(2, 0, 2), highest: SIMD3(2 + span / 2, 0, 2 + span / 2))
        let head = SIMD3(2.0, 0.0, 2.0)
        let moved = SceneView.focus(keeping: head, inside: region, from: head,
                                    distance: distance, fieldOfViewDegrees: fov, within: small)
        XCTAssertEqual(moved.x, small.centre.x, accuracy: 1e-9)
        XCTAssertEqual(moved.z, small.centre.z, accuracy: 1e-9)
    }

    func testTheCameraFollowsAFloorChangeAtOnce() {
        let focus = SIMD3(0.0, 0.0, 0.0)
        let head = SIMD3(0.0, 3.0, 0.0)
        let moved = SceneView.focus(keeping: head, inside: region, from: focus,
                                    distance: distance, fieldOfViewDegrees: fov, within: open)
        XCTAssertEqual(moved.y, 3.0, accuracy: 1e-9)
    }

    @MainActor
    func testPlacingTheCameraKeepsThePitchAndStandsBackFromTheFocus() {
        let camera = Entity()
        SceneView.place(camera, lookingAt: SIMD3(2, 0, 3), pitchDegrees: 55, distance: 10)
        let forward = camera.orientation.act(SIMD3<Float>(0, 0, -1))
        XCTAssertEqual(Double(-asin(forward.y) * 180 / .pi), 55, accuracy: 1e-3)
        XCTAssertEqual(camera.position.x, 2, accuracy: 1e-5)
        XCTAssertGreaterThan(camera.position.y, 0)
        XCTAssertGreaterThan(camera.position.z, 3)
    }
}
