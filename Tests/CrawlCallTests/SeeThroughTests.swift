// What the player sees through: a floor above the head (FR-VIEW-140) and whatever
// stands between the camera and the snake (FR-VIEW-150), from the floor a piece is
// placed on, the line test itself, the switch, and the four together over the real
// blockout.
//
// verifies: FR-TOOL-260, FR-TOOL-270, FR-VIEW-140, FR-VIEW-150, FR-VIEW-155
import RealityKit
import XCTest
@testable import CrawlCall

/// Which box a hole belongs to: `SeeThrough.holes` answers by the index of each box in
/// the list it is given. Named, so that a lookup reads as which box it asks about.
private enum BoxKey {
    /// The one box of a list of one.
    static let only = 0
    /// The boxes of `three()`, in its order.
    static let partition = 0
    static let fence = 1
    static let crate = 2
}

@MainActor
final class SeeThroughTests: XCTestCase {
    private func world() throws -> World { try Launch.world(map: "room").get() }

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

    /// How many modules of a built scene are drawn see-through, faded whole or cut
    /// open alike: a hole is a CustomMaterial where the shader loaded, and a fade is a
    /// PhysicallyBasedMaterial that is not opaque.
    private func seeThroughCount(_ root: Entity) -> Int {
        root.children.compactMap { ($0 as? ModelEntity)?.model?.materials.first }.filter { material in
            if material is CustomMaterial { return true }
            return (material as? PhysicallyBasedMaterial).map { $0.blending != .opaque } ?? false
        }.count
    }

    private func look(of model: ModelEntity) throws -> PhysicallyBasedMaterial {
        try XCTUnwrap(model.model?.materials.first as? PhysicallyBasedMaterial)
    }

    func testTheFloorAboveTheHeadIsAFrameAndTheHeadsFloorStaysSolid() throws {
        let parts = twoFloors()
        let (below, above) = (parts.below, parts.above)
        var seeThrough = parts.seeThrough
        seeThrough.show(headOn: 0, head: .zero, surface: 0, snake: [], from: .zero, margin: 0, visibilityRadius: 0)

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
        seeThrough.show(headOn: 0, head: .zero, surface: 0, snake: [], from: .zero, margin: 0, visibilityRadius: 0)
        seeThrough.show(headOn: 1, head: .zero, surface: 0, snake: [], from: .zero, margin: 0, visibilityRadius: 0)
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
        seeThrough.show(headOn: 0, head: .zero, surface: 0, snake: [], from: .zero, margin: 0, visibilityRadius: 0)

        // Counted rather than matched piece by piece: the plan says how many modules
        // stand above the ground floor, and exactly that many are drawn see-through.
        let expected = world.plan.pieces.filter { $0.level > 0 }.count
        let cleared = seeThroughCount(built.root)
        XCTAssertGreaterThan(expected, 0, "a one-floor map would pass this test for the wrong reason")
        XCTAssertEqual(cleared, expected)
        XCTAssertLessThan(cleared, built.root.children.count, "the whole map went see-through")
    }

    // MARK: where a module is cut open (ADR-0020)

    /// The match's camera as SceneView places it: 55 degrees down, 13.2 m back along
    /// positive z from what it looks at. In front of the snake is positive z.
    private func matchEye(over point: SIMD3<Double> = .zero) -> SIMD3<Double> {
        let pitch = 55.0 * .pi / 180
        return point + SIMD3(0, 13.2 * sin(pitch), 13.2 * cos(pitch))
    }
    private let reach = 0.45                       // bodyRadius + seeThroughMargin, shipped
    private let fence = SIMD3<Double>(0.5, 0.8, 0.5)
    private func box(_ centre: SIMD3<Double>, _ size: SIMD3<Double>, level: Int = 0) -> SeeThrough.Box {
        SeeThrough.Box(centre: centre, size: size, level: level)
    }
    /// Whether a line-of-sight hole cuts a point: within the radius of the line from
    /// the eye to the aim, and no further along it than the aim. The shader's own test,
    /// written again here so the test does not read the answer off the code.
    private func cut(_ point: SIMD3<Double>, by hole: SeeThrough.Hole, from eye: SIMD3<Double>) -> Bool {
        guard case .along(let aim) = hole.shape else { return gap(point, aimOrCentre(hole)) <= hole.radius }
        let toAim = aim - eye
        let reach = gap(aim, eye)
        let unit = toAim / reach
        let rel = point - eye
        let depth = rel.x * unit.x + rel.y * unit.y + rel.z * unit.z
        return depth <= reach && gap(rel, unit * depth) <= hole.radius
    }
    private func aimOrCentre(_ hole: SeeThrough.Hole) -> SIMD3<Double> {
        switch hole.shape { case .around(let c): return c; case .along(let p): return p }
    }
    private func gap(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = a - b
        return (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot()
    }

    func testATallModuleWellInFrontIsCutWhereTheLineCrossesItAndStandsElsewhere() throws {
        // A 2 m partition 1.2 m in front of the snake cuts the line of sight at 1.71 m.
        // It is cut along that line, not around the snake, which a hole kept to the
        // snake's side would never reach; and it is cut along the line and not with a
        // sphere around the stretch of it, which on the phone cleared the whole
        // partition. Where the line crosses, it is open; at its foot, it stands.
        let partition = box(SIMD3(0, 1, 1.2), SIMD3(0.5, 2, 0.1))
        let eye = matchEye()
        let hole = try XCTUnwrap(SeeThrough.holes(in: [partition], headOn: 0, head: .zero, surface: 0,
                                                  snake: [.zero], from: eye, margin: reach,
                                                  visibilityRadius: 0)[BoxKey.only],
                                 "a partition hiding the snake is not cut open at all")
        XCTAssertEqual(hole, SeeThrough.Hole(shape: .along(.zero), radius: reach, cause: .line))
        XCTAssertTrue(cut(SIMD3(0, 1.714, 1.2), by: hole, from: eye), "not open where the line crosses")
        // 0.6 m up is 0.64 m from the line of sight, beyond the 0.45 m it is cut to; a
        // sphere holding the stretch of line through the partition reaches it, which is
        // how the whole partition went clear on the phone.
        XCTAssertFalse(cut(SIMD3(0, 0.6, 1.2), by: hole, from: eye), "open low down, far from the line")
    }

    func testAModuleNearTheHeadThatHidesNothingIsCutAroundTheHead() throws {
        // FR-VIEW-155: a fence a metre and a half to the side, which no line of sight
        // to the head goes near, still stands within the visibility radius.
        let aside = box(SIMD3(-1.5, 0.4, 0), fence)
        let holes = SeeThrough.holes(in: [aside], headOn: 0, head: .zero, surface: 0, snake: [.zero],
                                     from: matchEye(), margin: reach, visibilityRadius: 2.5)
        XCTAssertEqual(holes[BoxKey.only], SeeThrough.Hole(shape: .around(.zero), radius: 2.5, cause: .window))
        // And with no window asked for, nothing about it wants cutting.
        XCTAssertNil(SeeThrough.holes(in: [aside], headOn: 0, head: .zero, surface: 0, snake: [.zero],
                                      from: matchEye(), margin: reach, visibilityRadius: 0)[BoxKey.only])
    }

    func testNothingWhollyBeyondTheHeadIsCutForTheWindow() {
        // The same fence moved a metre behind the head, away from the camera: inside
        // the radius, hiding nothing, and beyond — so left standing.
        let behind = box(SIMD3(0, 0.4, -1), fence)
        XCTAssertNil(SeeThrough.holes(in: [behind], headOn: 0, head: .zero, surface: 0, snake: [.zero],
                                      from: matchEye(), margin: reach, visibilityRadius: 2.5)[BoxKey.only])
    }

    func testTheFloorUnderTheHeadIsNeverCut() {
        // Cut open, it shows the void — which the throwaway build's first run did.
        let slab = box(SIMD3(0, -0.05, 0), SIMD3(0.5, 0.1, 0.5))
        XCTAssertNil(SeeThrough.holes(in: [slab], headOn: 0, head: .zero, surface: 0, snake: [.zero],
                                      from: matchEye(), margin: reach, visibilityRadius: 2.5)[BoxKey.only])
    }

    func testAFloorAboveTheHeadIsALidAndNotAHole() {
        // FR-VIEW-140 fades it whole; it is not the choosing's business at all.
        let balcony = box(SIMD3(0, 2.95, 0.5), SIMD3(0.5, 0.1, 0.5), level: 1)
        XCTAssertTrue(SeeThrough.holes(in: [balcony], headOn: 0, head: .zero, surface: 0, snake: [.zero],
                                       from: matchEye(), margin: reach, visibilityRadius: 2.5).isEmpty)
    }

    func testFarFromEverythingNothingIsCut() {
        let far = box(SIMD3(5, 0.4, 5), fence)
        XCTAssertTrue(SeeThrough.holes(in: [far], headOn: 0, head: .zero, surface: 0, snake: [.zero],
                                       from: matchEye(), margin: reach, visibilityRadius: 2.5).isEmpty)
    }

    func testOneModuleHidingTwoPartsIsCutOpenAroundBoth() throws {
        // A module carries one hole, so it is cut along the line to the middle of the
        // two parts, wide enough to take in where each part's own line crosses it.
        let wide = box(SIMD3(0, 1, 1.2), SIMD3(3, 2, 0.1))
        let parts: [SIMD3<Double>] = [SIMD3(-1, 0, 0), SIMD3(1, 0, 0)]
        let eye = matchEye()
        let hole = try XCTUnwrap(SeeThrough.holes(in: [wide], headOn: 0, head: element(0, of: parts), surface: 0,
                                                  snake: parts, from: eye, margin: reach,
                                                  visibilityRadius: 0)[BoxKey.only])
        XCTAssertEqual(hole, SeeThrough.Hole(shape: .along(.zero), radius: reach + 1, cause: .line))
        for part in parts {
            // Where that part's line crosses the module's plane, derived on its own.
            let along = (1.2 - eye.z) / (part.z - eye.z)
            let crossing = eye + (part - eye) * along
            XCTAssertTrue(cut(crossing, by: hole, from: eye), "the crossing for \(part) is left standing")
        }
    }

    func testATailPartDownADropIsFreedByWhatHidesItThoughThatIsLowerThanTheHead() throws {
        // The head is up on the balcony and the tail lies down the drop. A crate on
        // the floor below is lower than the head, and FR-VIEW-155 would never cut it;
        // the line of sight to the tail goes through it, and FR-VIEW-150 does.
        let tail = SIMD3<Double>(0, 0, 0)
        let head = SIMD3<Double>(0, 3, -2)
        let crate = box(SIMD3(0, 0.5, 0.4), SIMD3(0.5, 1, 0.5))
        XCTAssertNotNil(SeeThrough.holes(in: [crate], headOn: 1, head: head, surface: 3, snake: [head, tail],
                                         from: matchEye(over: tail), margin: reach,
                                         visibilityRadius: 2.5)[BoxKey.only])
    }

    func testAModuleBothBesideTheHeadAndHidingItIsCutWideEnoughForEither() throws {
        // A fence the body touches — its face the body's radius from the head
        // (ADR-0021) — is within the margin of a line of sight to the head, and it
        // stands within the window too.
        let beside = box(SIMD3(-0.25 - 0.3, 0.4, 0), fence)
        let hole = try XCTUnwrap(SeeThrough.holes(in: [beside], headOn: 0, head: .zero, surface: 0, snake: [.zero],
                                                  from: matchEye(), margin: reach,
                                                  visibilityRadius: 2.5)[BoxKey.only])
        guard case .around(let centre) = hole.shape else {
            return XCTFail("a module that needs both is not cut with one sphere around both")
        }
        XCTAssertGreaterThanOrEqual(hole.radius, 2.5 - 1e-9)
        XCTAssertLessThanOrEqual(gap(centre, .zero), hole.radius - 2.5 + 1e-9,
                                 "the head's own window is not inside the hole")
    }

    func testAFloorAHeadIsClimbingOntoIsNotCutForBeingHigherThanTheHead() {
        // Walking a stair, the head has changed floors and is a second's climb short of
        // the surface. A slab of that floor stands higher than the head, but not higher
        // than the floor it belongs to, and it is the floor that is measured against —
        // or the balcony is cut open under the snake for the whole of the climb.
        let halfway = SIMD3<Double>(0, 1.5, 0)
        let slab = box(SIMD3(1.5, 2.95, 0), SIMD3(0.5, 0.1, 0.5), level: 1)
        XCTAssertNil(SeeThrough.holes(in: [slab], headOn: 1, head: halfway, surface: 3,
                                      snake: [halfway], from: matchEye(over: halfway),
                                      margin: reach, visibilityRadius: 2.5)[BoxKey.only])
        // The pair that makes the test mean something: measured against the head's own
        // height, the same slab would be cut.
        XCTAssertNotNil(SeeThrough.holes(in: [slab], headOn: 1, head: halfway, surface: 1.5,
                                         snake: [halfway], from: matchEye(over: halfway),
                                         margin: reach, visibilityRadius: 2.5)[BoxKey.only])
    }

    // MARK: debug mode's switches (FR-TOOL-260, FR-TOOL-270)

    /// A partition in front of the snake, which the line of sight cuts, and a fence to
    /// its side within the window, which only the window cuts; and a crate beside the
    /// head that both cut.
    private func three() -> [SeeThrough.Box] {
        [box(SIMD3(0, 1, 1.2), SIMD3(0.5, 2, 0.1)),
         box(SIMD3(-1.5, 0.4, 0), fence),
         box(SIMD3(0, 0.5, 0.6), SIMD3(0.5, 1, 0.5))]
    }

    private func holes(_ switches: SeeThrough.Switches) -> [Int: SeeThrough.Hole] {
        SeeThrough.holes(in: three(), headOn: 0, head: .zero, surface: 0, snake: [.zero],
                         from: matchEye(), margin: reach, visibilityRadius: 2.5, switches: switches)
    }

    func testEachHoleKnowsWhatCutIt() {
        let all = holes(SeeThrough.Switches())
        XCTAssertEqual(all[BoxKey.partition]?.cause, .both, "the partition stands within the window as well")
        XCTAssertEqual(all[BoxKey.fence]?.cause, .window)
        XCTAssertEqual(all[BoxKey.crate]?.cause, .both)
        // Far from the head, the partition is the line's alone.
        let far = SeeThrough.holes(in: three(), headOn: 0, head: .zero, surface: 0, snake: [.zero],
                                   from: matchEye(), margin: reach, visibilityRadius: 0.5)
        XCTAssertEqual(far[BoxKey.partition]?.cause, .line)
    }

    func testSwitchingTheLineOffLeavesOnlyTheWindow() {
        let window = holes(SeeThrough.Switches(line: false, window: true))
        XCTAssertFalse(window.isEmpty)
        XCTAssertTrue(window.values.allSatisfy { $0.cause == .window }, "\(window)")
    }

    func testSwitchingTheWindowOffLeavesOnlyTheLine() {
        let line = holes(SeeThrough.Switches(line: true, window: false))
        XCTAssertNil(line[BoxKey.fence], "the fence aside hides nothing, and only the window cut it")
        XCTAssertFalse(line.isEmpty)
        XCTAssertTrue(line.values.allSatisfy { $0.cause == .line }, "\(line)")
    }

    func testSwitchingBothOffCutsNothing() {
        XCTAssertTrue(holes(SeeThrough.Switches(line: false, window: false)).isEmpty)
    }

    func testTheSwitchesByThemselvesHaveBothCutsAndNoTint() {
        XCTAssertEqual(SeeThrough.Switches(), SeeThrough.Switches(line: true, window: true, tint: false))
        // Three causes, three colours.
        XCTAssertEqual(Set(SeeThrough.Hole.Cause.allCases.map { "\(SeeThrough.tint(for: $0))" }).count, 3)
    }

    func testTintPaintsWhatIsCutByWhatCutItAndOnlyWhenAskedFor() throws {
        let colour = SIMD3<Double>(0.5, 0.5, 0.5)
        let holed = try XCTUnwrap(SeeThrough.holed(from: SeeThrough.solid(colour: colour)))
        func drawn(_ switches: SeeThrough.Switches) throws -> CGColor {
            let model = ModelEntity(mesh: MeshResource.generateBox(size: 1), materials: [SeeThrough.solid(colour: colour)])
            let partition = SeeThrough.Module(model: model, level: 0,
                                              centre: SIMD3(0, 1, 1.2), size: SIMD3(0.5, 2, 0.1),
                                              solid: [SeeThrough.solid(colour: colour)],
                                              clear: [SeeThrough.clear(colour: colour)], holed: [holed])
            var seeThrough = SeeThrough([partition])
            seeThrough.show(headOn: 0, head: .zero, surface: 0, snake: [.zero], from: matchEye(),
                            margin: reach, visibilityRadius: 0, switches: switches)
            return try XCTUnwrap(model.model?.materials.first as? CustomMaterial).baseColor.__tint
        }
        func rgb(_ c: CGColor) throws -> SIMD3<Double> {
            let converted = c.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil) ?? c
            let parts = converted.components ?? []
            // Red, green and blue; the fourth component is alpha.
            return try vector(parts.prefix(SIMD3<Double>.scalarCount).map { Double($0) })
        }
        let tinted = try rgb(drawn(SeeThrough.Switches(tint: true)))
        let line = SeeThroughTint.line
        XCTAssertEqual(tinted.x, line.x, accuracy: 0.01)
        XCTAssertEqual(tinted.y, line.y, accuracy: 0.01)
        XCTAssertEqual(tinted.z, line.z, accuracy: 0.01)
        let plain = try rgb(drawn(SeeThrough.Switches()))
        XCTAssertEqual(plain.x, colour.x, accuracy: 0.01, "a match tints what it cuts")
    }

    func testTheHoleShaderLoadsAndAModuleIsDrawnThroughIt() throws {
        // ADR-0020 falls back to fading whole where the shader is not there, which keeps
        // the game safe and would also keep this suite green with the shader missing.
        // So it is asked outright: the shader loads, and a module the choosing cuts
        // open carries the hole the choosing computed.
        let colour = SIMD3<Double>(0.5, 0.5, 0.5)
        let holed = try XCTUnwrap(SeeThrough.holed(from: SeeThrough.solid(colour: colour)),
                                  "the hole shader did not load from the app's library")
        let model = ModelEntity(mesh: MeshResource.generateBox(size: 1),
                                materials: [SeeThrough.solid(colour: colour)])
        // A 2 m partition 1.2 m in front of the snake, as in the choosing's own test.
        let partition = SeeThrough.Module(model: model, level: 0,
                                          centre: SIMD3(0, 1, 1.2), size: SIMD3(0.5, 2, 0.1),
                                          solid: [SeeThrough.solid(colour: colour)],
                                          clear: [SeeThrough.clear(colour: colour)],
                                          holed: [holed])
        var seeThrough = SeeThrough([partition])
        seeThrough.show(headOn: 0, head: .zero, surface: 0, snake: [.zero], from: matchEye(),
                        margin: reach, visibilityRadius: 0)
        let drawn = try XCTUnwrap(model.model?.materials.first as? CustomMaterial,
                                  "the partition in the way is not drawn through the hole shader")
        let expected = try XCTUnwrap(SeeThrough.holes(in: [SeeThrough.Box(centre: partition.centre,
                                                                          size: partition.size, level: 0)],
                                                      headOn: 0, head: .zero, surface: 0, snake: [.zero],
                                                      from: matchEye(), margin: reach,
                                                      visibilityRadius: 0)[BoxKey.only])
        XCTAssertEqual(drawn.custom.value, expected.parameter)
        // Along a line of sight, which the shader reads from the sign of the radius.
        XCTAssertLessThan(drawn.custom.value.w, 0)
        // It still stands, so it still casts its shadow (ADR-0020).
        XCTAssertEqual(model.components[DynamicLightShadowComponent.self]?.castsShadow, true)
        // And stepping the snake away puts the partition back as it was.
        seeThrough.show(headOn: 0, head: SIMD3(5, 0, 0), surface: 0, snake: [SIMD3(5, 0, 0)],
                        from: matchEye(over: SIMD3(5, 0, 0)), margin: reach, visibilityRadius: 0)
        XCTAssertEqual(try look(of: model).blending, .opaque, "the partition stayed holed")
    }

    func testModulesSharingOneLookEachKeepTheirOwnHole() throws {
        // A scene builds the holed look once per module type and every fence shares it
        // (SceneBuilder), and the material carries its parameters in a block RealityKit
        // does not document as copied on write. If it were shared, every fence would
        // show the hole of whichever was written last. Two partitions, each in front of
        // its own snake part, must come out with two different holes.
        let colour = SIMD3<Double>(0.5, 0.5, 0.5)
        let shared = try XCTUnwrap(SeeThrough.holed(from: SeeThrough.solid(colour: colour)))
        let size = SIMD3<Double>(0.5, 2, 0.1)
        let centres = [SIMD3<Double>(-2, 1, 1.2), SIMD3<Double>(2, 1, 1.2)]
        let models = centres.map { _ in ModelEntity(mesh: MeshResource.generateBox(size: 1),
                                                    materials: [SeeThrough.solid(colour: colour)]) }
        var seeThrough = SeeThrough(zip(models, centres).map { model, centre in
            SeeThrough.Module(model: model, level: 0, centre: centre, size: size,
                              solid: [SeeThrough.solid(colour: colour)],
                              clear: [SeeThrough.clear(colour: colour)], holed: [shared])
        })
        let parts = [SIMD3<Double>(-2, 0, 0), SIMD3<Double>(2, 0, 0)]
        seeThrough.show(headOn: 0, head: try element(0, of: parts), surface: 0, snake: parts, from: matchEye(),
                        margin: reach, visibilityRadius: 0)
        let drawn = try models.map { try XCTUnwrap($0.model?.materials.first as? CustomMaterial) }
        XCTAssertLessThan(try element(0, of: drawn).custom.value.x, 0, "the left partition's hole is not on the left")
        XCTAssertGreaterThan(try element(1, of: drawn).custom.value.x, 0, "the right partition's hole is not on the right")
        // And the look they were made from is untouched.
        XCTAssertEqual(shared.custom.value, SIMD4<Float>(repeating: 0))
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

    /// The shipped arrangement, so that the table below is about the game and not
    /// about numbers chosen to make it pass: the configured pitch, the head on the
    /// ground floor at the origin, the kit's fence, the shipped margin and radius. The
    /// camera stands on the negative-z side, so a module at positive z is behind the head.
    private func asShipped() throws -> (eye: SIMD3<Double>, fence: SIMD3<Double>,
                                        margin: Double, radius: Double) {
        let world = try world()
        let pitch = world.configurations.view.cameraPitch * .pi / 180
        let eye = SIMD3<Double>(0, 8 * sin(pitch), -8 * cos(pitch))
        let fence = try XCTUnwrap(world.kit.module(for: "#")).size
        let margin = world.configurations.tuning.bodyRadius
            + world.configurations.view.seeThroughMargin
        return (eye, try vector(fence), margin,
                world.configurations.view.visibilityRadius)
    }

    /// Whether one module at the given place is cut open.
    private func cleared(module centre: SIMD3<Double>, size: SIMD3<Double>,
                         eye: SIMD3<Double>, snake: [SIMD3<Double>],
                         margin: Double, radius: Double) -> Bool {
        SeeThrough.holes(in: [SeeThrough.Box(centre: centre, size: size, level: 0)],
                         headOn: 0, head: .zero, surface: 0, snake: snake, from: eye,
                         margin: margin, visibilityRadius: radius)[BoxKey.only] != nil
    }

    func testTheWindowClearsWhatStandsBeforeTheHeadAndNothingBeyondIt() throws {
        // FR-VIEW-155. A window taken in every direction at once clears a fence
        // behind the snake, because that fence hides the ground behind itself and
        // that ground is inside the radius — which is what FR-VIEW-150 was fixed for
        // doing, at five times the radius. Beyond the head is where the window stops.
        let (eye, fence, margin, radius) = try asShipped()
        let stair = SIMD3<Double>(0.5, 3, 0.5)
        let cases: [(String, SIMD3<Double>, SIMD3<Double>, Bool)] = [
            ("a fence one cell towards the camera", SIMD3(0, 0.4, -0.5), fence, true),
            // Inside the window and outside it, placed by the shipped radius rather than
            // by a number that was right for one radius and wrong for the next.
            ("a fence towards the camera, inside the window",
             SIMD3(0, 0.4, -(radius - 0.5)), fence, true),
            ("a fence towards the camera, past the window's edge",
             SIMD3(0, 0.4, -(radius + 0.5)), fence, false),
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
            let got = cleared(module: centre, size: size, eye: eye,
                              snake: [.zero], margin: margin, radius: radius)
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
        let (eye, fence, margin, _) = try asShipped()
        for x in [-0.5, 0.0, 0.5] {
            XCTAssertFalse(SeeThrough.blocks(centre: SIMD3(x, fence.y / 2, -1.5), size: fence,
                                             from: eye, to: .zero, margin: margin),
                           "a fence at x=\(x), 1.5 m towards the camera, is drawn see-through")
            XCTAssertTrue(SeeThrough.blocks(centre: SIMD3(x, fence.y / 2, -1.0), size: fence,
                                            from: eye, to: .zero, margin: margin),
                          "a fence at x=\(x), 1.0 m towards the camera, went solid")
        }
    }

    func testABodyBehindAFenceStillClearsItWhateverTheWindowSays() throws {
        // The other rule is untouched by the one above: a fence behind the head is
        // solid, and the same fence with a tail segment behind it is not, because
        // then it really is hiding the snake (FR-VIEW-150).
        let (eye, fence, margin, radius) = try asShipped()
        let behind = SIMD3<Double>(0, 0.4, 0.5)
        XCTAssertFalse(cleared(module: behind, size: fence, eye: eye,
                               snake: [.zero], margin: margin, radius: radius))
        XCTAssertTrue(cleared(module: behind, size: fence, eye: eye,
                              snake: [.zero, SIMD3(0, 0, 1.0)], margin: margin, radius: radius))
    }

    func testBeyondIsMeasuredAcrossTheGroundAndNotAlongTheTiltedPlane() throws {
        // The trap this rule was nearly written into: the plane perpendicular to the
        // camera's line is tilted by the pitch, so the top of a fence standing behind
        // the head lies on the camera's side of it. Measured that way the test says
        // nothing; measured across the ground it says what it means.
        let (eye, fence, _, _) = try asShipped()
        let behind = SIMD3<Double>(0, fence.y / 2, 0.5)
        XCTAssertTrue(SeeThrough.beyond(centre: behind, size: fence, from: eye, past: .zero))
        // The tilted plane would have answered the other way, and this is the number
        // that shows it: the fence's top corner, nearest the camera along the line.
        let toHead = SIMD3<Double>.zero - eye
        let length = (toHead.x * toHead.x + toHead.y * toHead.y + toHead.z * toHead.z).squareRoot()
        let unit = toHead / length
        let top = SIMD3(0.0, fence.y, 0.5 - fence.z / 2)
        XCTAssertLessThan(top.x * unit.x + top.y * unit.y + top.z * unit.z, 0,
                          "the tilted plane no longer puts the fence's top on the camera's side")
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
        seeThrough.show(headOn: 0, head: .zero, surface: 0, snake: [SIMD3(0, -3, -3)], from: eye, margin: 0.15, visibilityRadius: 0)
        XCTAssertNotEqual(try look(of: below).blending, .opaque, "the wall in the way is solid")
        // The same wall, with the snake stepped aside: FR-VIEW-150 says "for as long
        // as it stands there", and this is the "no longer" half.
        seeThrough.show(headOn: 0, head: .zero, surface: 0, snake: [SIMD3(6, 0, -3)], from: eye, margin: 0.15, visibilityRadius: 0)
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


        // Straight down on the snake: nothing of the map can be between the two, so
        // only the floor above is cleared.
        seeThrough.show(headOn: 0, head: .zero, surface: 0, snake: [head], from: head + SIMD3(0, 12, 0), margin: 0.2, visibilityRadius: 0)
        XCTAssertEqual(seeThroughCount(scene.root), above)

        // From where the camera actually stands: the match's own distance and the
        // configured pitch, which is what decides whether the line clears the wall
        // or runs into it.
        let distance = max(world.plan.bounds.extent.x, world.plan.bounds.extent.z) * 1.1
        let pitch = world.configurations.view.cameraPitch * .pi / 180
        let eye = head + SIMD3(0, distance * sin(pitch), distance * cos(pitch))
        seeThrough.show(headOn: 0, head: .zero, surface: 0, snake: [head], from: eye, margin: 0.2, visibilityRadius: 0)
        XCTAssertGreaterThan(seeThroughCount(scene.root), above, "the room's own wall is in the line and stayed solid")
    }

    // MARK: the ground slabs, which nothing cuts (ADR-0047)

    func testAGroundSlabIsABoxOfTheGroundFloorLyingAtItsSurfaceOverNoBasement() throws {
        let kit = try Kit.load(named: "blockout", from: .main)
        // A floor over two cells of basement, a wall on the ground floor, a balcony
        // cell on floor 1: the slabs are the floor over solid ground, the floor the map
        // implies under the wall among them (FR-TOOL-020), and not the wall itself,
        // whose top stands above the surface.
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor -1\n..\nfloor 0\n....#\nfloor 1\n   .\n", kit: kit)
        let plan = ScenePlan.make(map: map, kit: kit, cellSize: 0.5)
        let slabs = Set(plan.groundSlabs)
        func cell(_ piece: ScenePlan.Piece) -> (Int, Int) {
            (Int((piece.centre.x / 0.5).rounded()), Int((piece.centre.z / 0.5).rounded()))
        }
        for (index, piece) in plan.pieces.enumerated() {
            let (x, z) = cell(piece)
            let expected = piece.level == 0 && piece.module == "floor" && (2...4).contains(x) && z == 0
                && abs(piece.centre.y + piece.size.y / 2) < 1e-9
            XCTAssertEqual(slabs.contains(index), expected, "\(piece.module) at \(x),\(z) on floor \(piece.level)")
        }
        XCTAssertFalse(slabs.isEmpty, "the map has no slab, so the test proves nothing")
    }

    func testNoGroundSlabIsEverCutOrFadedWhereverTheHeadAndTheCameraAre() throws {
        // The rules of FR-VIEW-140, FR-VIEW-150 and FR-VIEW-155 over the shipped map,
        // with the head on every cell anybody can stand on and the camera turned every
        // eighth of a turn: a slab the see-through could touch would be drawn wrong
        // once it is joined to the rest (ADR-0047).
        let world = try Launch.world().get()
        let plan = world.plan
        let slabs = Set(plan.groundSlabs)
        XCTAssertFalse(slabs.isEmpty, "the map has no ground slabs, so the test proves nothing")
        let boxes = plan.pieces.map { SeeThrough.Box(centre: $0.centre, size: $0.size, level: $0.level) }
        let cell = world.configurations.tuning.navigationGraphCellSize
        let distance = SceneView.distance(framing: plan, view: world.configurations.view)
        let pitch = world.configurations.view.cameraPitch * .pi / 180
        let margin = world.configurations.tuning.bodyRadius + world.configurations.view.seeThroughMargin
        let radius = world.configurations.tuning.bodyRadius
        var heads = 0
        for node in world.graph.nodes {
            let ground = world.graph.centre(of: node, cellSize: cell, floorHeight: world.kit.floorHeight)
            let head = ground + SIMD3(0, radius, 0)
            let snake = [head, head + SIMD3(2 * radius, 0, 0), head + SIMD3(4 * radius, 0, radius), head + SIMD3(-2 * radius, 0, 2 * radius)]
            heads += 1
            for eighth in 0..<8 {
                let yaw = Double(eighth) * .pi / 4
                let across = distance * cos(pitch)
                let eye = SIMD3(head.x + across * sin(yaw), head.y + distance * sin(pitch), head.z + across * cos(yaw))
                let holes = SeeThrough.holes(in: boxes, headOn: node.floor, head: head, surface: ground.y, snake: snake,
                                             from: eye, margin: margin,
                                             visibilityRadius: world.configurations.view.visibilityRadius)
                let cut = slabs.intersection(holes.keys)
                XCTAssertTrue(cut.isEmpty, "head at \(node), yaw \(eighth)/8 cuts ground slabs \(cut.sorted())")
                let lids = slabs.filter { boxes[$0].level > node.floor }
                XCTAssertTrue(lids.isEmpty, "head at \(node) fades ground slabs \(lids.sorted())")
            }
        }
        XCTAssertGreaterThan(heads, 0)
    }
}
