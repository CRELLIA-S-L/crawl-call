// The shape check ADR-0012 asks for: an unknown key is an error, not a silent default.
//
// file verifies: IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010
import XCTest
@testable import CrawlCall

final class SchemaTests: XCTestCase {
    private let shape = Schema.object([
        "speed": .value,
        "limits": .object(["lowest": .value, "highest": .value]),
        "perName": .named(of: .object(["amount": .value])),
        "list": .array(of: .value),
    ])

    private func json(_ text: String) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(text.utf8))
    }

    private let good = """
    {"speed": 1, "limits": {"lowest": 0, "highest": 2},
     "perName": {"anything": {"amount": 3}}, "list": [1, 2]}
    """

    func testAConformingObjectPasses() throws {
        XCTAssertNoThrow(try shape.check(try json(good)))
    }

    func testAnUnknownTopLevelKeyIsRejectedByName() throws {
        let text = good.replacingOccurrences(of: "\"speed\": 1", with: "\"speed\": 1, \"speeed\": 1")
        XCTAssertThrowsError(try shape.check(try json(text))) { error in
            XCTAssertEqual(error as? SchemaError, .unknownKey("speeed", path: ""))
        }
    }

    func testAnUnknownNestedKeyNamesItsPath() throws {
        let text = good.replacingOccurrences(of: "\"lowest\": 0", with: "\"lowest\": 0, \"lowset\": 0")
        XCTAssertThrowsError(try shape.check(try json(text))) { error in
            XCTAssertEqual(error as? SchemaError, .unknownKey("lowset", path: "limits"))
        }
    }

    func testAMissingKeyIsRejectedByName() throws {
        let text = good.replacingOccurrences(of: "\"speed\": 1,", with: "")
        XCTAssertThrowsError(try shape.check(try json(text))) { error in
            XCTAssertEqual(error as? SchemaError, .missingKey("speed", path: ""))
        }
    }

    func testNamedSectionsAcceptAnyNameButNotAnyShape() throws {
        let renamed = good.replacingOccurrences(of: "\"anything\"", with: "\"something-else\"")
        XCTAssertNoThrow(try shape.check(try json(renamed)))

        let wrong = good.replacingOccurrences(of: "{\"amount\": 3}", with: "{\"amont\": 3}")
        XCTAssertThrowsError(try shape.check(try json(wrong))) { error in
            XCTAssertEqual(error as? SchemaError, .unknownKey("amont", path: "perName.anything"))
        }
    }

    func testAnArrayIsRequiredWhereTheShapeSaysArray() throws {
        let text = good.replacingOccurrences(of: "\"list\": [1, 2]", with: "\"list\": 1")
        XCTAssertThrowsError(try shape.check(try json(text))) { error in
            XCTAssertEqual(error as? SchemaError, .wrongKind(path: "list", expected: "an array"))
        }
    }

    func testAScalarWhereAnObjectBelongsIsRejected() throws {
        let text = good.replacingOccurrences(of: "{\"lowest\": 0, \"highest\": 2}", with: "7")
        XCTAssertThrowsError(try shape.check(try json(text))) { error in
            XCTAssertEqual(error as? SchemaError, .notAnObject(path: "limits"))
        }
    }
}
