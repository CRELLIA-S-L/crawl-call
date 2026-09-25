// The Greenholm configuration (IF-GREENHOLM-010): what the island looks like, read
// from `config/setting/greenholm.json` when a map that stands on it is loaded. Its
// numbers are taste, settled by eye on the phone, so none of them is in code (ART-070).
//
// implements: IF-GREENHOLM-010, FR-GREENHOLM-040, FR-GREENHOLM-050, FR-GREENHOLM-060, FR-GREENHOLM-070
import Foundation

struct GreenholmConfiguration: Decodable, Equatable {
    typealias Colour = ViewConfiguration.Colour

    /// Metres the island's edge lies beyond the map's outermost cells, and the radius
    /// its hollows are rounded with (FR-MAP-200).
    let edgeMargin: Double
    let edgeRounding: Double
    /// Metres of shore beyond the grass, and how far below the grass it lies.
    let shoreWidth: Double
    let shoreDrop: Double
    /// Metres from the grass down to the water.
    let waterDrop: Double
    let grassColour: Colour
    let shoreColour: Colour
    let waterColour: Colour
    /// The shallows (FR-GREENHOLM-040): metres beyond the shore they reach, in how
    /// many bands, and their colour at the shore; the last band is a step short of
    /// the water's colour.
    let shallowsWidth: Double
    let shallowsBands: Int
    let shallowsColour: Colour
    /// The foam along the shore (FR-GREENHOLM-050): metres wide, and its colour. The
    /// shallows begin where it ends.
    let foamWidth: Double
    let foamColour: Colour
    /// How rough the water is, 0 a mirror and 1 chalk, and how strongly it reflects,
    /// 0 not at all (FR-GREENHOLM-060).
    let waterRoughness: Double
    let waterSpecular: Double
    /// The waves and glints that move across the water (FR-GREENHOLM-070): metres
    /// from one wave to the next, metres a second, how far a glint lifts the colour
    /// towards white, 0 to 1, and how steep the waves are, as rise over run.
    let rippleWavelength: Double
    let rippleSpeed: Double
    let rippleStrength: Double
    let rippleSlope: Double
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
            "edgeMargin": .value, "edgeRounding": .value,
            "shoreWidth": .value, "shoreDrop": .value, "waterDrop": .value,
            "grassColour": colour, "shoreColour": colour, "waterColour": colour,
            "shallowsWidth": .value, "shallowsBands": .value, "shallowsColour": colour,
            "foamWidth": .value, "foamColour": colour, "waterRoughness": .value, "waterSpecular": .value,
            "rippleWavelength": .value, "rippleSpeed": .value, "rippleStrength": .value, "rippleSlope": .value,
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
