// What the player sees through: a floor above the head (FR-VIEW-140) and whatever
// stands between the camera and the snake (FR-VIEW-150), from the floor a piece is
// placed on, the line test itself, the switch, and the four together over the real
// blockout.
//
// verifies: FR-VIEW-140, FR-VIEW-150, FR-VIEW-155
import RealityKit
import XCTest
@testable import CrawlCall

@MainActor
final class SeeThroughTests: XCTestCase {
    private func world() throws -> World { try Launch.world().get() }

    /// Two modules of the same size, one on each floor, standing apart so that only
    /// the rule under test can make either of them see-through.
    private func twoFloors() -> (below: ModelEntity, above: ModelEntity, seeThrough: SeeThrough) {
        let mesh = MeshResource.generateBox(size: 1)
        let colour = SIMD3<Double>(0.5, 0.5, 0.5)
        let below = ModelEntity(mesh: mesh, materials: [SeeThrough.solid(colour: colour)])
        let above = ModelEntity(mesh: mesh, materials: [SeeThrough.solid(colour: colour)])
        below.name = "below"
        above.name = "above"
        let modules = [
            SeeThrough.Module(model: below, level: 0,
                              centre: SIMD3(0, 0, 0), size: SIMD3(1, 1, 1),
                              solid: [SeeThrough.solid(colour: colour)],
                              clear: [SeeThrough.clear(colour: colour)]),
            SeeThrough.Module(model: above, level: 1,
                              centre: SIMD3(0, 3, 0), size: SIMD3(1, 1, 1),
                              solid: [SeeThrough.solid(colour: colour)],
                              clear: [SeeThrough.clear(colour: colour)]),
        ]
        return (below, above, SeeThrough(modules))
    }

    private func look(of model: ModelEntity) throws -> PhysicallyBasedMaterial {
        try XCTUnwrap(model.model?.materials.first as? PhysicallyBasedMaterial)
    }

    func testTheFloorAboveTheHeadIsAFrameAndTheHeadsFloorStaysSolid() throws {
        let parts = twoFloors()
        let (below, above) = (parts.below, parts.above)
        var seeThrough = parts.seeThrough
        seeThrough.show(headOn: 0, snake: [], from: .zero, margin: 0)

        let lid = try look(of: above)
        XCTAssertNotEqual(lid.blending, .opaque, "the floor above the head is still solid")
        // A module that went on casting a solid shadow would darken the very floor it
        // was made see-through for.
        XCTAssertEqual(above.components[DynamicLightShadowComponent.self]?.castsShadow, false)

        let here = try look(of: below)
        XCTAssertEqual(here.blending, .opaque, "the head's own floor is see-through")
        XCTAssertNotEqual(below.components[DynamicLightShadowComponent.self]?.castsShadow, false)
    }

    func testOnTheUpperFloorNothingIsAFrame() throws {
        // The other direction, and the negation of the test above: standing on the
        // balcony, the balcony is solid again.
        let parts = twoFloors()
        let (below, above) = (parts.below, parts.above)
        var seeThrough = parts.seeThrough
        seeThrough.show(headOn: 0, snake: [], from: .zero, margin: 0)
        seeThrough.show(headOn: 1, snake: [], from: .zero, margin: 0)
        for model in [below, above] {
            let look = try look(of: model)
            XCTAssertEqual(look.blending, .opaque, "\(model.name) is see-through with the head above it")
            XCTAssertNotEqual(model.components[DynamicLightShadowComponent.self]?.castsShadow, false)
        }
    }

    func testEveryPieceCarriesTheFloorTheMapPlacedItOn() throws {
        let plan = try world().plan
        // The blockout is two floors, and nothing of it is placed anywhere else.
        XCTAssertEqual(Set(plan.pieces.map(\.level)), [0, 1])
        for piece in plan.pieces {
            // Whatever a module is for, it reaches its own floor's surface and does
            // not rise above it: a slab hangs its thickness below, a stair its whole
            // height, a wall stands on it and is sunk into it by the overlap.
            let base = piece.centre.y - piece.size.y / 2
            let surface = Double(piece.level) * plan.floorHeight
            XCTAssertLessThanOrEqual(base, surface + 1e-9, "\(piece.module) floats above floor \(piece.level)")
            XCTAssertGreaterThanOrEqual(base, surface - piece.size.y - 1e-9,
                                        "\(piece.module) hangs below floor \(piece.level)")
        }
    }

    func testTheWholeBalconyIsAFrameWhileTheSnakeIsUnderIt() throws {
        let world = try world()
        let built = SceneBuilder.entity(for: world.plan)
        var seeThrough = built.seeThrough
        seeThrough.show(headOn: 0, snake: [], from: .zero, margin: 0)

        // Counted rather than matched piece by piece: the plan says how many modules
        // stand above the ground floor, and exactly that many are drawn see-through.
        let expected = world.plan.pieces.filter { $0.level > 0 }.count
        let cleared = built.root.children
            .compactMap { ($0 as? ModelEntity)?.model?.materials.first as? PhysicallyBasedMaterial }
            .filter { $0.blending != .opaque }
        XCTAssertGreaterThan(expected, 0, "a one-floor map would pass this test for the wrong reason")
        XCTAssertEqual(cleared.count, expected)
        XCTAssertLessThan(cleared.count, built.root.children.count, "the whole map went see-through")
    }

    // MARK: what stands in the way (FR-VIEW-150)

    private let eye = SIMD3<Double>(0, 5, 5)

    func testABoxOnTheLineBetweenTheEyeAndTheSnakeBlocks() {
        XCTAssertTrue(SeeThrough.blocks(centre: SIMD3(0, 2, 2), size: SIMD3(1, 1, 1),
                                        from: eye, to: .zero, margin: 0.15))
    }

    func testABoxBesideTheLineDoesNot() {
        XCTAssertFalse(SeeThrough.blocks(centre: SIMD3(3, 2, 2), size: SIMD3(1, 1, 1),
                                         from: eye, to: .zero, margin: 0.15))
    }

    func testABoxBeyondTheSnakeOrBehindTheEyeDoesNot() {
        // The test is over the segment, not an endless ray: what is past either end
        // of it is not in the way, however well it lines up. The eye is level with
        // the snake here on purpose, so that it is the segment doing the work and
        // not the rule about what stands lower than the body.
        let level = SIMD3<Double>(0, 0, 5)
        XCTAssertFalse(SeeThrough.blocks(centre: SIMD3(0, 0, -2), size: SIMD3(1, 1, 1),
                                         from: level, to: .zero, margin: 0.15))
        XCTAssertFalse(SeeThrough.blocks(centre: SIMD3(0, 0, 7), size: SIMD3(1, 1, 1),
                                         from: level, to: .zero, margin: 0.15))
        // And the same box between the two is in the way, or the test above would
        // pass on a function that never says yes.
        XCTAssertTrue(SeeThrough.blocks(centre: SIMD3(0, 0, 2), size: SIMD3(1, 1, 1),
                                        from: level, to: .zero, margin: 0.15))
    }

    func testTheFloorASnakeStandsOnIsNotInItsWay() {
        // The head rests on the surface, so the slab it stands on touches the end of
        // the line and the margin reaches well into it. Nothing whose top is no
        // higher than the body can be between that body and a camera above it, and
        // without that rule every cell under the snake would go see-through and the
        // player would look through the floor into nothing.
        let slab = (centre: SIMD3<Double>(0, -0.05, 0), size: SIMD3<Double>(0.5, 0.1, 0.5))
        XCTAssertFalse(SeeThrough.blocks(centre: slab.centre, size: slab.size,
                                         from: eye, to: .zero, margin: 0.45))
        // The rule is about height, not about being underfoot: the same slab raised
        // to stand above the snake is in the way like anything else.
        XCTAssertTrue(SeeThrough.blocks(centre: SIMD3(0, 2, 2), size: slab.size,
                                        from: eye, to: .zero, margin: 0.45))
    }

    func testTheMarginIsWhatTurnsABodyIntoMoreThanAPoint() {
        // A box beside the line, missing it by a quarter of a metre: out of the way
        // for a point, in the way for a body of that size — which is what the snake
        // is, and what the fade has to start before.
        let beside = (centre: SIMD3<Double>(0.6, 2, 2), size: SIMD3<Double>(0.5, 1, 0.5))
        XCTAssertFalse(SeeThrough.blocks(centre: beside.centre, size: beside.size,
                                         from: eye, to: .zero, margin: 0))
        XCTAssertTrue(SeeThrough.blocks(centre: beside.centre, size: beside.size,
                                        from: eye, to: .zero, margin: 0.45))
    }

    func testTheReachIsADistanceAndNotACubeAroundTheBox() {
        // ADR-0019 point 3. A unit box at the origin and a line running the length of
        // one of its vertical edges, three tenths of a metre clear of it on each of
        // the two horizontal axes: the gap is 0.3 m along either axis on its own and
        // 0.424 m as a distance. A margin between the two tells the readings apart —
        // growing the box on every axis says the line is in the way, measuring the
        // distance says it is not, and the second is what the requirements ask for.
        let box = SIMD3<Double>(1, 1, 1)
        let eye = SIMD3<Double>(0.8, -5, 0.8)
        let point = SIMD3<Double>(0.8, 5, 0.8)
        XCTAssertFalse(SeeThrough.blocks(centre: .zero, size: box,
                                         from: eye, to: point, margin: 0.35))
        // Past the distance, it is in the way again — or the assertion above would
        // pass on a rule that had stopped saying yes.
        XCTAssertTrue(SeeThrough.blocks(centre: .zero, size: box,
                                        from: eye, to: point, margin: 0.45))
    }

    func testWithNoMarginTheAnswerIsWhetherTheLineCutsTheBoxAtAll() {
        // The bots pass no margin (ADR-0019 point 4), so measuring the distance must
        // not have moved their eyes: with nothing to lend, a box the line touches is
        // in the way and a box it misses by a millimetre is not.
        let eye = SIMD3<Double>(0, 0, 5)
        XCTAssertTrue(SeeThrough.blocks(centre: SIMD3(0, 0, 2), size: SIMD3(1, 1, 1),
                                        from: eye, to: .zero, margin: 0))
        XCTAssertFalse(SeeThrough.blocks(centre: SIMD3(0.501, 0, 2), size: SIMD3(1, 1, 1),
                                         from: eye, to: .zero, margin: 0))
        // And the same box moved back to touch the line again, by that millimetre.
        XCTAssertTrue(SeeThrough.blocks(centre: SIMD3(0.499, 0, 2), size: SIMD3(1, 1, 1),
                                        from: eye, to: .zero, margin: 0))
    }

    // MARK: the window of ground around the head (FR-VIEW-155)

    /// One wall standing on the ground floor, two metres tall, with nothing else.
    private func oneWall() -> (model: ModelEntity, seeThrough: SeeThrough) {
        let colour = SIMD3<Double>(0.5, 0.5, 0.5)
        let model = ModelEntity(mesh: MeshResource.generateBox(size: 1),
                                materials: [SeeThrough.solid(colour: colour)])
        model.name = "wall"
        return (model, SeeThrough([
            SeeThrough.Module(model: model, level: 0,
                              centre: SIMD3(0, 1, 0), size: SIMD3(1, 2, 1),
                              solid: [SeeThrough.solid(colour: colour)],
                              clear: [SeeThrough.clear(colour: colour)]),
        ]))
    }

    func testAWallHidingTheGroundAheadIsDrawnThroughThoughItHidesNoneOfTheSnake() throws {
        let parts = oneWall()
        var seeThrough = parts.seeThrough
        // The snake is off to one side, where the wall hides no part of it: by
        // FR-VIEW-150 alone the wall is not in the way and stays solid.
        let aside = [SIMD3<Double>(4, 0, 0)]
        seeThrough.show(headOn: 0, snake: aside, from: eye, margin: 0)
        XCTAssertEqual(try look(of: parts.model).blending, .opaque,
                       "the wall went see-through with nothing of the snake behind it")
        // The same wall with a patch of the snake's own floor behind it in the
        // window: what the player is steering towards is hidden, and that is what
        // FR-VIEW-155 adds.
        seeThrough.show(headOn: 0, snake: aside,
                        window: SeeThrough.Window(head: SIMD3(4, 0, 0), ground: [SIMD3(0, 0, -1.5)]),
                        from: eye, margin: 0)
        XCTAssertNotEqual(try look(of: parts.model).blending, .opaque)
    }

    func testGroundTheWallDoesNotHideLeavesItSolid() throws {
        // The negation: a window point the wall stands nowhere near changes nothing,
        // or the test above would pass on a rule that cleared the map whenever a
        // window was given at all.
        let parts = oneWall()
        var seeThrough = parts.seeThrough
        seeThrough.show(headOn: 0, snake: [SIMD3(4, 0, 0)],
                        window: SeeThrough.Window(head: SIMD3(4, 0, 0), ground: [SIMD3(4, 0, -1.5)]),
                        from: eye, margin: 0)
        XCTAssertEqual(try look(of: parts.model).blending, .opaque)
    }

    /// The shipped arrangement, so that the table below is about the game and not
    /// about numbers chosen to make it pass: the configured pitch, the head on the
    /// ground floor, the kit's fence, and the ground within the shipped radius taken
    /// at the shipped cell. The camera stands on the negative-z side, so a module at
    /// positive z is behind the head.
    private func asShipped() throws -> (eye: SIMD3<Double>, window: SeeThrough.Window,
                                        fence: SIMD3<Double>, margin: Double) {
        let world = try world()
        let pitch = world.configurations.view.cameraPitch * .pi / 180
        let eye = SIMD3<Double>(0, 8 * sin(pitch), -8 * cos(pitch))
        let cell = world.plan.cellSize
        let radius = world.configurations.view.visibilityRadius
        let reach = Int((radius / cell).rounded(.up))
        var ground: [SIMD3<Double>] = []
        for x in -reach...reach {
            for z in -reach...reach where (Double(x) * cell) * (Double(x) * cell)
                + (Double(z) * cell) * (Double(z) * cell) <= radius * radius {
                ground.append(SIMD3(Double(x) * cell, 0, Double(z) * cell))
            }
        }
        let fence = try XCTUnwrap(world.kit.module(for: "#")).size
        let margin = world.configurations.tuning.bodyRadius
            + world.configurations.view.seeThroughMargin
        return (eye, SeeThrough.Window(head: .zero, ground: ground),
                SIMD3(fence[0], fence[1], fence[2]), margin)
    }

    /// One module at the given place, shown once, and whether it came out clear.
    private func cleared(module centre: SIMD3<Double>, size: SIMD3<Double>,
                         eye: SIMD3<Double>, snake: [SIMD3<Double>],
                         window: SeeThrough.Window?, margin: Double) throws -> Bool {
        let colour = SIMD3<Double>(0.5, 0.5, 0.5)
        let model = ModelEntity(mesh: MeshResource.generateBox(size: 1),
                                materials: [SeeThrough.solid(colour: colour)])
        var seeThrough = SeeThrough([
            SeeThrough.Module(model: model, level: 0, centre: centre, size: size,
                              solid: [SeeThrough.solid(colour: colour)],
                              clear: [SeeThrough.clear(colour: colour)]),
        ])
        seeThrough.show(headOn: 0, snake: snake, window: window, from: eye, margin: margin)
        return try look(of: model).blending != .opaque
    }

    func testTheWindowClearsWhatStandsBeforeTheHeadAndNothingBeyondIt() throws {
        // FR-VIEW-155. A window taken in every direction at once clears a fence
        // behind the snake, because that fence hides the ground behind itself and
        // that ground is inside the radius — which is what FR-VIEW-150 was fixed for
        // doing, at five times the radius. Beyond the head is where the window stops.
        let (eye, window, fence, margin) = try asShipped()
        let stair = SIMD3<Double>(0.5, 3, 0.5)
        let cases: [(String, SIMD3<Double>, SIMD3<Double>, Bool)] = [
            ("a fence one cell towards the camera", SIMD3(0, 0.4, -0.5), fence, true),
            ("a fence four cells towards the camera", SIMD3(0, 0.4, -2.0), fence, true),
            ("a fence beside the head", SIMD3(-0.5, 0.4, 0), fence, true),
            ("a fence diagonally before it", SIMD3(-0.5, 0.4, -0.5), fence, true),
            ("a fence one cell behind the head", SIMD3(0, 0.4, 0.5), fence, false),
            ("a fence two cells behind", SIMD3(0, 0.4, 1.0), fence, false),
            ("a fence four cells behind", SIMD3(0, 0.4, 2.0), fence, false),
            ("a three-metre stair behind", SIMD3(0, 1.5, 1.0), stair, false),
        ]
        for (label, centre, size, expected) in cases {
            // The head alone, so that only the window can clear anything: a tail
            // stretching behind would hide behind those fences and clear them by
            // FR-VIEW-150, which is a different rule and not this one.
            let got = try cleared(module: centre, size: size, eye: eye,
                                  snake: [window.head], window: window, margin: margin)
            XCTAssertEqual(got, expected, "\(label) came out \(got ? "clear" : "solid")")
        }
    }

    func testAFenceFurtherFromTheLineThanTheMarginIsLeftSolid() throws {
        // The three cells the two readings disagreed about until 2026-09-23: a metre
        // and a half towards the camera, which stands on the negative-z side, where
        // the fence is 0.565 m from the line of sight straight ahead and 0.618 m to
        // either side, against a margin of 0.45 m. Half a metre nearer it is 0.156 m
        // and 0.294 m away and still cleared, which is the pair that makes this a
        // measurement and not a blanket. The gaps do not depend on how far back the
        // camera sits, only on its pitch, so the test does not pin the distance.
        let (eye, window, fence, margin) = try asShipped()
        for x in [-0.5, 0.0, 0.5] {
            XCTAssertFalse(SeeThrough.blocks(centre: SIMD3(x, fence.y / 2, -1.5), size: fence,
                                             from: eye, to: window.head, margin: margin),
                           "a fence at x=\(x), 1.5 m towards the camera, is drawn see-through")
            XCTAssertTrue(SeeThrough.blocks(centre: SIMD3(x, fence.y / 2, -1.0), size: fence,
                                            from: eye, to: window.head, margin: margin),
                          "a fence at x=\(x), 1.0 m towards the camera, went solid")
        }
    }

    func testABodyBehindAFenceStillClearsItWhateverTheWindowSays() throws {
        // The other rule is untouched by the one above: a fence behind the head is
        // solid, and the same fence with a tail segment behind it is not, because
        // then it really is hiding the snake (FR-VIEW-150).
        let (eye, window, fence, margin) = try asShipped()
        let behind = SIMD3<Double>(0, 0.4, 0.5)
        XCTAssertFalse(try cleared(module: behind, size: fence, eye: eye,
                                   snake: [window.head], window: window, margin: margin))
        XCTAssertTrue(try cleared(module: behind, size: fence, eye: eye,
                                  snake: [window.head, SIMD3(0, 0, 1.0)],
                                  window: window, margin: margin))
    }

    func testBeyondIsMeasuredAcrossTheGroundAndNotAlongTheTiltedPlane() throws {
        // The trap this rule was nearly written into: the plane perpendicular to the
        // camera's line is tilted by the pitch, so the top of a fence standing behind
        // the head lies on the camera's side of it. Measured that way the test says
        // nothing; measured across the ground it says what it means.
        let (eye, window, fence, _) = try asShipped()
        let behind = SIMD3<Double>(0, fence.y / 2, 0.5)
        XCTAssertTrue(SeeThrough.beyond(centre: behind, size: fence, from: eye, past: window.head))
        // The tilted plane would have answered the other way, and this is the number
        // that shows it: the fence's top corner, nearest the camera along the line.
        let toHead = window.head - eye
        let reach = (toHead.x * toHead.x + toHead.y * toHead.y + toHead.z * toHead.z).squareRoot()
        let unit = toHead / reach
        let top = SIMD3(0.0, fence.y, 0.5 - fence.z / 2) - window.head
        XCTAssertLessThan(top.x * unit.x + top.y * unit.y + top.z * unit.z, 0,
                          "the tilted plane no longer puts the fence's top on the camera's side")
    }

    func testTheWindowIsTheWalkableGroundWithinTheRadiusAndNoFurther() throws {
        let world = try world()
        let cell = world.plan.cellSize
        let radius = world.configurations.view.visibilityRadius
        let start = try XCTUnwrap(world.graph.nodes.first { $0.floor == 0 })
        let head = SIMD3(Double(start.x) * cell, 0, Double(start.z) * cell)
        let window = SeeThrough.window(around: head, floor: 0, floorHeight: world.plan.floorHeight,
                                       radius: radius, cellSize: cell, in: world.graph).ground
        XCTAssertFalse(window.isEmpty, "the head's own cell is not in its own window")
        for point in window {
            let away = point - head
            XCTAssertLessThanOrEqual((away.x * away.x + away.z * away.z).squareRoot(),
                                     radius + 1e-9, "a point outside the radius is in the window")
            let node = NavigationGraph.Node(floor: 0, x: Int((point.x / cell).rounded()),
                                            z: Int((point.z / cell).rounded()))
            XCTAssertTrue(world.graph.isWalkable(node), "the window holds ground the map never laid")
        }
        // Every walkable cell of that floor within the radius is there, and not
        // merely some of them.
        let expected = world.graph.nodes.filter { node in
            guard node.floor == 0 else { return false }
            let dx = Double(node.x) * cell - head.x
            let dz = Double(node.z) * cell - head.z
            return dx * dx + dz * dz <= radius * radius
        }.count
        XCTAssertEqual(window.count, expected)
    }

    func testARadiusOfNothingIsNoWindowAtAll() throws {
        let world = try world()
        XCTAssertTrue(SeeThrough.window(around: .zero, floor: 0, floorHeight: world.plan.floorHeight,
                                        radius: 0, cellSize: world.plan.cellSize,
                                        in: world.graph).ground.isEmpty)
    }

    func testTheWindowLiesOnItsFloorAndNotOnTheClimbingHead() throws {
        // A head on the stair has already changed floors and is still walking up to
        // one — a whole second of it at the shipped speed. The window belongs to the
        // floor it names, so its height comes from that floor and not from the head.
        let world = try world()
        let cell = world.plan.cellSize
        let upstairs = try XCTUnwrap(world.graph.nodes.first { $0.floor == 1 })
        let halfway = SIMD3(Double(upstairs.x) * cell, world.plan.floorHeight / 2,
                            Double(upstairs.z) * cell)
        let window = SeeThrough.window(around: halfway, floor: 1, floorHeight: world.plan.floorHeight,
                                       radius: world.configurations.view.visibilityRadius,
                                       cellSize: cell, in: world.graph).ground
        XCTAssertFalse(window.isEmpty)
        for point in window {
            XCTAssertEqual(point.y, world.plan.floorHeight, accuracy: 1e-9,
                           "a window point hangs at the height the head happened to be at")
        }
    }

    func testAWallTouchingTheSnakeFromBehindIsNotInTheWay() {
        // The margin is room to the side of the line, never past its end. While it
        // grew the box in every direction at once it swallowed the point the line
        // stops at, so every wall the snake stood against went see-through — the one
        // behind it included, which a camera in front of the snake cannot be looking
        // through. The pitch and the margin are the shipped ones; the box is a wall
        // on a half-metre grid, tall enough that its height cannot be what decides
        // the answer — which side of the snake it stands on is.
        let pitch = 55.0 * .pi / 180
        let eye = SIMD3<Double>(0, 8 * sin(pitch), -8 * cos(pitch))
        let head = SIMD3<Double>(0, 0.05, 0)
        let wall = SIMD3<Double>(0.5, 3, 0.5)
        let margin = 0.45
        XCTAssertFalse(SeeThrough.blocks(centre: SIMD3(0, 1.5, 0.5), size: wall,
                                         from: eye, to: head, margin: margin),
                       "the wall behind the snake is drawn see-through")
        // The same cell's worth of wall on the camera's side is in the way, or the
        // assertion above would pass on a rule that had stopped saying yes at all.
        XCTAssertTrue(SeeThrough.blocks(centre: SIMD3(0, 1.5, -0.5), size: wall,
                                        from: eye, to: head, margin: margin))
        // And beside the snake, where half a step would put it in front: the margin
        // buys the fade its head start, and that is not what this took away.
        XCTAssertTrue(SeeThrough.blocks(centre: SIMD3(-0.5, 1.5, 0), size: wall,
                                        from: eye, to: head, margin: margin))
        XCTAssertTrue(SeeThrough.blocks(centre: SIMD3(0.5, 1.5, 0), size: wall,
                                        from: eye, to: head, margin: margin))
    }

    func testAWallStopsBeingSeeThroughOnceTheSnakeIsNoLongerBehindIt() {
        let parts = twoFloors()
        let below = parts.below
        var seeThrough = parts.seeThrough
        // `below` stands at the origin; a snake beyond it, seen from this side, is
        // behind it.
        seeThrough.show(headOn: 0, snake: [SIMD3(0, -3, -3)], from: eye, margin: 0.15)
        XCTAssertNotEqual(try look(of: below).blending, .opaque, "the wall in the way is solid")
        // The same wall, with the snake stepped aside: FR-VIEW-150 says "for as long
        // as it stands there", and this is the "no longer" half.
        seeThrough.show(headOn: 0, snake: [SIMD3(6, 0, -3)], from: eye, margin: 0.15)
        XCTAssertEqual(try look(of: below).blending, .opaque, "the wall stayed see-through")
        XCTAssertNotEqual(below.components[DynamicLightShadowComponent.self]?.castsShadow, false)
    }

    func testOverTheBlockoutTheLineToTheSnakeClearsMoreThanTheFloorAboveDoes() throws {
        let world = try world()
        let scene = SceneBuilder.entity(for: world.plan)
        var seeThrough = scene.seeThrough
        // The walkable cell nearest the camera on the ground floor: the wall of the
        // room stands directly between it and the camera, which is the case the
        // requirement is about. Taken from the map rather than written down here, so
        // that a redrawn blockout moves the test with it.
        let cell = world.plan.cellSize
        let corner = try XCTUnwrap(world.graph.nodes.filter { $0.floor == 0 }.max { a, b in a.z < b.z })
        let head = SIMD3(Double(corner.x) * cell, 0, Double(corner.z) * cell)
        let above = world.plan.pieces.filter { $0.level > 0 }.count

        func seeThroughCount() -> Int {
            scene.root.children
                .compactMap { ($0 as? ModelEntity)?.model?.materials.first as? PhysicallyBasedMaterial }
                .filter { $0.blending != .opaque }
                .count
        }

        // Straight down on the snake: nothing of the map can be between the two, so
        // only the floor above is cleared.
        seeThrough.show(headOn: 0, snake: [head], from: head + SIMD3(0, 12, 0), margin: 0.2)
        XCTAssertEqual(seeThroughCount(), above)

        // From where the camera actually stands: the match's own distance and the
        // configured pitch, which is what decides whether the line clears the wall
        // or runs into it.
        let distance = max(world.plan.bounds.extent.x, world.plan.bounds.extent.z) * 1.1
        let pitch = world.configurations.view.cameraPitch * .pi / 180
        let eye = head + SIMD3(0, distance * sin(pitch), distance * cos(pitch))
        seeThrough.show(headOn: 0, snake: [head], from: eye, margin: 0.2)
        XCTAssertGreaterThan(seeThroughCount(), above, "the room's own wall is in the line and stayed solid")
    }
}
