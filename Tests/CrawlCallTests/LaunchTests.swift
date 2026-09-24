// "When the game starts, the system shall read…" — this is that moment, exercised
// the way the app exercises it.
//
// verifies: IF-SNAKE-010, IF-MAP-020, IF-VIEW-020, IF-BOT-010
import XCTest
@testable import CrawlCall

final class LaunchTests: XCTestCase {
    func testStartingWithTheShippedBundleReadsEveryConfiguration() throws {
        switch Launch.load(from: .main) {
        case .success(let all):
            // Each file contributed something, so none was skipped on the way.
            XCTAssertGreaterThan(all.snake.startingSegmentCount, 0)
            XCTAssertFalse(all.bot.archetypes.isEmpty)
            XCTAssertFalse(all.tuning.moduleDamageThresholds.isEmpty)
            XCTAssertGreaterThan(all.view.cameraPitch, 0)
            XCTAssertGreaterThan(all.match.commanderInterval, 0)
        case .failure(let error):
            XCTFail("the shipped bundle should start: \(error)")
        }
    }

    func testStartingWithoutTheFilesFailsAndNamesTheFirstMissingOne() {
        // The test bundle carries no `config/`, which is the "someone shipped a build
        // without its tuning" case.
        switch Launch.load(from: Bundle(for: LaunchTests.self)) {
        case .success:
            XCTFail("a bundle with no config/ must not start")
        case .failure(let error):
            guard case .fileMissing(let name) = error else {
                return XCTFail("expected a missing file, got \(error)")
            }
            XCTAssertEqual(name, "snake")
            XCTAssertTrue(error.description.contains("config/snake.json"))
        }
    }

    func testTheSameLoadTwiceGivesTheSameValues() throws {
        // Reading is not supposed to mutate anything; a second start sees what the
        // first one saw.
        let first = try Launch.load(from: .main).get()
        let second = try Launch.load(from: .main).get()
        XCTAssertEqual(first.snake, second.snake)
        XCTAssertEqual(first.tuning, second.tuning)
        XCTAssertEqual(first.view, second.view)
        XCTAssertEqual(first.bot, second.bot)
        XCTAssertEqual(first.match, second.match)
    }
}

/// The app itself, not just the function it calls: if the read is ever taken out of
/// the entry point, this file stops compiling and the suite goes red.
final class AppStartTests: XCTestCase {
    @MainActor
    func testStartingTheAppReadsTheConfigurations() {
        let app = SceneDelegate()
        guard case .success(let world) = app.world else {
            return XCTFail("the app did not read its world at start: \(app.world)")
        }
        XCTAssertGreaterThan(world.configurations.snake.baseSpeed, 0)
        XCTAssertEqual(world.map.kit, "blockout")
        XCTAssertGreaterThan(world.graph.nodeCount, 0)
        XCTAssertFalse(world.plan.pieces.isEmpty)
    }
}

/// The whole chain with nothing stubbed: files on disk, through the parser and the
/// kit, into a graph and a plan that agree with each other.
///
/// verifies: FR-MAP-010, FR-MAP-020, FR-TOOL-020, FR-TOOL-030
final class WorldTests: XCTestCase {
    func testTheWorldIsAssembledFromTheShippedFiles() throws {
        let world = try Launch.world().get()
        XCTAssertEqual(world.map.floors.count, 2)
        XCTAssertEqual(world.kit.floorHeight, 3.0)
        XCTAssertEqual(world.plan.cellSize, world.configurations.tuning.navigationGraphCellSize)
        XCTAssertEqual(world.graph.floorsReachable(from: try XCTUnwrap(world.graph.nodes.first { $0.floor == 0 })),
                       [0, 1])
    }

    func testAMapThatIsNotThereIsNamedRatherThanCrashing() {
        switch Launch.world(map: "nosuchmap") {
        case .success: XCTFail("a map that is not in the bundle must not start")
        case .failure(let error): XCTAssertEqual(error as? MapLoadError, .missing(name: "nosuchmap"))
        }
    }
}
