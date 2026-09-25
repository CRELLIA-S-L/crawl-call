// The world around the arena: how much ground the match camera can show and that the
// setting covers it (FR-MAP-140), that scenery stays out of play (FR-MAP-130), the
// setting a map names (FR-MAP-120) and Greenholm's configuration (IF-GREENHOLM-010).
//
// The coverage is checked against a derivation of its own: the frame's corner rays are
// taken from the camera entity the game itself places (`SceneView.place`), turned by
// RealityKit's own quaternion, rather than from the formula under test.
//
// verifies: FR-MAP-120, FR-MAP-130, FR-MAP-140, IF-GREENHOLM-010, FR-GREENHOLM-010, FR-GREENHOLM-020, FR-GREENHOLM-030
import RealityKit
import XCTest
@testable import CrawlCall

@MainActor
final class CoverageTests: XCTestCase {
    /// Where a frame's corners meet the plane at `surface`, found from the camera
    /// entity: RealityKit's camera looks down its own -z, with y up and x right.
    private func corners(focus: SIMD3<Double>, pitch: Double, fieldOfView: Double, distance: Double,
                         aspect: Double, surface: Double) -> [SIMD2<Double>] {
        let camera = Entity()
        SceneView.place(camera, lookingAt: focus, pitchDegrees: pitch, distance: distance)
        let t = tan(fieldOfView * .pi / 360)
        var hits: [SIMD2<Double>] = []
        for (sx, sy) in [(-1.0, 1.0), (1, 1), (1, -1), (-1, -1)] {
            let local = SIMD3<Float>(Float(sx * aspect * t), Float(sy * t), -1)
            let ray = SIMD3<Double>(camera.orientation.act(local))
            let origin = SIMD3<Double>(camera.position)
            let along = (surface - origin.y) / ray.y
            XCTAssertGreaterThan(along, 0, "a corner ray looks above the horizon")
            let hit = origin + ray * along
            hits.append(SIMD2(hit.x, hit.z))
        }
        return hits
    }

    func testTheFootprintIsWhereTheGamesOwnCameraSeesTheGround() {
        for pitch in [50.0, 53.7, 55, 60] {
            for aspect in [0.5, 1, 2.174, 7.8] {
                for drop in [0.0, 3, 3.45] {
                    let formula = FrameCoverage.footprint(pitchDegrees: pitch, fieldOfViewDegrees: 50,
                                                          distance: 13.2, aspect: aspect, drop: drop)
                    let entity = corners(focus: .zero, pitch: pitch, fieldOfView: 50, distance: 13.2,
                                         aspect: aspect, surface: -drop)
                    guard let formula else { return XCTFail("no footprint at \(pitch)°") }
                    for (a, b) in zip(formula, entity) {
                        // Float, as RealityKit keeps a transform, over tens of metres.
                        XCTAssertEqual(a.x, b.x, accuracy: 1e-3, "pitch \(pitch), aspect \(aspect), drop \(drop)")
                        XCTAssertEqual(a.y, b.y, accuracy: 1e-3, "pitch \(pitch), aspect \(aspect), drop \(drop)")
                    }
                }
            }
        }
    }

    func testThePlansFigureForTheBlockoutIsReproduced() throws {
        // `materials/plans/surroundings.md` gives 11.2 m beyond and 5.7 m towards the
        // camera at 55 degrees on the phone's 2622 × 1206 screen, with the ground at the
        // point looked at; derived there by hand and independently of this code.
        let corners = try XCTUnwrap(FrameCoverage.footprint(pitchDegrees: 55, fieldOfViewDegrees: 50,
                                                            distance: 13.2, aspect: 2622.0 / 1206,
                                                            drop: 0))
        XCTAssertEqual(corners.map { -$0.y }.max()!, 11.2, accuracy: 0.05)
        XCTAssertEqual(corners.map(\.y).max()!, 5.7, accuracy: 0.05)
        XCTAssertEqual(corners.map { abs($0.x) }.max()!, 19.9, accuracy: 0.05)
    }

    func testEveryFrameOfTheRangeFallsInsideTheCoveredGround() throws {
        let world = try Launch.world().get()
        let widest = 7.8
        let camera = CameraRange(view: world.configurations.view, plan: world.plan, widestAspect: widest)
        let arena = world.plan.bounds
        let surface = arena.lowest.y - 0.35
        let covered = try XCTUnwrap(FrameCoverage.covered(arena: arena, camera: camera, surface: surface))
        // Pitches between the ones the reach is computed at, and the ends.
        let pitches = [50.0, 50.13, 52.61, 55, 57.77, 59.94, 60]
        let xs = [arena.lowest.x, arena.centre.x, arena.highest.x]
        let zs = [arena.lowest.z, arena.centre.z, arena.highest.z]
        let ys = [arena.lowest.y, 0, 3, arena.highest.y]
        for pitch in pitches {
            for aspect in [0.4, 1, 2.174, widest] {
                for x in xs { for z in zs { for y in ys {
                    for hit in corners(focus: SIMD3(x, y, z), pitch: pitch, fieldOfView: camera.fieldOfView,
                                       distance: camera.distance, aspect: aspect, surface: surface) {
                        XCTAssertTrue(covered.contains(hit),
                                      "pitch \(pitch), aspect \(aspect), focus \(x),\(y),\(z): \(hit) outside")
                    }
                } } }
            }
        }
    }

    func testTheCoveredGroundIsNoLargerThanTheSlackBeyondTheWidestFrame() throws {
        // Negation of the above: a rectangle that is the reach itself, less a metre
        // of slack and a little more, misses some corner. So the check is not passing
        // because the rectangle is merely enormous.
        let world = try Launch.world().get()
        let camera = CameraRange(view: world.configurations.view, plan: world.plan, widestAspect: 2.174)
        let arena = world.plan.bounds
        let covered = try XCTUnwrap(FrameCoverage.covered(arena: arena, camera: camera, surface: arena.lowest.y))
        let tight = covered.grown(by: -Coverage.slack - 0.05)
        let far = corners(focus: SIMD3(arena.lowest.x, arena.highest.y, arena.lowest.z), pitch: 50,
                          fieldOfView: camera.fieldOfView, distance: camera.distance, aspect: 2.174,
                          surface: arena.lowest.y)
        XCTAssertFalse(far.allSatisfy(tight.contains))
    }

    func testAWiderFrameNeedsMoreGroundAcrossAndNoMoreInDepth() throws {
        let narrow = try XCTUnwrap(FrameCoverage.reach(of: CameraRange(pitches: 50...60, fieldOfView: 50,
                                                                       distance: 13.2, widestAspect: 1),
                                                       drops: 0...3))
        let wide = try XCTUnwrap(FrameCoverage.reach(of: CameraRange(pitches: 50...60, fieldOfView: 50,
                                                                     distance: 13.2, widestAspect: 4),
                                                     drops: 0...3))
        XCTAssertGreaterThan(wide.across, narrow.across * 3.9)
        XCTAssertEqual(wide.beyond, narrow.beyond, accuracy: 1e-9)
        XCTAssertEqual(wide.toward, narrow.toward, accuracy: 1e-9)
    }

    func testACameraThatSeesTheHorizonStopsTheLaunch() throws {
        var view = try Launch.world().get().configurations.view
        XCTAssertNoThrow(try FrameCoverage.requireGroundInFrame(view: view))
        view = try replacing(view, fieldOfView: 101)
        XCTAssertThrowsError(try FrameCoverage.requireGroundInFrame(view: view)) { error in
            XCTAssertEqual(error as? CoverageError, .horizonInFrame(fieldOfView: 101, lowestPitch: 50))
            XCTAssertTrue(String(describing: error).hasPrefix("SETTING_HORIZON_IN_FRAME: "))
        }
        // 99 degrees leaves the top edge half a degree below the horizon at 50.
        view = try replacing(view, fieldOfView: 99)
        XCTAssertNoThrow(try FrameCoverage.requireGroundInFrame(view: view))
    }

    private func replacing(_ view: ViewConfiguration, fieldOfView: Double) throws -> ViewConfiguration {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "view", withExtension: "json", subdirectory: "config"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        json["cameraFieldOfView"] = fieldOfView
        return try JSONDecoder().decode(ViewConfiguration.self, from: JSONSerialization.data(withJSONObject: json))
    }

    // MARK: what stands in front of the arena

    /// Whether a segment passes through a box: the slab test.
    private func crosses(from a: SIMD3<Double>, to b: SIMD3<Double>,
                         low: SIMD3<Double>, high: SIMD3<Double>) -> Bool {
        var enter = 0.0, leave = 1.0
        let d = b - a
        for axis in 0..<3 {
            if abs(d[axis]) < 1e-12 {
                if a[axis] < low[axis] || a[axis] > high[axis] { return false }
                continue
            }
            var t0 = (low[axis] - a[axis]) / d[axis]
            var t1 = (high[axis] - a[axis]) / d[axis]
            if t0 > t1 { swap(&t0, &t1) }
            enter = max(enter, t0); leave = min(leave, t1)
            if enter > leave { return false }
        }
        return true
    }

    func testSomethingAsTallAsAllowedInFrontHidesNoPartOfTheArena() throws {
        let world = try Launch.world().get()
        let camera = CameraRange(view: world.configurations.view, plan: world.plan, widestAspect: 2.174)
        let arena = world.plan.bounds
        for gap in [0.3, 1, 2.4] {
            let allowed = FrameCoverage.tallestInFront(gap: gap, camera: camera)
            let ground = world.plan.underside
            let low = SIMD3(arena.centre.x - 0.5, ground, arena.highest.z + gap)
            let high = SIMD3(arena.centre.x + 0.5, ground + allowed - 1e-6, arena.highest.z + gap + 1)
            for pitch in [50.0, 55, 60] {
                for fz in stride(from: arena.lowest.z, through: arena.highest.z, by: 0.5) {
                    for fy in [ground, 0, 3] {
                        let focus = SIMD3(arena.centre.x, fy, fz)
                        let cam = Entity()
                        SceneView.place(cam, lookingAt: focus, pitchDegrees: pitch, distance: camera.distance)
                        let eye = SIMD3<Double>(cam.position)
                        for pz in stride(from: arena.lowest.z, through: arena.highest.z, by: 0.25) {
                            let p = SIMD3(arena.centre.x, ground, pz)
                            XCTAssertFalse(crosses(from: eye, to: p, low: low, high: high),
                                           "gap \(gap), pitch \(pitch), focus z \(fz) y \(fy), point z \(pz)")
                        }
                    }
                }
            }
        }
    }

    func testSomethingTallerThanAllowedInFrontHidesTheArenasEdge() throws {
        // Negation: a tenth taller, the camera looking at the near edge from the lowest
        // pitch sees the edge through it.
        let world = try Launch.world().get()
        let camera = CameraRange(view: world.configurations.view, plan: world.plan, widestAspect: 2.174)
        let arena = world.plan.bounds
        let gap = 1.0
        let ground = world.plan.underside
        let allowed = FrameCoverage.tallestInFront(gap: gap, camera: camera) * 1.1
        let low = SIMD3(arena.centre.x - 0.5, ground, arena.highest.z + gap)
        let high = SIMD3(arena.centre.x + 0.5, ground + allowed, arena.highest.z + gap + 1)
        let cam = Entity()
        SceneView.place(cam, lookingAt: SIMD3(arena.centre.x, ground, arena.highest.z),
                        pitchDegrees: 50, distance: camera.distance)
        let edge = SIMD3(arena.centre.x, ground, arena.highest.z)
        XCTAssertTrue(crosses(from: SIMD3<Double>(cam.position), to: edge, low: low, high: high))
    }
}

@MainActor
final class GreenholmTests: XCTestCase {
    private func world() throws -> World { try Launch.world().get() }

    private func scenery(widest: Double = 2.174) throws -> (Scenery, World, CameraRange) {
        let world = try world()
        let camera = CameraRange(view: world.configurations.view, plan: world.plan, widestAspect: widest)
        return (try world.setting.scenery(around: world.plan, camera: camera), world, camera)
    }

    private func configuration(_ world: World) throws -> GreenholmConfiguration {
        guard case .greenholm(let c) = world.setting else { throw XCTSkip("the shipped map is not on Greenholm") }
        return c
    }

    // MARK: FR-MAP-120, IF-GREENHOLM-010

    func testTheShippedMapStandsOnGreenholmWithItsConfiguration() throws {
        let world = try world()
        let c = try configuration(world)
        XCTAssertGreaterThan(c.islandMargin, 0)
        XCTAssertGreaterThan(c.birdInterval, 0)
        XCTAssertFalse(c.treeScales.isEmpty)
    }

    func testASettingTheGameDoesNotProvideIsRefusedByName() {
        XCTAssertThrowsError(try Setting.load(named: "atlantis", from: .main)) { error in
            XCTAssertEqual(error as? SettingError, .unknown(name: "atlantis"))
            XCTAssertEqual(String(describing: error),
                           "SETTING_UNKNOWN: the map names the setting 'atlantis', and the game provides greenholm")
        }
    }

    func testAMapOnAnUnknownSettingDoesNotLaunch() throws {
        // The whole path: a map naming a setting nobody provides is read to the end
        // and refused, not played on nothing.
        let kit = try Kit.load(named: "blockout", from: .main)
        let map = try MapParser.parse("kit blockout\nsetting atlantis\nfloor 0\n..\n", kit: kit)
        XCTAssertThrowsError(try Setting.load(named: map.setting, from: .main))
    }

    /// A bundle of the shipped `config/` and `maps/`, with one map added and one
    /// configuration changed, so that the launch itself can be run on it.
    private func bundle(map: String, text: String, view change: ((inout [String: Any]) -> Void)? = nil) throws -> Bundle {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let main = try XCTUnwrap(Bundle.main.resourceURL)
        for directory in ["config", "maps"] {
            try FileManager.default.copyItem(at: main.appendingPathComponent(directory),
                                             to: root.appendingPathComponent(directory))
        }
        try text.write(to: root.appendingPathComponent("maps/\(map).map"), atomically: true, encoding: .utf8)
        if let change {
            let url = root.appendingPathComponent("config/view.json")
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            change(&json)
            try JSONSerialization.data(withJSONObject: json).write(to: url)
        }
        return try XCTUnwrap(Bundle(url: root))
    }

    func testTheLaunchRefusesAMapOnASettingTheGameDoesNotProvide() throws {
        let b = try bundle(map: "atlantis", text: "kit blockout\nsetting atlantis\nfloor 0\n..\n")
        switch Launch.world(from: b, map: "atlantis") {
        case .success: XCTFail("a map on a setting nobody provides must not start")
        case .failure(let error): XCTAssertEqual(error as? SettingError, .unknown(name: "atlantis"))
        }
        // And the same bundle starts a map on Greenholm, so the refusal is the setting's.
        let good = try bundle(map: "small", text: "kit blockout\nsetting greenholm\nfloor 0\n..\n")
        XCTAssertNoThrow(try Launch.world(from: good, map: "small").get())
    }

    func testTheLaunchRefusesACameraThatSeesTheHorizon() throws {
        let b = try bundle(map: "small", text: "kit blockout\nsetting greenholm\nfloor 0\n..\n") {
            $0["cameraFieldOfView"] = 110
        }
        switch Launch.world(from: b, map: "small") {
        case .success: XCTFail("a camera that sees the horizon must not start a match")
        case .failure(let error):
            XCTAssertEqual(error as? CoverageError, .horizonInFrame(fieldOfView: 110, lowestPitch: 50))
        }
    }

    func testTheConfigurationRefusesAKeyItDoesNotKnow() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "greenholm", withExtension: "json",
                                                subdirectory: "config/setting"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        json["treeHieght"] = 3
        let data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try Configurations.decode(GreenholmConfiguration.self, named: "setting/greenholm",
                                                       schema: GreenholmConfiguration.schema, from: data)) { error in
            XCTAssertTrue(String(describing: error).hasPrefix("CONFIG_BAD_SHAPE: config/setting/greenholm.json"),
                          String(describing: error))
        }
        json.removeValue(forKey: "treeHieght")
        json.removeValue(forKey: "waterColour")
        XCTAssertThrowsError(try Configurations.decode(GreenholmConfiguration.self, named: "setting/greenholm",
                                                       schema: GreenholmConfiguration.schema,
                                                       from: JSONSerialization.data(withJSONObject: json)))
    }

    // MARK: FR-MAP-130 — scenery takes no part in play

    func testTheSettingChangesNothingOfTheArena() throws {
        // The same grids on two settings: the same pieces, the same graph.
        let kit = try Kit.load(named: "blockout", from: .main)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "blockout", withExtension: "map", subdirectory: "maps"))
        let text = try String(contentsOf: url, encoding: .utf8)
        let elsewhere = text.replacingOccurrences(of: "setting greenholm", with: "setting elsewhere")
        XCTAssertNotEqual(text, elsewhere)
        let a = try MapParser.parse(text, kit: kit)
        let b = try MapParser.parse(elsewhere, kit: kit)
        XCTAssertEqual(ScenePlan.make(map: a, kit: kit, cellSize: 0.5), ScenePlan.make(map: b, kit: kit, cellSize: 0.5))
        XCTAssertEqual(NavigationGraph.derive(from: a, stepHeight: ShippedTuning.stepHeight).nodes, NavigationGraph.derive(from: b, stepHeight: ShippedTuning.stepHeight).nodes)
    }

    func testTheSceneryJoinsNeitherTheMapNorWhatIsCutOpen() throws {
        let world = try world()
        let built = SceneBuilder.scene(for: world.plan, view: world.configurations.view)
        let map = try XCTUnwrap(built.root.children.first { $0.name == EntityName.map })
        let before = map.children.count
        let result = SceneryBuilder.world(for: world, widestAspect: 2.174, in: built.root)
        let scenery = try XCTUnwrap(built.root.children.first { $0.name == EntityName.scenery })
        XCTAssertGreaterThan(scenery.children.count, 0)
        XCTAssertEqual(map.children.count, before)
        // What is cut open is judged over the map's modules alone: one per piece.
        XCTAssertEqual(map.children.count, world.plan.pieces.filter { $0.size.min() > 0 }.count)
        XCTAssertFalse(scenery.children.contains { $0.parent === map })
        XCTAssertNotNil(result.sky)
        XCTAssertNotNil(result.flock)
    }

    func testNoPartStandsOverTheArena() throws {
        let (s, world, _) = try scenery()
        let arena = world.plan.bounds
        for part in s.parts where part.layer == .rim {
            let overX = part.highest.x > arena.lowest.x && part.lowest.x < arena.highest.x
            let overZ = part.highest.z > arena.lowest.z && part.lowest.z < arena.highest.z
            XCTAssertFalse(overX && overZ, "\(part.shape) at \(part.centre) stands over the arena")
        }
        // And the ground and water lie below it.
        for part in s.parts where part.layer != .rim {
            XCTAssertLessThanOrEqual(part.top, world.plan.underside + 1e-9)
        }
    }

    func testWhatStandsInFrontIsNoTallerThanAllowed() throws {
        let (s, world, camera) = try scenery()
        let arena = world.plan.bounds
        var inFront = 0
        for part in s.parts where part.layer == .rim
            && part.highest.x > arena.lowest.x && part.lowest.x < arena.highest.x && part.lowest.z >= arena.highest.z {
            inFront += 1
            let allowed = FrameCoverage.tallestInFront(gap: part.lowest.z - arena.highest.z, camera: camera)
            XCTAssertLessThanOrEqual(part.top - world.plan.underside, allowed + 1e-9, "\(part.shape) at \(part.centre)")
        }
        XCTAssertGreaterThan(inFront, 0, "nothing stands in front, so this checked nothing")
    }

    func testTreesInFrontAreLeftForShrubs() throws {
        // The rule changes what is placed: without a camera to answer to — a range whose
        // lowest pitch is nearly straight down — the front of the ring has cones.
        let world = try world()
        let c = try configuration(world)
        let arena = world.plan.bounds
        let steep = CameraRange(pitches: 89...89.5, fieldOfView: 50, distance: 13.2, widestAspect: 2.174)
        let usual = CameraRange(view: world.configurations.view, plan: world.plan, widestAspect: 2.174)
        func conesInFront(_ camera: CameraRange) throws -> Int {
            try Greenholm.scenery(around: world.plan, camera: camera, configuration: c).parts.filter {
                $0.shape == .cone && $0.highest.x > arena.lowest.x && $0.lowest.x < arena.highest.x
                    && $0.lowest.z >= arena.highest.z
            }.count
        }
        XCTAssertGreaterThan(try conesInFront(steep), 0)
        XCTAssertEqual(try conesInFront(usual), 0)
    }

    func testTheIslandIsLaidUnderTheLowestFloorAndNotUnderASunkenModule() throws {
        // A walkable module taller than the floor slab hangs below the surface it makes
        // — as the blockout's old stair did, three metres down; the island is laid at
        // the floor's underside, a slab below the surface, not at the module's foot.
        let kit = try Kit.load(named: "blockout", from: .main)
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n./\n", kit: kit)
        let plan = ScenePlan.make(map: map, kit: kit, cellSize: 0.5)
        let slab = try XCTUnwrap(kit.floor).size[1]
        let sunk = try XCTUnwrap(kit.module(for: "/")).size[1]
        XCTAssertGreaterThan(sunk, slab, "the kit changed: its '/' is no deeper than a floor slab")
        XCTAssertEqual(plan.bounds.lowest.y, -sunk, accuracy: 1e-9)
        XCTAssertEqual(plan.underside, -slab, accuracy: 1e-9)
        XCTAssertEqual(try world().plan.underside, -slab, accuracy: 1e-9)
        let empty = ScenePlan(pieces: [], cellSize: 0.5, floorHeight: 3)
        XCTAssertEqual(empty.underside, 0)
    }

    // MARK: FR-MAP-140 — the water reaches all the camera can show

    func testTheWaterReachesEveryPartOfTheCoveredGround() throws {
        for widest in [2.174, 7.8] {
            let (s, world, camera) = try scenery(widest: widest)
            let water = try XCTUnwrap(s.parts.first { $0.layer == .water })
            let expected = try XCTUnwrap(FrameCoverage.covered(arena: world.plan.bounds, camera: camera,
                                                               surface: s.surface))
            let reach = GroundRect(lowest: SIMD2(water.lowest.x, water.lowest.z),
                                   highest: SIMD2(water.highest.x, water.highest.z))
            // The water's box is its centre and size, so its edges come back through
            // arithmetic: compared with a tolerance, not exactly.
            XCTAssertTrue(reach.grown(by: 1e-9).contains(expected))
            XCTAssertFalse(reach.grown(by: -1e-6).contains(expected), "the water is sized to the ground, not beyond it")
            XCTAssertEqual(water.top, s.surface, accuracy: 1e-9)
            // Nothing the scenery offers lies lower than the water.
            for part in s.parts { XCTAssertGreaterThanOrEqual(part.lowest.y, s.surface - 1e-9 - IslandShape.submerged
                                                                - IslandShape.waterDepth) }
        }
    }

    // MARK: FR-GREENHOLM-030 — birds over the arena, as the camera sees them

    func testEveryFlightIsSeenCrossingNearWhereTheCameraLooks() throws {
        // Where the line from the shipped camera through a bird meets the floor: within
        // half the arena's depth of the point looked at, for every line a flight takes
        // and wherever the camera looks. Found from the camera entity the game places.
        let (s, world, camera) = try scenery()
        let birds = try XCTUnwrap(s.birds)
        let arena = world.plan.bounds
        let ground = world.plan.underside
        var offsets: [Double] = []
        for fz in [arena.lowest.z, arena.centre.z, arena.highest.z] {
            for number in 0..<40 {
                let bird = birds.flight(number, lookingAt: SIMD3(arena.centre.x, ground, fz), aspect: 2.174).from
                let cam = Entity()
                SceneView.place(cam, lookingAt: SIMD3(bird.x, ground, fz), pitchDegrees: camera.pitch,
                                distance: camera.distance)
                let eye = SIMD3<Double>(cam.position)
                let seen = eye + (bird - eye) * ((ground - eye.y) / (bird.y - eye.y))
                offsets.append(seen.z - fz)
                XCTAssertLessThanOrEqual(abs(seen.z - fz), arena.extent.z / 2 + 1e-6, "flight \(number), focus \(fz)")
            }
        }
        // And they are spread, not all on one line.
        XCTAssertGreaterThan(offsets.max()! - offsets.min()!, arena.extent.z / 2)
    }

    func testAFlightStartsAndEndsOutOfFrameAndCrossesItsMiddleOnAnyWindow() throws {
        // On the device's own camera, placed by the game: a flight's ends are outside
        // the frame at their depth, and its middle is inside, whatever the window's
        // shape — the iPad's widest included, where the water reaches far further than
        // any flight could fly in one interval.
        for widest in [2.174, 7.8] {
            let (s, world, camera) = try scenery(widest: widest)
            let birds = try XCTUnwrap(s.birds)
            let arena = world.plan.bounds
            let t = tan(camera.fieldOfView * .pi / 360)
            for aspect in [0.75, 1.33, 2.174, widest] {
                for focus in [SIMD3(arena.lowest.x, world.plan.underside + 0.1, arena.lowest.z), arena.centre,
                              SIMD3(arena.highest.x, 0, arena.highest.z)] {
                    let cam = Entity()
                    SceneView.place(cam, lookingAt: focus, pitchDegrees: camera.pitch, distance: camera.distance)
                    func inFrame(_ p: SIMD3<Double>) -> Bool {
                        let local = SIMD3<Double>(cam.orientation.inverse.act(SIMD3<Float>(p - SIMD3<Double>(cam.position))))
                        let depth = -local.z
                        return depth > 0 && abs(local.x) <= depth * aspect * t && abs(local.y) <= depth * t
                    }
                    for number in 0..<12 {
                        let f = birds.flight(number, lookingAt: focus, aspect: aspect)
                        XCTAssertFalse(inFrame(f.from), "flight \(number) starts in frame, aspect \(aspect)")
                        XCTAssertFalse(inFrame(f.to), "flight \(number) ends in frame, aspect \(aspect)")
                        let middle = (f.from + f.to) / 2
                        XCTAssertTrue(inFrame(middle), "flight \(number) never crosses the frame, aspect \(aspect)")
                        // And it gets there within its interval.
                        XCTAssertLessThan(simd_distance(f.from, middle) / birds.speed, f.lasts)
                    }
                }
            }
        }
    }

    // MARK: FR-GREENHOLM-010 — what the island is made of

    func testTheIslandIsGrassOnAShoreRingedByTreesAndShrubs() throws {
        let (s, world, _) = try scenery()
        let c = try configuration(world)
        let ground = s.parts.filter { $0.layer == .ground }
        XCTAssertEqual(ground.count, 2)
        let grass = try XCTUnwrap(ground.first { $0.colour == c.grassColour.rgb })
        let shore = try XCTUnwrap(ground.first { $0.colour == c.shoreColour.rgb })
        XCTAssertEqual(grass.top, world.plan.underside, accuracy: 1e-9)
        XCTAssertEqual(shore.top, grass.top - c.shoreDrop, accuracy: 1e-9)
        XCTAssertEqual(shore.size.x - grass.size.x, 2 * c.shoreWidth, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(s.parts.filter { $0.shape == .cone }.count, IslandShape.fewestRimTrees / 2)
        XCTAssertGreaterThan(s.parts.filter { $0.shape == .sphere }.count, 0)
        XCTAssertEqual(s.sky, Scenery.Sky(zenith: c.skyZenithColour.rgb, horizon: c.skyHorizonColour.rgb))
    }

    func testEveryPartIsBuiltAndLitAndShapesAreShared() throws {
        let (s, world, _) = try scenery()
        let built = SceneBuilder.scene(for: world.plan, view: world.configurations.view)
        let ambient = try XCTUnwrap(built.root.children.first { $0.name == EntityName.ambient })
        let root = SceneryBuilder.entity(for: s, ambient: ambient)
        let models = root.children.compactMap { $0 as? ModelEntity }
        XCTAssertEqual(models.count, s.parts.count)
        XCTAssertTrue(models.allSatisfy { $0.components.has(ImageBasedLightReceiverComponent.self) })
        let meshes = Set(models.compactMap { $0.model.map { ObjectIdentifier($0.mesh) } })
        XCTAssertLessThanOrEqual(meshes.count, Scenery.Part.Shape.allCases.count)
        for (model, part) in zip(models, s.parts) {
            XCTAssertEqual(SIMD3<Double>(model.scale), part.size, accuracy: 1e-5)
        }
    }

    func testTheSkyIsZenithAboveAndHorizonBelow() throws {
        let sky = Scenery.Sky(zenith: SIMD3(0, 0, 1), horizon: SIMD3(1, 1, 1))
        let image = try XCTUnwrap(SceneryBuilder.skyImage(sky))
        XCTAssertEqual(image.width, image.height * 2)
        let data = try XCTUnwrap(image.dataProvider?.data as Data?)
        func pixel(row: Int) -> SIMD3<Double> {
            let offset = row * image.bytesPerRow
            return SIMD3(Double(data[offset]), Double(data[offset + 1]), Double(data[offset + 2])) / 255
        }
        XCTAssertEqual(pixel(row: 0), SIMD3(0, 0, 1), accuracy: 0.03)
        XCTAssertEqual(pixel(row: image.height - 1), SIMD3(1, 1, 1), accuracy: 0.01)
        XCTAssertEqual(pixel(row: image.height * 3 / 4), SIMD3(1, 1, 1), accuracy: 0.01)
        XCTAssertNoThrow(try SceneryBuilder.skyResource(sky))
    }
}

final class BirdsTests: XCTestCase {
    private let birds = Birds(interval: 10, count: 3, speed: 5, size: 0.4, wingbeats: 2, colour: SIMD3(1, 1, 1),
                              height: 6, camera: BirdsTests.camera, seen: 4)
    private static let camera = CameraRange(pitches: 50...60, fieldOfView: 50, distance: 13.2,
                                            widestAspect: 2, pitch: 55)
    /// Half a flight's length, as the schedule lays it out looking at x = 5 through a
    /// frame twice as wide as tall; where that is out of frame is GreenholmTests'.
    private var half: Double {
        let f = birds.flight(0, lookingAt: SIMD3(5, 0, 3), aspect: 2)
        return (f.to.x - f.from.x) / 2
    }

    func testNoFlightBeforeTheFirstIntervalOrAfterItsEnd() throws {
        XCTAssertNil(birds.number(at: 0))
        XCTAssertNil(birds.number(at: 9.99))
        XCTAssertEqual(birds.number(at: 10), 0)
        XCTAssertEqual(birds.number(at: 25), 1)
        let first = birds.flight(0, lookingAt: SIMD3(5, 0, 3), aspect: 2)
        XCTAssertEqual(first.lasts, min((2 * half + birds.trail) / 5, 10), accuracy: 1e-9)
        XCTAssertNotNil(birds.flock(at: 10, on: first))
        XCTAssertNil(birds.flock(at: 9.9, on: first))
        let slow = Birds(interval: 30, count: 3, speed: 5, size: 0.4, wingbeats: 2, colour: .zero, height: 6,
                         camera: BirdsTests.camera, seen: 4)
        let long = slow.flight(0, lookingAt: SIMD3(5, 0, 3), aspect: 2)
        XCTAssertEqual(long.lasts, (2 * half + slow.trail) / 5, accuracy: 1e-9)
        XCTAssertNil(slow.flock(at: 30 + long.lasts + 0.01, on: long))
    }

    func testNoIntervalMeansNoFlights() {
        let never = Birds(interval: 0, count: 3, speed: 5, size: 0.4, wingbeats: 2, colour: .zero, height: 6,
                          camera: BirdsTests.camera, seen: 4)
        XCTAssertNil(never.number(at: 0))
        XCTAssertNil(never.number(at: 100))
    }

    func testAWiderFrameStartsAFlightFurtherOut() {
        let narrow = birds.flight(0, lookingAt: SIMD3(5, 0, 3), aspect: 1)
        let wide = birds.flight(0, lookingAt: SIMD3(5, 0, 3), aspect: 3)
        let n = (narrow.to.x - narrow.from.x) / 2, w = (wide.to.x - wide.from.x) / 2
        let wing = 0.4 * BirdShape.wingSpan * 2
        // What lies beyond the frame is the same wingspan; the frame is three times as wide.
        XCTAssertEqual(w - wing, (n - wing) * 3, accuracy: 1e-9)
        XCTAssertGreaterThan(n, wing)
    }

    func testAFlightCrossesFromOutsideTheFrameToOutsideTheOtherSide() {
        let first = birds.flight(0, lookingAt: SIMD3(5, 0, 3), aspect: 2)
        XCTAssertEqual(first.from.x, 5 - half, accuracy: 1e-9)
        XCTAssertEqual(first.to.x, 5 + half, accuracy: 1e-9)
        let second = birds.flight(1, lookingAt: SIMD3(5, 0, 3), aspect: 2)
        XCTAssertEqual(second.from.x, 5 + half, accuracy: 1e-9, "the next flight comes back the other way")
        XCTAssertEqual(second.to.x, 5 - half, accuracy: 1e-9)
        for n in 0..<50 {
            let f = birds.flight(n, lookingAt: SIMD3(5, 0, 3), aspect: 2)
            // In front of the point looked at, by the lift, give or take the spread.
            let lift = 6 / tan(55 * Double.pi / 180)
            XCTAssertTrue((3 + lift - 4 ... 3 + lift + 4).contains(f.from.z), "line \(f.from.z)")
            XCTAssertEqual(f.from.z, f.to.z)
            XCTAssertEqual(f.from.y, 6)
        }
        XCTAssertNotEqual(birds.flight(0, lookingAt: SIMD3(5, 0, 3), aspect: 2).from.z, birds.flight(1, lookingAt: SIMD3(5, 0, 3), aspect: 2).from.z)
        XCTAssertEqual(birds.flight(0, lookingAt: SIMD3(5, 0, 5), aspect: 2).from.z
                       - birds.flight(0, lookingAt: SIMD3(5, 0, 3), aspect: 2).from.z, 2, accuracy: 1e-9)
        // Looking from a floor higher, the line is nearer the point: the flock is lower
        // above it, so it is seen less far off.
        XCTAssertLessThan(birds.flight(0, lookingAt: SIMD3(5, 3, 3), aspect: 2).from.z,
                          birds.flight(0, lookingAt: SIMD3(5, 0, 3), aspect: 2).from.z)
    }

    func testTheFlockFliesInAVBehindItsLeader() throws {
        let flight = birds.flight(0, lookingAt: SIMD3(5, 0, 3), aspect: 2)
        let now = try XCTUnwrap(birds.flock(at: 12, on: flight))
        XCTAssertEqual(now.positions.count, 3)
        XCTAssertEqual(now.heading, SIMD3(1, 0, 0), accuracy: 1e-12)
        let leader = now.positions[0]
        XCTAssertEqual(leader.x, 5 - half + 2 * 5, accuracy: 1e-9)
        let left = now.positions[1], right = now.positions[2]
        XCTAssertEqual(left.x, right.x, accuracy: 1e-9)
        XCTAssertLessThan(left.x, leader.x)
        XCTAssertEqual(left.z - leader.z, -(right.z - leader.z), accuracy: 1e-9)
        XCTAssertNotEqual(left.z, leader.z)
    }

    func testWingsBeatWithinTheirSwing() {
        let angles = stride(from: 0.0, through: 3, by: 0.01).map(birds.wing(at:))
        XCTAssertLessThanOrEqual(angles.map(abs).max()!, BirdShape.flapDegrees + 1e-9)
        XCTAssertGreaterThan(angles.max()!, BirdShape.flapDegrees * 0.99)
        XCTAssertLessThan(angles.min()!, -BirdShape.flapDegrees * 0.99)
    }

    @MainActor
    func testTheFlockIsShownOnlyWhileItFliesAndKeepsItsLineWhileTheCameraMoves() throws {
        let flock = SceneryBuilder.flock(birds, ambient: Entity())
        let pilot = SceneryBuilder.Pilot()
        XCTAssertEqual(flock.children.count, 3)
        XCTAssertTrue(flock.children.allSatisfy { !$0.isEnabled })
        SceneryBuilder.move(flock, birds, at: 12, lookingAt: SIMD3(5, 0, 3), aspect: 2, pilot: pilot)
        XCTAssertTrue(flock.children.allSatisfy(\.isEnabled))
        XCTAssertEqual(Double(flock.children[0].position.x), 5 - half + 10, accuracy: 1e-4)
        let line = flock.children[0].position.z
        SceneryBuilder.move(flock, birds, at: 13, lookingAt: SIMD3(5, 0, 9), aspect: 2, pilot: pilot)
        XCTAssertEqual(flock.children[0].position.z, line, accuracy: 1e-5, "a flight keeps its line")
        SceneryBuilder.move(flock, birds, at: 21, lookingAt: SIMD3(5, 0, 9), aspect: 2, pilot: pilot)
        XCTAssertEqual(Double(flock.children[0].position.z),
                       birds.flight(1, lookingAt: SIMD3(5, 0, 9), aspect: 2).from.z, accuracy: 1e-4, "the next one takes a new line")
        SceneryBuilder.move(flock, birds, at: 5, lookingAt: SIMD3(5, 0, 3), aspect: 2, pilot: pilot)
        XCTAssertTrue(flock.children.allSatisfy { !$0.isEnabled })
    }
}

final class WidestFrameTests: XCTestCase {
    func testThePhonesWidestFrameIsItsScreenAndTheIPadsAsShortAsTheControls() {
        XCTAssertEqual(GameWindow.widestAspect(screen: CGSize(width: 402, height: 874), resizable: false),
                       874.0 / 402, accuracy: 1e-9)
        XCTAssertEqual(GameWindow.widestAspect(screen: CGSize(width: 1032, height: 1376), resizable: true),
                       1376 / Double(GameWindow.minimumSize.height), accuracy: 1e-9)
        XCTAssertEqual(GameWindow.widestAspect(screen: .zero, resizable: false), 1)
    }

    @MainActor
    func testTheSuitesOwnSceneIsNoWiderThanItsDevicesWidestFrame() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let delegate = try XCTUnwrap(scene.delegate as? SceneDelegate)
        let size = scene.effectiveGeometry.coordinateSpace.bounds.size
        XCTAssertGreaterThan(delegate.host.widestAspect + 1e-9, Double(size.width / size.height))
        XCTAssertEqual(delegate.host.widestAspect,
                       GameWindow.widestAspect(screen: scene.screen.bounds.size,
                                               resizable: scene.sizeRestrictions != nil), accuracy: 1e-9)
    }
}

private func XCTAssertEqual(_ a: SIMD3<Double>, _ b: SIMD3<Double>, accuracy: Double,
                            file: StaticString = #filePath, line: UInt = #line) {
    for i in 0..<3 { XCTAssertEqual(a[i], b[i], accuracy: accuracy, "component \(i)", file: file, line: line) }
}
