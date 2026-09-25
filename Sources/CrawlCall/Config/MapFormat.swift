// The words, separators and positions of the map file format (IF-MAP-010) and of a
// kit's legend (ADR-0012), named once for the parser and for its messages (ART-070).
//
// implements: IF-MAP-010, FR-MAP-120, FR-MAP-150, FR-MAP-180, FR-TOOL-010, FR-TOOL-020, FR-TOOL-030, FR-MAP-100, FR-SNAKE-220
import Foundation

enum MapFormat {
    /// The header's directives and the floor marker, each the first word of its line.
    static let kitDirective = "kit"
    static let settingDirective = "setting"
    static let spawnDirective = "spawn"
    static let transitionDirective = "transition"
    static let floorDirective = "floor"
    /// A whole line beginning with this is a comment.
    static let commentPrefix = ";"
    /// What separates the words of a directive.
    static let wordSeparator: Character = " "
    /// A grid cell holding no module.
    static let emptyCell: Character = " "
    /// A step of a flight of stairs, drawn as an arrow pointing the way the flight
    /// rises (IF-MAP-010, FR-MAP-150): up the page is towards −z, as rows count down.
    static let risesNorth: Character = "^"
    static let risesSouth: Character = "v"
    static let risesEast: Character = ">"
    static let risesWest: Character = "<"
    /// Which way on the grid each arrow rises, in cells along x and z.
    static let rises: [Character: (x: Int, z: Int)] = [
        risesNorth: (x: .zero, z: -MapGrid.neighbourStep),
        risesSouth: (x: .zero, z: MapGrid.neighbourStep),
        risesEast: (x: MapGrid.neighbourStep, z: .zero),
        risesWest: (x: -MapGrid.neighbourStep, z: .zero),
    ]
    /// The first step of a flight is its lowest, counted from one.
    static let firstStep = 1

    /// What separates a cell's x and z in `transition <x>,<z> <from> <to>`.
    static let coordinateSeparator: Character = ","

    /// What separates the names in a list a message gives.
    static let listSeparator = ", "

    /// Line endings: whatever a file was written with becomes `lineBreak`.
    static let lineBreak = "\n"
    static let windowsLineBreak = "\r\n"
    static let classicMacLineBreak = "\r"

    /// How many words each directive has, and where in it each argument stands.
    static let kitWords = 2
    static let kitNameWord = 1
    static let settingWords = 2
    static let settingNameWord = 1
    /// `spawn <x>,<z> <floor>`: a cell the snake may be born in (FR-MAP-180).
    static let spawnWords = 3
    static let spawnCellWord = 1
    static let spawnFloorWord = 2
    static let floorWords = 2
    static let floorLevelWord = 1
    static let transitionWords = 4
    static let transitionCellWord = 1
    static let transitionFromWord = 2
    static let transitionToWord = 3
    /// A cell is written `<x>,<z>`.
    static let coordinates = 2
    static let xCoordinate = 0
    static let zCoordinate = 1

    /// Lines and columns are counted from one, as an editor shows them.
    static let firstLine = 1
    static let firstColumn = 1

    /// A grid cell is one character, so a legend key is one character.
    static let charactersPerCell = 1

    /// The fields of a legend's module that must be three numbers each.
    static let moduleSize = "size"
    static let moduleColour = "colour"
}

/// Numbers of the map's grid and of the pieces it is built from (ART-070).
enum MapGrid {
    /// A neighbour on the same floor is one cell along x or along z (ADR-0016).
    static let neighbourStep = 1
    /// The graph keeps each edge at both of its ends, so counting the ends counts
    /// every edge this many times.
    static let endsPerEdge = 2
    /// How far a standing module is sunk into the surface it stands on, in metres.
    /// Small enough to be invisible at a cell of half a metre, large enough that no
    /// two faces end up in the same plane (FR-TOOL-020).
    static let surfaceOverlap = 0.01
}

extension MapGrid {
    /// Floors are numbered one apart: the floor below floor n is n − floorStep.
    static let floorStep = 1
    /// A walk over the graph counts one step for every neighbour it moves to.
    static let stepsPerNeighbour = 1
}
