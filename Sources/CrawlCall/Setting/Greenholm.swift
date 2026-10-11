// Greenholm, the first setting (FR-GREENHOLM-010): the map's ground as a grassy
// island, its edge a shore along the map's outline, rounded (FR-MAP-200), and open
// water out to the edge of all the match camera can show (FR-MAP-140), under a
// daylight sky (FR-GREENHOLM-020), with birds now and then (FR-GREENHOLM-030). Trees
// and shrubs are the map's modules now, not a ring of scenery (FR-MAP-210, ADR-0034).
// Laid out here as parts and surfaces; built in `SceneryBuilder`.
//
// file implements: FR-GREENHOLM-010, FR-GREENHOLM-020, FR-GREENHOLM-030, FR-GREENHOLM-050, FR-GREENHOLM-060, FR-GREENHOLM-070, FR-MAP-130, FR-MAP-140, FR-MAP-170, FR-MAP-200, FR-MAP-260, FR-MAP-270, FR-MAP-280
import Foundation

enum Greenholm {
    /// The island's scenery, drawn along the edge it is given rather than one it works
    /// out for itself: where the ground ends is what play reads (FR-MAP-200), so it is
    /// computed by the part that owns it and handed here (ADR-0073).
    static func scenery(around plan: ScenePlan, camera: CameraRange, edge outline: Outline?,
                        configuration c: GreenholmConfiguration) throws -> Scenery {
        let arena = plan.bounds
        // The island's ground lies just under the surface of floor 0, the ground
        // (FR-MAP-170): the map's own ground is cells, drawn one by one, and between
        // them the island shows through — at their height, and not a slab lower, where
        // it read as a dark line along every cell.
        let ground = Double(plan.groundLevel ?? .zero) * plan.floorHeight - MapGrid.surfaceOverlap
        let shore = ground - c.shoreDrop
        let water = ground - c.waterDrop
        let bottom = water - IslandShape.submerged
        // The floor under the water (FR-MAP-270): just under it at the shore, falling
        // to its depth. It is seen through the water and lies lower, where every ray
        // from the camera meets it further along than it met the water, so what the
        // camera shows of it is worked out at its own depth.
        let floorTop = water - IslandShape.floorUnderSurface
        let floorBottom = water - max(c.floorDepth, IslandShape.floorUnderSurface)
        guard let covered = FrameCoverage.covered(arena: arena, camera: camera, surface: water),
              let coveredFloor = FrameCoverage.covered(arena: arena, camera: camera, surface: floorBottom) else {
            throw CoverageError.horizonInFrame(fieldOfView: camera.fieldOfView,
                                               lowestPitch: camera.pitches.lowerBound)
        }

        var parts: [Scenery.Part] = []
        var surfaces: [Scenery.Surface] = []
        var patch = GroundRect(lowest: covered.lowest, highest: covered.lowest)
        if let outline {
            let grid = outline.grid
            surfaces.append(.init(layer: .ground, colour: c.grassColour.rgb,
                                  mesh: Outline.surface(where: outline.region(atLeast: .zero, sparingBasements: true),
                                                        on: grid, height: ground)))
            surfaces.append(.init(layer: .ground, colour: c.grassColour.rgb,
                                  mesh: Outline.wall(along: outline.signed, on: grid, top: ground, bottom: shore)))
            surfaces.append(.init(layer: .ground, colour: c.shoreColour.rgb,
                                  mesh: Outline.surface(where: outline.region(atLeast: -c.shoreWidth, sparingBasements: true),
                                                        on: grid, height: shore)))
            surfaces.append(.init(layer: .ground, colour: c.shoreColour.rgb,
                                  mesh: Outline.wall(along: outline.signed.map { $0 + c.shoreWidth }, on: grid,
                                                     top: shore, bottom: bottom)))
            // The floor, from the shore's colour at its edge towards its own at depth;
            // what makes the shallows shallow (FR-MAP-270).
            surfaces.append(.init(layer: .floor, colour: c.shoreColour.rgb,
                                  mesh: Outline.floor(under: outline, edge: c.shoreWidth, width: c.floorWidth,
                                                      top: floorTop, bottom: floorBottom,
                                                      stride: Int((IslandShape.floorStep / grid.step).rounded()))))
            // The water near the island is cut to its shore, so that it never runs
            // under the island — where a basement is (FR-MAP-170): foam along the
            // shore (FR-GREENHOLM-050), and the water beyond it.
            let foam = c.shoreWidth + max(c.foamWidth, .zero)
            surfaces.append(.init(layer: .water, colour: c.foamColour.rgb,
                                  mesh: Outline.surface(where: outline.signed.map { min(-($0 + c.shoreWidth), $0 + foam) },
                                                        on: grid, height: water)))
            surfaces.append(.init(layer: .water, colour: c.waterColour.rgb,
                                  mesh: Outline.surface(where: outline.signed.map { -($0 + foam) },
                                                        on: grid, height: water)))
            let far = grid.point(grid.width - Distances.oneMore, grid.height - Distances.oneMore)
            patch = GroundRect(lowest: grid.origin, highest: far)
        }
        // The rest of the water, out to all the camera can show: the covered ground
        // less the patch, in as many as four slabs round it (FR-MAP-140); and the
        // floor under it at its full depth, out to the floor's own coverage
        // (FR-MAP-270). Both are drawn by their tops alone.
        for (layer, rects, height, colour) in [(Scenery.Part.Layer.water, covered.around(patch), water, c.waterColour.rgb),
                                               (.floor, coveredFloor.around(patch), floorBottom, c.floorColour.rgb)] {
            for rect in rects {
                let size = rect.highest - rect.lowest
                let centre = (rect.highest + rect.lowest) * Geometry.half
                parts.append(.init(shape: .box, layer: layer,
                                   size: SIMD3(size.x, IslandShape.waterDepth, size.y),
                                   centre: SIMD3(centre.x, height - IslandShape.waterDepth * Geometry.half, centre.y),
                                   colour: colour))
            }
        }

        let birds = Birds(interval: c.birdInterval, count: c.birdCount, speed: c.birdSpeed,
                          size: c.birdSize, wingbeats: c.birdWingbeats, colour: c.birdColour.rgb,
                          height: arena.highest.y + c.birdHeight, camera: camera,
                          seen: arena.extent.z * Geometry.half)
        return Scenery(parts: parts, surfaces: surfaces, covered: covered, surface: water,
                       sky: .init(zenith: c.skyZenithColour.rgb, horizon: c.skyHorizonColour.rgb),
                       birds: birds, waterRoughness: c.waterRoughness,
                       waterSpecular: c.waterSpecular, waterOpacity: c.waterOpacity,
                       floorColour: c.floorColour.rgb,
                       ripple: .init(wavelength: c.rippleWavelength, speedShare: c.rippleSpeedShare,
                                     strength: c.rippleStrength, slope: c.rippleSlope))
    }

}

extension Setting {
    /// The scenery the setting draws around an arena, for a camera that can take any
    /// of the range given (FR-MAP-140).
    ///
    /// The dispatch lives with the scenery rather than with the setting's own file,
    /// because what a setting *is* — its name, its configuration and where its ground
    /// ends — is read by play, while what it draws is read by nothing below the view
    /// (FR-MAP-130, ADR-0073).
    func scenery(around plan: ScenePlan, camera: CameraRange) throws -> Scenery {
        switch self {
        case .greenholm(let configuration):
            return try Greenholm.scenery(around: plan, camera: camera, edge: edge(around: plan),
                                         configuration: configuration)
        }
    }
}
