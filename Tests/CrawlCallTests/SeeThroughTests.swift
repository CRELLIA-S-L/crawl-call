// What the player sees through: a floor above the head (FR-VIEW-140) and whatever
// stands between the camera and the snake (FR-VIEW-150), from the floor a piece is
// placed on, the line test itself, the switch, and the four together over the real
// blockout.
//
// verifies: FR-VIEW-140, FR-VIEW-150
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
