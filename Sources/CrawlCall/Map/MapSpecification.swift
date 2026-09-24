// The map file, parsed. IF-MAP-010: one UTF-8 text file, a header naming the module
// kit and the transitions between floors, then one character grid per floor.
//
// FR-TOOL-010 asks for the placement of every module per floor, or a rejection that
// names the line and the reason — so every error below carries its line.
//
// implements: IF-MAP-010, FR-TOOL-010, FR-TOOL-200
import Foundation

struct MapSpecification: Equatable {
    /// A way between floors at one cell: stairs, a ramp, a drop.
    struct Transition: Equatable {
        let x: Int
        let z: Int
        let from: Int
        let to: Int
    }

    /// One module placed on one floor, at its cell.
    struct Placement: Equatable {
        let module: String
        let character: Character
        let walkable: Bool
        let floor: Int
        let x: Int
        let z: Int
    }

    let kit: String
    /// Floors in the order the file declares them, each with its grid rows.
    let floors: [(level: Int, rows: [String])]
    let transitions: [Transition]
    let placements: [Placement]

    static func == (a: MapSpecification, b: MapSpecification) -> Bool {
        a.kit == b.kit && a.transitions == b.transitions && a.placements == b.placements
            && a.floors.map(\.level) == b.floors.map(\.level)
            && a.floors.map(\.rows) == b.floors.map(\.rows)
    }
}

enum MapParseError: IdentifiedError, Equatable {
    case noKit
    case noFloors
    case repeatedKit(line: Int)
    case unknownDirective(String, line: Int)
    case gridBeforeAnyFloor(line: Int)
    case repeatedFloor(Int, line: Int)
    case badFloorNumber(String, line: Int)
    case badTransition(String, line: Int)
    case transitionToUnknownFloor(Int, line: Int)
    case raggedGrid(floor: Int, line: Int, expected: Int, found: Int)
    case unknownCharacter(Character, floor: Int, line: Int, column: Int)
    case emptyFloor(Int, line: Int)

    var identifier: ErrorIdentifier {
        switch self {
        case .noKit:                    return .mapNoKit
        case .noFloors:                 return .mapNoFloors
        case .repeatedKit:              return .mapRepeatedKit
        case .unknownDirective:         return .mapUnknownDirective
        case .gridBeforeAnyFloor:       return .mapGridBeforeAnyFloor
        case .repeatedFloor:            return .mapRepeatedFloor
        case .badFloorNumber:           return .mapBadFloorNumber
        case .badTransition:            return .mapBadTransition
        case .transitionToUnknownFloor: return .mapTransitionToUnknownFloor
        case .raggedGrid:               return .mapRaggedGrid
        case .unknownCharacter:         return .mapUnknownCharacter
        case .emptyFloor:               return .mapEmptyFloor
        }
    }

    var details: String {
        switch self {
        case .noKit:
            return "the file names no kit; a map needs `kit <name>` before its floors"
        case .noFloors:
            return "the file has no floors"
        case .repeatedKit(let l):
            return "line \(l): the kit is named twice; a map is assembled from one kit"
        case .unknownDirective(let d, let l):
            return "line \(l): '\(d)' is not `kit`, `transition` or `floor`"
        case .gridBeforeAnyFloor(let l):
            return "line \(l): a grid row before any `floor` line"
        case .repeatedFloor(let f, let l):
            return "line \(l): floor \(f) is declared twice"
        case .badFloorNumber(let t, let l):
            return "line \(l): '\(t)' is not a floor number"
        case .badTransition(let t, let l):
            return "line \(l): '\(t)' is not `transition <x>,<z> <from> <to>`"
        case .transitionToUnknownFloor(let f, let l):
            return "line \(l): the transition names floor \(f), which the file does not declare"
        case .raggedGrid(let f, let l, let e, let g):
            return "line \(l): floor \(f) is \(e) cells wide here and \(g) on this row"
        case .unknownCharacter(let c, let f, let l, let col):
            return "line \(l), column \(col): floor \(f) uses '\(c)', which the kit's legend does not name"
        case .emptyFloor(let f, let l):
            return "line \(l): floor \(f) has no grid under it"
        }
    }
}

enum MapParser {
    /// Splits a file into lines whatever it was written on.
    ///
    /// Swift's `Character` is an extended grapheme cluster, so in a file with Windows
    /// line endings `\r\n` is one character — and `split(separator: "\n")` finds no
    /// separator at all and hands back the whole file as a single line. Normalising
    /// first is what makes that impossible rather than merely unlikely.
    static func lines(of text: String) -> [Substring] {
        text
            .replacingOccurrences(of: MapFormat.windowsLineBreak, with: MapFormat.lineBreak)
            .replacingOccurrences(of: MapFormat.classicMacLineBreak, with: MapFormat.lineBreak)
            .split(separator: MapFormat.lineBreak, omittingEmptySubsequences: false)
    }

    /// Reads a map file against the kit it names. The kit comes from the caller
    /// because a map cannot be read without knowing which characters are legal —
    /// that is the disagreement ADR-0012's legend exists to prevent.
    static func parse(_ text: String, kit: Kit) throws -> MapSpecification {
        var kitName: String?
        var floors: [(level: Int, rows: [String])] = []
        var floorLine: [Int: Int] = [:]
        var transitions: [(MapSpecification.Transition, Int)] = []
        var current: Int?

        for (index, raw) in lines(of: text).enumerated() {
            let line = index + MapFormat.firstLine
            // A comment is a whole line beginning with `;`. It cannot be a trailing
            // one: `#` is the wall module and a trailing marker would eat a grid row,
            // and trailing spaces in a grid are cells, not whitespace to strip.
            let content = raw
            let trimmed = content.trimmingCharacters(in: .whitespaces)
            // A line with nothing on it separates sections. A line of spaces does not:
            // inside a grid those are cells with no module (IF-MAP-010), and trimming
            // them away would shorten the floor and move everything below it.
            if content.isEmpty || trimmed.hasPrefix(MapFormat.commentPrefix) { continue }
            if trimmed.isEmpty && current == nil { continue }

            let words = trimmed.split(separator: MapFormat.wordSeparator, omittingEmptySubsequences: true)
            switch words.first.map(String.init) {
            case MapFormat.kitDirective:
                guard kitName == nil else { throw MapParseError.repeatedKit(line: line) }
                guard words.count == MapFormat.kitWords else { throw MapParseError.unknownDirective(trimmed, line: line) }
                kitName = String(words[MapFormat.kitNameWord])
            case MapFormat.transitionDirective:
                guard words.count == MapFormat.transitionWords,
                      let cell = Self.cell(String(words[MapFormat.transitionCellWord])),
                      let from = Int(words[MapFormat.transitionFromWord]),
                      let to = Int(words[MapFormat.transitionToWord]) else {
                    throw MapParseError.badTransition(trimmed, line: line)
                }
                transitions.append((.init(x: cell.x, z: cell.z, from: from, to: to), line))
            case MapFormat.floorDirective:
                guard words.count == MapFormat.floorWords else { throw MapParseError.unknownDirective(trimmed, line: line) }
                guard let level = Int(words[MapFormat.floorLevelWord]) else {
                    throw MapParseError.badFloorNumber(String(words[MapFormat.floorLevelWord]), line: line)
                }
                guard floorLine[level] == nil else { throw MapParseError.repeatedFloor(level, line: line) }
                floorLine[level] = line
                floors.append((level: level, rows: []))
                current = floors.indices.last
            default:
                let row = String(content)
                // Where the line sits decides what it is. Before the first `floor` the
                // file is still its header, so an unknown word there is a directive
                // nobody knows — unless it would pass for a grid, which is the other
                // mistake worth naming precisely.
                guard let index = current else {
                    let looksLikeAGrid = row.allSatisfy { $0 == MapFormat.emptyCell || kit.module(for: $0) != nil }
                    throw looksLikeAGrid ? MapParseError.gridBeforeAnyFloor(line: line)
                                         : MapParseError.unknownDirective(trimmed, line: line)
                }
                let level = floors[index].level
                if let width = floors[index].rows.first?.count, width != row.count {
                    throw MapParseError.raggedGrid(floor: level, line: line,
                                                   expected: width, found: row.count)
                }
                // A space is empty space, not a module (IF-MAP-010), so the kit's
                // legend is not asked about it.
                for (column, character) in row.enumerated()
                where character != MapFormat.emptyCell && kit.module(for: character) == nil {
                    throw MapParseError.unknownCharacter(character, floor: level,
                                                         line: line, column: column + MapFormat.firstColumn)
                }
                floors[index].rows.append(row)
            }
        }

        guard let name = kitName else { throw MapParseError.noKit }
        guard !floors.isEmpty else { throw MapParseError.noFloors }
        for floor in floors where floor.rows.isEmpty {
            // Every floor was entered in `floorLine` when its line was read, so the
            // fallback is never taken; it is the line a message names when there is none.
            throw MapParseError.emptyFloor(floor.level, line: floorLine[floor.level] ?? .zero)
        }
        let levels = Set(floors.map(\.level))
        for (transition, line) in transitions {
            for level in [transition.from, transition.to] where !levels.contains(level) {
                throw MapParseError.transitionToUnknownFloor(level, line: line)
            }
        }

        var placements: [MapSpecification.Placement] = []
        for floor in floors {
            for (z, row) in floor.rows.enumerated() {
                for (x, character) in row.enumerated() {
                    // Empty space places nothing; the cell exists and holds no module.
                    guard character != MapFormat.emptyCell, let module = kit.module(for: character) else { continue }
                    placements.append(.init(module: module.name, character: character,
                                            walkable: module.walkable,
                                            floor: floor.level, x: x, z: z))
                }
            }
        }

        return MapSpecification(kit: name, floors: floors,
                                transitions: transitions.map(\.0), placements: placements)
    }

    /// The kit a map names, read without the kit — the one thing that can be known
    /// before the legend is in hand.
    static func kitName(in text: String) throws -> String {
        for (index, raw) in lines(of: text).enumerated() {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix(MapFormat.commentPrefix) { continue }
            let words = trimmed.split(separator: MapFormat.wordSeparator, omittingEmptySubsequences: true)
            let directive = words.first.map(String.init)
            if directive == MapFormat.kitDirective {
                guard words.count == MapFormat.kitWords else {
                    throw MapParseError.unknownDirective(trimmed, line: index + MapFormat.firstLine)
                }
                return String(words[MapFormat.kitNameWord])
            }
            if directive == MapFormat.floorDirective { break }
        }
        throw MapParseError.noKit
    }

    private static func cell(_ text: String) -> (x: Int, z: Int)? {
        let parts = text.split(separator: MapFormat.coordinateSeparator)
        guard parts.count == MapFormat.coordinates,
              let x = Int(parts[MapFormat.xCoordinate]), let z = Int(parts[MapFormat.zCoordinate]) else { return nil }
        return (x, z)
    }
}
