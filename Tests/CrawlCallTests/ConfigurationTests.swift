// Every configuration the game reads at start: the shipped file decodes, and a file
// with a typo in a key is refused rather than defaulted (ADR-0012).
//
// file verifies: IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010, INV-SNAKE-020
import XCTest
@testable import CrawlCall

final class ConfigurationTests: XCTestCase {
    /// The app bundle, which carries `config/` as shipped; the test bundle is hosted
    /// by the app, so this is the same file the game reads at start.
    private var shipped: Bundle { Bundle(for: ConfigurationTests.self).loadedAppBundle }

    // MARK: the files as shipped

    func testEveryShippedConfigurationLoads() throws {
        let all = try Configurations.load(from: shipped)
        XCTAssertGreaterThan(all.snake.baseSpeed, 0)
        XCTAssertGreaterThan(all.snake.startingSegmentCount, 0)
        XCTAssertGreaterThan(all.tuning.navigationGraphCellSize, 0)
        XCTAssertGreaterThan(all.bot.deliberationPeriod, 0)
        XCTAssertGreaterThan(all.match.squadSize, 0)
    }

    func testTheCameraPitchIsInsideTheRangeTheRequirementAllows() throws {
        // FR-VIEW-010: between 50 and 60 degrees below the horizontal.
        let view = try Configurations.load(from: shipped).view
        XCTAssertGreaterThanOrEqual(view.cameraPitch, 50)
        XCTAssertLessThanOrEqual(view.cameraPitch, 60)
    }

    func testTheSnakeIsSlowerThanEveryArchetypeThatRuns() throws {
        // INV-SNAKE-020, read off the files the game ships with.
        let all = try Configurations.load(from: shipped)
        let slowestRunner = all.bot.archetypes.values.map(\.runSpeed).min()
        XCTAssertNotNil(slowestRunner)
        XCTAssertLessThan(all.snake.baseSpeed, slowestRunner ?? 0)
    }

    func testTheCommanderIntervalIsInsideTheRangeTheRequirementFixes() throws {
        // FR-CMD-020: once per commander interval, between 5 and 10 seconds.
        let match = try Configurations.load(from: shipped).match
        XCTAssertGreaterThanOrEqual(match.commanderInterval, 5)
        XCTAssertLessThanOrEqual(match.commanderInterval, 10)
    }

    func testTheThermalThresholdIsAStateTheDeviceCanReport() throws {
        // A threshold the system never sees would switch degradation off silently.
        let match = try Configurations.load(from: shipped).match
        XCTAssertTrue(["nominal", "fair", "serious", "critical"].contains(match.thermalDegradationThreshold),
                      "\(match.thermalDegradationThreshold) is not a thermal state")
    }

    func testTheThermalThresholdIsStillTheDocumentedDefault() throws {
        // IF-BOT-010 defaults it to `serious` on ADR-0001's measurement. Changing the
        // shipped value is allowed — changing it without changing the requirement is
        // what this catches.
        let match = try Configurations.load(from: shipped).match
        XCTAssertEqual(match.thermalDegradationThreshold, "serious")
    }

    // MARK: a typo is an error

    private func snakeJSON() throws -> String {
        let url = try XCTUnwrap(shipped.url(forResource: "snake", withExtension: "json", subdirectory: "config"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testAnUnknownKeyInAShippedFileIsRefused() throws {
        let text = try snakeJSON().replacingOccurrences(of: "\"baseSpeed\"", with: "\"baseSped\"")
        XCTAssertThrowsError(try Configurations.decode(SnakeConfiguration.self, named: "snake",
                                                       schema: SnakeConfiguration.schema,
                                                       from: Data(text.utf8))) { error in
            guard case ConfigurationError.badShape(_, let shape)? = error as? ConfigurationError else {
                return XCTFail("expected a shape error, got \(error)")
            }
            XCTAssertEqual(shape, .unknownKey("baseSped", path: ""))
        }
    }

    func testAKeyRemovedFromAShippedFileIsRefused() throws {
        let text = try snakeJSON().replacingOccurrences(of: "\"damagePerSegment\": 10,", with: "")
        XCTAssertThrowsError(try Configurations.decode(SnakeConfiguration.self, named: "snake",
                                                       schema: SnakeConfiguration.schema,
                                                       from: Data(text.utf8))) { error in
            guard case ConfigurationError.badShape(_, let shape)? = error as? ConfigurationError else {
                return XCTFail("expected a shape error, got \(error)")
            }
            XCTAssertEqual(shape, .missingKey("damagePerSegment", path: ""))
        }
    }

    func testABotConfigurationWithoutTheFiguresHeightOrItsEyesIsRefused() throws {
        // The size a bot is drawn at and where it looks from are configuration and
        // nothing else (IF-BOT-010, ADR-0022): without them the file does not load,
        // rather than falling back on a number kept somewhere in the code.
        let url = try XCTUnwrap(shipped.url(forResource: "bot", withExtension: "json", subdirectory: "config"))
        let full = try XCTUnwrap(JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as? [String: Any])
        for key in ["figureHeight", "eyeHeight"] {
            var json = full
            XCTAssertNotNil(json.removeValue(forKey: key), "the shipped file has no \(key), so this proves nothing")
            XCTAssertThrowsError(try Configurations.decode(BotConfiguration.self, named: "bot",
                                                           schema: BotConfiguration.schema,
                                                           from: JSONSerialization.data(withJSONObject: json))) { error in
                guard case ConfigurationError.badShape(_, let shape)? = error as? ConfigurationError else {
                    return XCTFail("expected a shape error, got \(error)")
                }
                XCTAssertEqual(shape, .missingKey(key, path: ""))
            }
        }
    }

    func testTextThatIsNotJSONIsRefusedAsSuch() {
        XCTAssertThrowsError(try Configurations.decode(ViewConfiguration.self, named: "view",
                                                       schema: ViewConfiguration.schema,
                                                       from: Data("{ not json".utf8))) { error in
            guard case ConfigurationError.notJSON? = error as? ConfigurationError else {
                return XCTFail("expected a JSON error, got \(error)")
            }
        }
    }

    func testAFileWhoseTopLevelIsAnArrayIsRefusedAsAShape() {
        // JSONSerialization accepts an array at the top level — only a bare scalar is
        // refused without `fragmentsAllowed`, which this call does not pass — so the
        // shape check is what has to catch this one.
        XCTAssertThrowsError(try Configurations.decode(ViewConfiguration.self, named: "view",
                                                       schema: ViewConfiguration.schema,
                                                       from: Data("[1, 2]".utf8))) { error in
            guard case ConfigurationError.badShape(_, let shape)? = error as? ConfigurationError else {
                return XCTFail("expected a shape error, got \(error)")
            }
            XCTAssertEqual(shape, .notAnObject(path: ""))
        }
    }

    func testABareScalarIsRefusedBeforeTheShapeCheck() {
        // The other side of the same contract: no `fragmentsAllowed`, so the parser
        // rejects it and the error says "not JSON" rather than naming a key.
        XCTAssertThrowsError(try Configurations.decode(ViewConfiguration.self, named: "view",
                                                       schema: ViewConfiguration.schema,
                                                       from: Data("55".utf8))) { error in
            guard case ConfigurationError.notJSON? = error as? ConfigurationError else {
                return XCTFail("expected a JSON error, got \(error)")
            }
        }
    }

    func testAValueOfTheWrongTypeIsRefusedByTheDecoder() throws {
        let text = try snakeJSON().replacingOccurrences(of: "\"startingSegmentCount\": 6", with: "\"startingSegmentCount\": \"six\"")
        XCTAssertThrowsError(try Configurations.decode(SnakeConfiguration.self, named: "snake",
                                                       schema: SnakeConfiguration.schema,
                                                       from: Data(text.utf8))) { error in
            guard case ConfigurationError.undecodable? = error as? ConfigurationError else {
                return XCTFail("expected a decoding error, got \(error)")
            }
        }
    }

    func testAMissingFileIsNamedRatherThanCrashing() {
        XCTAssertThrowsError(try Configurations.load(from: Bundle(for: SchemaTests.self))) { error in
            guard case ConfigurationError.fileMissing? = error as? ConfigurationError else {
                return XCTFail("expected a missing-file error, got \(error)")
            }
        }
    }
}

private extension Bundle {
    /// The application bundle that hosts this test bundle.
    var loadedAppBundle: Bundle { Bundle.main }
}
