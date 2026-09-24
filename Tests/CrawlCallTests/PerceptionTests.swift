// A bot notices the snake when something of it is close enough and nothing stands in
// the way (FR-BOT-050), over a map built here so that what is in the way is known.
//
// verifies: FR-BOT-050
import XCTest
@testable import CrawlCall

final class PerceptionTests: XCTestCase {
    private lazy var kit: Kit = { try! Kit.load(named: "blockout", from: .main) }()
    private lazy var configuration: BotConfiguration = {
        try! Launch.world().get().configurations.bot
    }()
    private let cell = 0.5

    /// A row of floor with one wall in the middle of it:
    /// `.....#.....`, so that two points on the same row are either side of it.
    private func plan(_ rows: String...) throws -> ScenePlan {
        let map = try MapParser.parse("kit blockout\nfloor 0\n" + rows.joined(separator: "\n") + "\n", kit: kit)
        return ScenePlan.make(map: map, kit: kit, cellSize: cell)
    }

    private func bot(at x: Int, _ z: Int, kind: Archetype = .assault) throws -> Bot {
        try XCTUnwrap(Bot(id: 0, squad: .red, archetype: kind,
                          at: SIMD3(Double(x) * cell, 0, Double(z) * cell), floor: 0,
                          configuration: configuration))
    }

    private func at(_ x: Int, _ z: Int) -> SIMD3<Double> {
        SIMD3(Double(x) * cell, 0, Double(z) * cell)
    }

    func testABotSeesTheSnakeAcrossAnEmptyFloor() throws {
        var bots = [try bot(at: 0, 0)]
        Perception.notice(&bots, snake: [at(6, 0)], plan: try plan("........"), configuration: configuration)
        XCTAssertTrue(bots[0].knowsSnake)
    }

    func testAWallBetweenThemHidesIt() throws {
        var bots = [try bot(at: 0, 0)]
        Perception.notice(&bots, snake: [at(6, 0)], plan: try plan("...#...."), configuration: configuration)
        XCTAssertFalse(bots[0].knowsSnake, "the bot saw through a wall")
    }

    func testACrateHidesItToo() throws {
        // Cover is map geometry that blocks line of sight (glossary), and a crate is
        // cover — a snake is a low creature and does not look over it.
        var bots = [try bot(at: 0, 0)]
        Perception.notice(&bots, snake: [at(6, 0)], plan: try plan("...o...."), configuration: configuration)
        XCTAssertFalse(bots[0].knowsSnake)
    }

    // MARK: from the height of the eyes (ADR-0022)

    /// A floor with one low box on it, lower than a bot's eyes — lower than anything
    /// the blockout kit has, whose lowest standing module, the fence, is 8 cm short of
    /// a bot's eyes and hides a snake within seven metres of it.
    private func kerb(at x: Int, height: Double) throws -> ScenePlan {
        let floor = try plan("............")
        let box = ScenePlan.Piece(module: "kerb", size: SIMD3(cell, height, cell),
                                  centre: SIMD3(Double(x) * cell, height / 2 - MapGrid.surfaceOverlap, 0),
                                  colour: SIMD3(0.5, 0.5, 0.5), level: 0)
        return ScenePlan(pieces: floor.pieces + [box], cellSize: floor.cellSize, floorHeight: floor.floorHeight)
    }

    func testABotLooksOverWhatIsLowerThanItsEyes() throws {
        // A box half the eyes' height in the next cell over, and a snake four metres
        // off: the line from the eyes is still above the box where it crosses it.
        // Measured along the floor, as sight was until ADR-0022, the box hid it.
        let low = configuration.eyeHeight / 2
        var bots = [try bot(at: 0, 0)]
        Perception.notice(&bots, snake: [at(8, 0)], plan: try kerb(at: 1, height: low), configuration: configuration)
        XCTAssertTrue(bots[0].knowsSnake, "the bot did not look over a box lower than its eyes")
    }

    func testAFenceTheBotStandsAgainstHidesTheSnakeAcrossTheRoom() throws {
        // The blockout's fence is 0.8 m, just below the eyes: over five metres the
        // line from the eyes comes down below the fence's top before it is past it.
        var bots = [try bot(at: 0, 0)]
        Perception.notice(&bots, snake: [at(10, 0)], plan: try plan(".#.........."), configuration: configuration)
        XCTAssertFalse(bots[0].knowsSnake, "the bot saw over a fence its eyes barely clear")
    }

    func testAFenceCloseInFrontOfTheSnakeStillHidesIt() throws {
        // A fence in the cell before the snake: the line has come down to a
        // seventh of a metre by then.
        var bots = [try bot(at: 0, 0)]
        Perception.notice(&bots, snake: [at(9, 0)], plan: try plan("........#..."), configuration: configuration)
        XCTAssertFalse(bots[0].knowsSnake, "the bot saw through a fence the snake was lying behind")
    }

    func testWhatStandsTallerThanTheEyesHidesTheSnakeWhereverItStands() throws {
        // A partition is two metres tall, above the eyes: in the next cell to the bot
        // it hides what a fence there would not.
        var bots = [try bot(at: 0, 0)]
        Perception.notice(&bots, snake: [at(10, 0)], plan: try plan(".=.........."), configuration: configuration)
        XCTAssertFalse(bots[0].knowsSnake, "the bot saw through a partition")
    }

    func testTheFloorTheyBothStandOnIsNotInTheWay() throws {
        // The failure this guards against makes every bot blind: the slab under them
        // touches the line, and a rule that counted it would end the match at the
        // whistle.
        var bots = [try bot(at: 0, 0)]
        Perception.notice(&bots, snake: [at(1, 0)], plan: try plan("...."), configuration: configuration)
        XCTAssertTrue(bots[0].knowsSnake)
    }

    func testBeyondTheDetectionRangeItIsNotNoticed() throws {
        let range = try XCTUnwrap(configuration.archetypes[Archetype.assault.rawValue]).detectionRange
        let far = Int((range / cell).rounded(.up)) + 2
        var bots = [try bot(at: 0, 0)]
        let row = String(repeating: ".", count: far + 1)
        Perception.notice(&bots, snake: [at(far, 0)], plan: try plan(row), configuration: configuration)
        XCTAssertFalse(bots[0].knowsSnake, "a bot noticed the snake \(Double(far) * cell) m away")
        // And the same snake one step inside the range is noticed, so the test above
        // is about the range and not about the line.
        let near = Int((range / cell).rounded(.down)) - 1
        var again = [try bot(at: 0, 0)]
        Perception.notice(&again, snake: [at(near, 0)], plan: try plan(row), configuration: configuration)
        XCTAssertTrue(again[0].knowsSnake)
    }

    func testASegmentSeenIsTheSnakeSeen() throws {
        // "Any segment of the snake" — the head is behind the wall, a segment is not.
        // The segment is two rows over rather than one: at one row the line to it
        // grazes the wall's own corner, where blocked and clear are the same case.
        let arena = try plan("...#....",
                             "........",
                             "........")
        var head = [try bot(at: 0, 0)]
        Perception.notice(&head, snake: [at(6, 0)], plan: arena, configuration: configuration)
        XCTAssertFalse(head[0].knowsSnake, "the head is behind the wall")

        var bots = [try bot(at: 0, 0)]
        Perception.notice(&bots, snake: [at(6, 0), at(6, 2)], plan: arena, configuration: configuration)
        XCTAssertTrue(bots[0].knowsSnake)
    }

    func testWhatIsAlreadyKnownStaysKnown() throws {
        var bots = [try bot(at: 0, 0)]
        let open = try plan("........")
        Perception.notice(&bots, snake: [at(6, 0)], plan: open, configuration: configuration)
        XCTAssertTrue(bots[0].knowsSnake)
        // Out of sight afterwards: nothing in the specification says a bot forgets,
        // so nothing here does either.
        Perception.notice(&bots, snake: [at(6, 0)], plan: try plan("...#...."), configuration: configuration)
        XCTAssertTrue(bots[0].knowsSnake)
    }
}
