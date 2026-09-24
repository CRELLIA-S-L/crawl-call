// Every error the game can report opens its line with the identifier of its kind,
// a colon and a space (FR-TOOL-200) — checked over one error of every kind the game
// has, so that a kind added without an identifier, or an error type that writes its
// own line, fails here rather than on the launch screen.
//
// verifies: FR-TOOL-200
import XCTest
@testable import CrawlCall

final class ErrorIdentifierTests: XCTestCase {
    private struct Underlying: Error {}

    /// One error of every kind, from every error type the game declares. A new case
    /// in any of them is a kind this list has to learn, which is the point of keeping
    /// the list complete: `testEveryKindInTheCatalogueIsRaisedBySomeError` fails until
    /// it does.
    private var everyKind: [IdentifiedError] {
        let schema = SchemaError.unknownKey("speed", path: "abilities")
        let mapParse: [MapParseError] = [
            .noKit, .noFloors, .repeatedKit(line: 3), .unknownDirective("lift", line: 4),
            .gridBeforeAnyFloor(line: 5), .repeatedFloor(1, line: 6), .badFloorNumber("x", line: 7),
            .badTransition("transition 1", line: 8), .transitionToUnknownFloor(9, line: 9),
            .raggedGrid(floor: 0, line: 10, expected: 4, found: 3),
            .unknownCharacter("?", floor: 0, line: 11, column: 2), .emptyFloor(2, line: 12),
        ]
        let kit: [Kit.KitError] = [
            .missing(name: "blockout"), .legendKeyIsNotOneCharacter("##"),
            .moduleFieldIsNotThreeNumbers(module: "# (wall)", field: "size"),
        ]
        let schemaErrors: [SchemaError] = [
            .notAnObject(path: ""), schema, .missingKey("speed", path: "abilities"),
            .wrongKind(path: "list", expected: "an array"),
        ]
        let configuration: [ConfigurationError] = [
            .fileMissing(name: "snake"), .notJSON(name: "snake", underlying: Underlying()),
            .badShape(name: "snake", error: schema), .undecodable(name: "snake", underlying: Underlying()),
        ]
        let mapLoad: [MapLoadError] = [
            .missing(name: "blockout"), .unreadable(name: "blockout", underlying: Underlying()),
        ]
        return mapParse + kit + schemaErrors + configuration + mapLoad
    }

    func testEveryErrorLineOpensWithItsIdentifierAColonAndASpace() {
        for error in everyKind {
            let line = String(describing: error)
            XCTAssertTrue(line.hasPrefix(error.identifier.rawValue + ": "),
                          "\(line) does not open with \(error.identifier.rawValue): ")
            // The message follows the identifier and is not empty: an identifier alone
            // says what kind of thing went wrong and not what.
            XCTAssertFalse(line.dropFirst(error.identifier.rawValue.count + 2).isEmpty, line)
        }
    }

    func testTheErrorLineIsWhatTheLaunchScreenShows() {
        // The launch screen prints `String(describing:)` of whatever failed; an error
        // reached as a plain `Error` must still print its identified line.
        let error: Error = MapLoadError.missing(name: "blockout")
        XCTAssertEqual(String(describing: error), "MAP_MISSING: maps/blockout.map is missing from the bundle")
    }

    func testEveryKindHasAnIdentifierOfItsOwn() {
        // Kinds, not error values: two errors of one kind share an identifier, two
        // kinds never do.
        let identifiers = everyKind.map(\.identifier)
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
    }

    func testEveryKindInTheCatalogueIsRaisedBySomeError() {
        XCTAssertEqual(Set(everyKind.map(\.identifier)), Set(ErrorIdentifier.allCases))
    }

    func testIdentifiersAreUpperCaseWordsJoinedByUnderscores() {
        let shape = try! NSRegularExpression(pattern: "^[A-Z]+(_[A-Z]+)*$")
        for identifier in ErrorIdentifier.allCases {
            let raw = identifier.rawValue
            let range = NSRange(raw.startIndex..., in: raw)
            XCTAssertNotNil(shape.firstMatch(in: raw, range: range), raw)
        }
    }

    func testAMapThatNamesTheKitTwiceSaysSoByItsIdentifier() throws {
        // End to end through the parser: the identifier comes from a real failure,
        // not only from a hand-built value.
        let kit = try JSONDecoder().decode(Kit.self, from: Data("""
            {"floorHeight": 3, "floorModule": ".",
             "modules": {".": {"name": "floor", "walkable": true, "size": [1, 0.1, 1], "colour": [1, 1, 1]}}}
            """.utf8))
        XCTAssertThrowsError(try MapParser.parse("kit a\nkit b\nfloor 0\n.\n", kit: kit)) { error in
            XCTAssertTrue(String(describing: error).hasPrefix("MAP_REPEATED_KIT: line 2"), "\(error)")
        }
    }
}
