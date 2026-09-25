// The Greenholm configuration (IF-GREENHOLM-010): what the island looks like, read
// from `config/setting/greenholm.json` when a map that stands on it is loaded. Its
// numbers are taste, settled by eye on the phone, so none of them is in code (ART-070).
//
// implements: IF-GREENHOLM-010
import Foundation

struct GreenholmConfiguration: Decodable, Equatable {
    typealias Colour = ViewConfiguration.Colour

    /// Metres of grass beyond the smallest ellipse round the arena.
    let islandMargin: Double
    /// Metres of shore beyond the grass, and how far below the grass it lies.
    let shoreWidth: Double
    let shoreDrop: Double
    /// Metres from the grass down to the water.
    let waterDrop: Double
    /// Metres along the rim from one tree to the next, and how far inside the grass's
    /// edge the rim stands.
    let rimSpacing: Double
    let rimInset: Double
    /// A tree: a trunk and a cone of a crown, in metres, before its scale.
    let trunkHeight: Double
    let trunkRadius: Double
    let crownHeight: Double
    let crownRadius: Double
    /// A shrub: a sphere flattened to this height, in metres.
    let shrubRadius: Double
    let shrubHeight: Double
    /// The scales the rim's trees are drawn at, taken in turn, so that the ring does not
    /// read as one tree repeated.
    let treeScales: [Double]
    let grassColour: Colour
    let shoreColour: Colour
    let waterColour: Colour
    let trunkColour: Colour
    let crownColour: Colour
    let shrubColour: Colour
    /// The sky, straight up and at the horizon (FR-GREENHOLM-020).
    let skyZenithColour: Colour
    let skyHorizonColour: Colour
    /// Birds (FR-GREENHOLM-030): seconds from one flight to the next, how many fly
    /// together, metres a second, metres above the arena's top, a bird's length in
    /// metres, and wingbeats a second.
    let birdInterval: Double
    let birdCount: Int
    let birdSpeed: Double
    let birdHeight: Double
    let birdSize: Double
    let birdWingbeats: Double
    let birdColour: Colour

    static let schema: Schema = {
        let colour = Schema.object(["red": .value, "green": .value, "blue": .value])
        return Schema.object([
            "islandMargin": .value, "shoreWidth": .value, "shoreDrop": .value, "waterDrop": .value,
            "rimSpacing": .value, "rimInset": .value,
            "trunkHeight": .value, "trunkRadius": .value, "crownHeight": .value, "crownRadius": .value,
            "shrubRadius": .value, "shrubHeight": .value, "treeScales": .array(of: .value),
            "grassColour": colour, "shoreColour": colour, "waterColour": colour,
            "trunkColour": colour, "crownColour": colour, "shrubColour": colour,
            "skyZenithColour": colour, "skyHorizonColour": colour,
            "birdInterval": .value, "birdCount": .value, "birdSpeed": .value, "birdHeight": .value,
            "birdSize": .value, "birdWingbeats": .value, "birdColour": colour,
        ])
    }()
}

extension ViewConfiguration.Colour {
    /// Red, green and blue as one value, as the scene's parts carry them.
    var rgb: SIMD3<Double> { SIMD3(red, green, blue) }
}
