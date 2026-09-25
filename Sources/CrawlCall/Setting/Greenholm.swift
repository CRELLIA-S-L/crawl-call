// Greenholm, the first setting (FR-GREENHOLM-010): the arena on a grassy island
// ringed by trees and shrubs, a shore, and water out to the edge of all the match
// camera can show (FR-MAP-140), under a daylight sky (FR-GREENHOLM-020), with birds
// now and then (FR-GREENHOLM-030). Laid out here as parts; built in `SceneryBuilder`.
//
// implements: FR-GREENHOLM-010, FR-GREENHOLM-020, FR-GREENHOLM-030, FR-MAP-130, FR-MAP-140
import Foundation

enum Greenholm {
    static func scenery(around plan: ScenePlan, camera: CameraRange,
                        configuration c: GreenholmConfiguration) throws -> Scenery {
        let arena = plan.bounds
        let centre = arena.centre
        // The island's grass is level with the underside of the arena's lowest floor, so
        // the arena stands on it like a diorama on its base.
        let ground = plan.underside
        let shore = ground - c.shoreDrop
        let water = ground - c.waterDrop
        let bottom = water - IslandShape.submerged
        guard let covered = FrameCoverage.covered(arena: arena, camera: camera, surface: water) else {
            throw CoverageError.horizonInFrame(fieldOfView: camera.fieldOfView,
                                               lowestPitch: camera.pitches.lowerBound)
        }

        // The grass: the smallest ellipse round the arena, grown by the margin.
        let halfX = arena.extent.x * Geometry.half * IslandShape.circumscribing + c.islandMargin
        let halfZ = arena.extent.z * Geometry.half * IslandShape.circumscribing + c.islandMargin
        var parts: [Scenery.Part] = []
        parts.append(.init(shape: .cylinder, layer: .ground,
                           size: SIMD3(halfX * Geometry.bothSides, ground - bottom, halfZ * Geometry.bothSides),
                           centre: SIMD3(centre.x, (ground + bottom) * Geometry.half, centre.z),
                           colour: c.grassColour.rgb))
        parts.append(.init(shape: .cylinder, layer: .ground,
                           size: SIMD3((halfX + c.shoreWidth) * Geometry.bothSides, shore - bottom,
                                       (halfZ + c.shoreWidth) * Geometry.bothSides),
                           centre: SIMD3(centre.x, (shore + bottom) * Geometry.half, centre.z),
                           colour: c.shoreColour.rgb))
        let waterSize = covered.highest - covered.lowest
        let waterCentre = (covered.highest + covered.lowest) * Geometry.half
        parts.append(.init(shape: .box, layer: .water,
                           size: SIMD3(waterSize.x, IslandShape.waterDepth, waterSize.y),
                           centre: SIMD3(waterCentre.x, water - IslandShape.waterDepth * Geometry.half, waterCentre.y),
                           colour: c.waterColour.rgb))

        parts += rim(around: arena, ringX: halfX - c.rimInset, ringZ: halfZ - c.rimInset,
                     ground: ground, camera: camera, configuration: c)

        // Birds fly above all the arena holds, on lines chosen as each flight starts from
        // where the camera then looks (`Birds`), seen crossing within half the arena's
        // depth of it.
        let birds = Birds(interval: c.birdInterval, count: c.birdCount, speed: c.birdSpeed,
                          size: c.birdSize, wingbeats: c.birdWingbeats, colour: c.birdColour.rgb,
                          height: arena.highest.y + c.birdHeight, camera: camera,
                          seen: arena.extent.z * Geometry.half)
        return Scenery(parts: parts, covered: covered, surface: water,
                       sky: .init(zenith: c.skyZenithColour.rgb, horizon: c.skyHorizonColour.rgb),
                       birds: birds)
    }

    /// The ring of trees and shrubs on an ellipse round the arena. Nothing is placed
    /// over the arena, and in front of it — between it and the camera — nothing taller
    /// than `FrameCoverage.tallestInFront` allows at its distance: a tree there becomes
    /// a shrub, and a shrub that would still hide the arena is left out (ADR-0031).
    static func rim(around arena: ScenePlan.Bounds, ringX: Double, ringZ: Double, ground: Double,
                    camera: CameraRange, configuration c: GreenholmConfiguration) -> [Scenery.Part] {
        let centre = arena.centre
        // Ramanujan's approximation of an ellipse's perimeter; the spacing is a look,
        // so an approximation is all it needs.
        let sum = ringX + ringZ
        let h = (ringX - ringZ) * (ringX - ringZ) / (sum * sum)
        let perimeter = Double.pi * sum * (Fraction.whole + Ramanujan.a * h
                                           / (Ramanujan.b + (Ramanujan.c - Ramanujan.a * h).squareRoot()))
        let trees = max(IslandShape.fewestRimTrees, Int((perimeter / c.rimSpacing).rounded(.down)))
        let step = Geometry.bothSides * .pi / Double(trees)
        var parts: [Scenery.Part] = []
        for index in Int.zero..<trees {
            let scale = c.treeScales.isEmpty ? Fraction.whole : c.treeScales[index % c.treeScales.count]
            for (angle, isTree) in [(Double(index) * step, true),
                                    ((Double(index) + IslandShape.shrubOffset) * step, false)] {
                let x = centre.x + ringX * cos(angle)
                let z = centre.z + ringZ * sin(angle)
                let tree = tree(at: SIMD2(x, z), ground: ground, scale: scale, configuration: c)
                let shrub = [self.shrub(at: SIMD2(x, z), ground: ground, configuration: c)]
                for candidate in isTree ? [tree, shrub] : [shrub] {
                    if fits(candidate, around: arena, standingAt: ground, camera: camera) {
                        parts += candidate
                        break
                    }
                }
            }
        }
        return parts
    }

    /// A trunk with a cone of a crown on it.
    static func tree(at point: SIMD2<Double>, ground: Double, scale: Double,
                     configuration c: GreenholmConfiguration) -> [Scenery.Part] {
        let trunk = c.trunkHeight * scale
        let crown = c.crownHeight * scale
        let trunkWidth = c.trunkRadius * scale * Geometry.bothSides
        let crownWidth = c.crownRadius * scale * Geometry.bothSides
        return [
            .init(shape: .cylinder, layer: .rim, size: SIMD3(trunkWidth, trunk, trunkWidth),
                  centre: SIMD3(point.x, ground + trunk * Geometry.half, point.y), colour: c.trunkColour.rgb),
            .init(shape: .cone, layer: .rim, size: SIMD3(crownWidth, crown, crownWidth),
                  centre: SIMD3(point.x, ground + trunk + crown * Geometry.half, point.y), colour: c.crownColour.rgb),
        ]
    }

    /// A sphere flattened to a mound.
    static func shrub(at point: SIMD2<Double>, ground: Double,
                      configuration c: GreenholmConfiguration) -> Scenery.Part {
        let width = c.shrubRadius * Geometry.bothSides
        return .init(shape: .sphere, layer: .rim, size: SIMD3(width, c.shrubHeight, width),
                     centre: SIMD3(point.x, ground + c.shrubHeight * Geometry.half, point.y),
                     colour: c.shrubColour.rgb)
    }

    /// Whether a thing of these parts stands clear of the arena: not over it, and not
    /// tall enough in front of it to hide any of it from the match camera.
    static func fits(_ parts: [Scenery.Part], around arena: ScenePlan.Bounds, standingAt ground: Double,
                     camera: CameraRange) -> Bool {
        guard let first = parts.first else { return false }
        var low = first.lowest
        var high = first.highest
        for part in parts.dropFirst() {
            low = pointwiseMin(low, part.lowest)
            high = pointwiseMax(high, part.highest)
        }
        let overArenaX = high.x > arena.lowest.x && low.x < arena.highest.x
        let overArenaZ = high.z > arena.lowest.z && low.z < arena.highest.z
        if overArenaX && overArenaZ { return false }
        // Only what stands in the arena's own columns and in front of it can come
        // between the camera and the arena (`FrameCoverage.tallestInFront`).
        guard overArenaX, low.z >= arena.highest.z else { return true }
        let allowed = FrameCoverage.tallestInFront(gap: low.z - arena.highest.z, camera: camera)
        return high.y - ground <= allowed
    }
}
