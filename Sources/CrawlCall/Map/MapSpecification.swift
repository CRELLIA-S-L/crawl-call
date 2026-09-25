// The map file, parsed. IF-MAP-010: one UTF-8 text file, a header naming the module
// kit, the setting and the transitions between floors, then one character grid per
// floor. The setting is the world the arena stands in (FR-MAP-120); the parser only
// reads its name, and whether the game provides it is asked when it is loaded.
//
// FR-TOOL-010 asks for the placement of every module per floor, or a rejection that
// names the line and the reason — so every error below carries its line.
//
// A flight of stairs is a run of arrows on one floor, each a step, rising the way the
// arrows point to the floor above (FR-MAP-150); one too steep to climb is refused
// here, where the map is read (FR-MAP-160, ADR-0033).
//
// implements: IF-MAP-010, FR-MAP-120, FR-MAP-150, FR-MAP-160, FR-TOOL-010, FR-TOOL-200
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
        /// Where the cell is a step of a flight of stairs, which step it is.
        var step: Step? = nil
    }

    /// A step of a flight: the `index`th from the bottom, counted from one, of `count`.
    struct Step: Equatable {
        let index: Int
        let count: Int
    }

    let kit: String
    /// Metres from one floor's walking surface to the next: the kit's (FR-MAP-100),
    /// carried so that how high a cell is can be read off the map alone.
    let floorHeight: Double
    /// The setting the arena stands in, by its name (FR-MAP-120).
    let setting: String
    /// Floors in the order the file declares them, each with its grid rows.
    let floors: [(level: Int, rows: [String])]
    let transitions: [Transition]
    let placements: [Placement]

    static func == (a: MapSpecification, b: MapSpecification) -> Bool {
        a.kit == b.kit && a.floorHeight == b.floorHeight && a.setting == b.setting && a.transitions == b.transitions && a.placements == b.placements
            && a.floors.map(\.level) == b.floors.map(\.level)
            && a.floors.map(\.rows) == b.floors.map(\.rows)
    }

    /// How high a placement's walking surface is, in metres: its floor's, and on a
    /// flight its share of the way to the floor above, in equal rises (FR-MAP-150).
    func height(of placement: Placement) -> Double {
        let floor = Double(placement.floor) * floorHeight
        guard let step = placement.step, step.count > .zero else { return floor }
        return floor + floorHeight * Double(step.index) / Double(step.count)
    }
}

enum MapParseError: IdentifiedError, Equatable {
    case noKit
    case noFloors
    case repeatedKit(line: Int)
    case noSetting
    case repeatedSetting(line: Int)
    case unknownDirective(String, line: Int)
    case gridBeforeAnyFloor(line: Int)
    case repeatedFloor(Int, line: Int)
    case badFloorNumber(String, line: Int)
    case badTransition(String, line: Int)
    case transitionToUnknownFloor(Int, line: Int)
    case raggedGrid(floor: Int, line: Int, expected: Int, found: Int)
    case unknownCharacter(Character, floor: Int, line: Int, column: Int)
    case emptyFloor(Int, line: Int)
    case flightLeadsNowhere(floor: Int, line: Int, column: Int)
    case flightTooSteep(line: Int, rise: Double, allowed: Double)

    var identifier: ErrorIdentifier {
        switch self {
        case .noKit:                    return .mapNoKit
        case .noFloors:                 return .mapNoFloors
        case .repeatedKit:              return .mapRepeatedKit
        case .noSetting:                return .mapNoSetting
        case .repeatedSetting:          return .mapRepeatedSetting
        case .unknownDirective:         return .mapUnknownDirective
        case .gridBeforeAnyFloor:       return .mapGridBeforeAnyFloor
        case .repeatedFloor:            return .mapRepeatedFloor
        case .badFloorNumber:           return .mapBadFloorNumber
        case .badTransition:            return .mapBadTransition
        case .transitionToUnknownFloor: return .mapTransitionToUnknownFloor
        case .raggedGrid:               return .mapRaggedGrid
        case .unknownCharacter:         return .mapUnknownCharacter
        case .emptyFloor:               return .mapEmptyFloor
        case .flightLeadsNowhere:       return .mapFlightLeadsNowhere
        case .flightTooSteep:           return .mapFlightTooSteep
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
        case .noSetting:
            return "the file names no setting; a map needs `setting <name>` before its floors"
        case .repeatedSetting(let l):
            return "line \(l): the setting is named twice; an arena stands in one setting"
        case .unknownDirective(let d, let l):
            return "line \(l): '\(d)' is not `kit`, `setting`, `transition` or `floor`"
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
        case .flightLeadsNowhere(let f, let l, let c):
            return "line \(l), column \(c): the flight on floor \(f) rises to a cell the floor above does not make walkable"
        case .flightTooSteep(let l, let r, let a):
            return "line \(l): the flight starting here would rise \(r) m a step, more than the \(a) m a step may"
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
    ///
    /// A flight whose steps would rise more than `stepHeight` is refused (FR-MAP-160);
    /// the step height is the tuning's, which the caller has and the map does not.
    static func parse(_ text: String, kit: Kit, stepHeight: Double = .infinity) throws -> MapSpecification {
        var kitName: String?
        var settingName: String?
        var floors: [(level: Int, rows: [String])] = []
        var floorLine: [Int: Int] = [:]
        // The line each grid row is on, by floor: a flight is refused by the line it
        // starts on.
        var rowLines: [Int: [Int]] = [:]
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
            case MapFormat.settingDirective:
                guard settingName == nil else { throw MapParseError.repeatedSetting(line: line) }
                guard words.count == MapFormat.settingWords else { throw MapParseError.unknownDirective(trimmed, line: line) }
                settingName = String(words[MapFormat.settingNameWord])
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
                    let looksLikeAGrid = row.allSatisfy {
                    $0 == MapFormat.emptyCell || MapFormat.rises[$0] != nil || kit.module(for: $0) != nil
                }
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
                // An arrow is a step, drawn as the kit's step module, so it is known
                // wherever the kit has one.
                for (column, character) in row.enumerated()
                where character != MapFormat.emptyCell && kit.module(for: character) == nil
                    && (MapFormat.rises[character] == nil || kit.step == nil) {
                    throw MapParseError.unknownCharacter(character, floor: level,
                                                         line: line, column: column + MapFormat.firstColumn)
                }
                floors[index].rows.append(row)
                rowLines[level, default: []].append(line)
            }
        }

        guard let name = kitName else { throw MapParseError.noKit }
        guard let setting = settingName else { throw MapParseError.noSetting }
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
            let steps = try flights(on: floor, lines: rowLines[floor.level] ?? [], among: floors,
                                    kit: kit, stepHeight: stepHeight)
            for (z, row) in floor.rows.enumerated() {
                for (x, character) in row.enumerated() {
                    // Empty space places nothing; the cell exists and holds no module.
                    guard character != MapFormat.emptyCell,
                          let module = MapFormat.rises[character] != nil ? kit.step : kit.module(for: character)
                    else { continue }
                    placements.append(.init(module: module.name, character: character,
                                            walkable: module.walkable,
                                            floor: floor.level, x: x, z: z,
                                            step: steps[GridCell(x: x, z: z)]))
                }
            }
        }

        return MapSpecification(kit: name, floorHeight: kit.floorHeight, setting: setting, floors: floors,
                                transitions: transitions.map(\.0), placements: placements)
    }

    private struct GridCell: Hashable {
        let x: Int
        let z: Int
    }

    /// The flights on one floor, as the step each arrow is. A flight is a run of the
    /// same arrow along the way it points; its first step is the one no arrow of the
    /// run leads up to, and its top step leads onto the cell beyond it on the floor
    /// above, which must be walkable there (FR-MAP-150). Its rise is the floor height
    /// shared over its steps, and more than a step may rise refuses the map (FR-MAP-160).
    private static func flights(on floor: (level: Int, rows: [String]), lines: [Int],
                                among floors: [(level: Int, rows: [String])], kit: Kit,
                                stepHeight: Double) throws -> [GridCell: MapSpecification.Step] {
        let rows = floor.rows.map(Array.init)
        func arrow(_ x: Int, _ z: Int) -> Character? {
            guard rows.indices.contains(z), rows[z].indices.contains(x), MapFormat.rises[rows[z][x]] != nil
            else { return nil }
            return rows[z][x]
        }
        let above = floors.first { $0.level == floor.level + MapGrid.floorStep }.map { $0.rows.map(Array.init) }
        func walkableAbove(_ x: Int, _ z: Int) -> Bool {
            guard let above, above.indices.contains(z), above[z].indices.contains(x) else { return false }
            let character = above[z][x]
            return MapFormat.rises[character] != nil || kit.module(for: character)?.walkable == true
        }
        var steps: [GridCell: MapSpecification.Step] = [:]
        for (z, row) in rows.enumerated() {
            for x in row.indices {
                guard let character = arrow(x, z), let way = MapFormat.rises[character],
                      arrow(x - way.x, z - way.z) != character else { continue }
                // The first step of a flight: walk up it to its top.
                var run: [GridCell] = []
                var cell = GridCell(x: x, z: z)
                while arrow(cell.x, cell.z) == character {
                    run.append(cell)
                    cell = GridCell(x: cell.x + way.x, z: cell.z + way.z)
                }
                let line = lines.indices.contains(z) ? lines[z] : .zero
                // The run holds the cell it started from, so it is never empty and the
                // fallback is the name of that cell rather than a case that happens.
                let top = run.last ?? GridCell(x: x, z: z)
                guard walkableAbove(cell.x, cell.z) else {
                    throw MapParseError.flightLeadsNowhere(floor: floor.level,
                                                          line: lines.indices.contains(top.z) ? lines[top.z] : .zero,
                                                          column: top.x + MapFormat.firstColumn)
                }
                let rise = kit.floorHeight / Double(run.count)
                guard rise <= stepHeight else {
                    throw MapParseError.flightTooSteep(line: line, rise: rise, allowed: stepHeight)
                }
                for (offset, step) in run.enumerated() {
                    steps[step] = MapSpecification.Step(index: offset + MapFormat.firstStep, count: run.count)
                }
            }
        }
        return steps
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
