// The frame record (FR-TOOL-230, FR-TOOL-240): the ring keeps the newest frames and says
// how many it dropped, the file reads as the columns promise, events land in the frame
// they happened in, and a real match — deliberating, eating, ending — records itself.
//
// verifies: FR-TOOL-230, FR-TOOL-240
import RealityKit
import XCTest
@testable import CrawlCall

final class FrameRecordTests: XCTestCase {
    private func frame(step: Double = 0, deliberation: Double = 0, seeThrough: Double = 0,
                       draw: Double = 0) -> FrameRecord.Frame {
        var frame = FrameRecord.Frame()
        frame[.step] = step
        frame[.deliberation] = deliberation
        frame[.seeThrough] = seeThrough
        frame[.draw] = draw
        return frame
    }

    // MARK: the ring

    func testAnEmptyRecordIsItsHeaderAlone() {
        XCTAssertEqual(FrameRecord(capacity: 4).csv(),
                       "frame,time_ms,interval_ms,step_ms,deliberation_ms,see_through_ms,draw_ms,events\n")
    }

    func testAFullRingKeepsTheNewestFramesInOrderAndCountsWhatItDropped() {
        var record = FrameRecord(capacity: 3)
        for step in 1...5 { record.record(frame(step: Double(step))) }
        XCTAssertEqual(record.count, 3)
        XCTAssertEqual(record.dropped, 2)
        XCTAssertEqual(record.frames.map { $0[.step] }, [3, 4, 5])
        // Numbered from the first frame ever recorded, so the gap the ring left shows.
        let numbers = record.csv().split(separator: "\n").dropFirst().map { $0.split(separator: ",")[0] }
        XCTAssertEqual(numbers, ["3", "4", "5"])
    }

    func testARingOfOneKeepsTheLastFrame() {
        var record = FrameRecord(capacity: 1)
        record.record(frame(step: 1))
        record.record(frame(step: 2))
        XCTAssertEqual(record.frames.map { $0[.step] }, [2])
        XCTAssertEqual(record.dropped, 1)
    }

    func testARingAskedForNoRoomStillHoldsAFrame() {
        var record = FrameRecord(capacity: 0)
        record.record(frame(step: 7))
        XCTAssertEqual(record.frames.map { $0[.step] }, [7])
    }

    // MARK: the file's shape

    func testARowWritesEveryColumnToTheMicrosecond() {
        var record = FrameRecord(capacity: 2)
        var one = frame(step: 2.5, deliberation: 1.25, seeThrough: 0.0626, draw: 0.3333333)
        one.time = 1000
        one.interval = 16.6666666
        record.record(one)
        let row = record.csv().split(separator: "\n")[1]
        XCTAssertEqual(row, "1,1000.000,16.667,2.500,1.250,0.063,0.333,")
    }

    func testEventsAreWrittenInTheirOwnOrderWithACountWhereThereIsMoreThanOne() {
        var one = frame()
        one.add(.firstHole)
        one.add(.deliberation, times: 2)
        one.add(.matchBegan)
        var record = FrameRecord(capacity: 1)
        record.record(one)
        let events = record.csv().split(separator: "\n")[1].split(separator: ",", omittingEmptySubsequences: false).last
        XCTAssertEqual(events, "match_began;deliberation*2;first_hole")
    }

    func testAnEventCountStopsAtItsLimitRatherThanWrapping() {
        var one = frame()
        one.add(.hit, times: Int(UInt16.max))
        one.add(.hit, times: 5)
        XCTAssertEqual(one.count(of: .hit), Int(UInt16.max))
    }

    func testEveryEventHasACounter() {
        // The counters are one SIMD lane each; an event past the last lane would have
        // no counter to land in.
        XCTAssertLessThanOrEqual(FrameEvent.allCases.count, SIMD8<UInt16>.scalarCount)
        XCTAssertEqual(Set(FrameEvent.allCases.map(\.rawValue)).count, FrameEvent.allCases.count)
    }

    // MARK: the switch

    func testTheRecordIsSwitchedOnByItsVariableAndNothingElse() {
        XCTAssertTrue(FrameRecorder.isSwitchedOn(["CRAWLCALL_FRAMES": "1"]))
        XCTAssertFalse(FrameRecorder.isSwitchedOn(["CRAWLCALL_FRAMES": "0"]))
        XCTAssertFalse(FrameRecorder.isSwitchedOn(["CRAWLCALL_FRAMES": ""]))
        XCTAssertFalse(FrameRecorder.isSwitchedOn(["MTL_HUD_ENABLED": "1"]))
        XCTAssertFalse(FrameRecorder.isSwitchedOn([:]))
    }

    // MARK: the recorder

    private var file: URL {
        FileManager.default.temporaryDirectory.appending(path: "frames-\(UUID().uuidString).csv")
    }

    @MainActor
    func testAnEventNotedBetweenFramesLandsInTheNextFrameOnly() {
        let recorder = FrameRecorder(capacity: 4, fileURL: file)
        recorder.note(.mealBegan)
        recorder.add(interval: 1.0 / 60, frame())
        recorder.add(interval: 1.0 / 60, frame())
        XCTAssertEqual(recorder.record.frames.map { $0.count(of: .mealBegan) }, [1, 0])
    }

    @MainActor
    func testTheIntervalIsKeptInMillisecondsAndTimeRunsForward() {
        let recorder = FrameRecorder(capacity: 4, fileURL: file)
        recorder.add(interval: 0.05, frame())
        recorder.add(interval: 0.02, frame())
        let frames = recorder.record.frames
        XCTAssertEqual(frames[0].interval, 50, accuracy: 1e-9)
        XCTAssertEqual(frames[1].interval, 20, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(frames[1].time, frames[0].time)
    }

    @MainActor
    func testWritingNowLeavesTheRecordInTheFile() throws {
        let url = file
        let recorder = FrameRecorder(capacity: 4, fileURL: url)
        recorder.add(interval: 1.0 / 60, frame(step: 3))
        try recorder.writeNow()
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), recorder.record.csv())
    }

    @MainActor
    func testWritingInTheBackgroundLeavesTheRecordAsItWasWhenAsked() throws {
        let url = file
        let recorder = FrameRecorder(capacity: 4, fileURL: url)
        recorder.add(interval: 1.0 / 60, frame(step: 3))
        let asked = recorder.record.csv()
        recorder.writeInBackground()
        // A frame after the request is not in the file: the copy was taken when asked.
        recorder.add(interval: 1.0 / 60, frame(step: 4))
        let deadline = Date().addingTimeInterval(5)
        while !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), asked)
    }

    @MainActor
    func testAnEventNotedTooOftenStopsAtItsLimitInTheFrameToo() {
        let recorder = FrameRecorder(capacity: 2, fileURL: file)
        recorder.note(.hit, times: Int(UInt16.max))
        var frame = frame()
        frame.add(.hit, times: 7)
        recorder.add(interval: 1.0 / 60, frame)
        XCTAssertEqual(recorder.record.frames[0].count(of: .hit), Int(UInt16.max))
    }

    @MainActor
    func testStartingARecordRemovesTheOneAnEarlierRunLeft() throws {
        let url = file
        try "frame\n1\n".write(to: url, atomically: true, encoding: .utf8)
        _ = FrameRecorder(capacity: 2, fileURL: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)),
                       "a record from an earlier run would pass for this one's")
    }

    func testTheRecordIsWrittenToTheDocumentsContainer() {
        XCTAssertEqual(FrameRecorder.defaultFileURL.deletingLastPathComponent().standardizedFileURL,
                       URL.documentsDirectory.standardizedFileURL)
        XCTAssertEqual(FrameRecorder.defaultFileURL.lastPathComponent, "frames.csv")
    }
}

/// A real match with the record on: what it records is what happened in it.
@MainActor
final class MatchRecordTests: XCTestCase {
    private func world(squadSize: Int? = nil) throws -> World {
        let base = try Launch.world().get()
        guard let squadSize else { return base }
        let url = try XCTUnwrap(Bundle.main.url(forResource: "match", withExtension: "json", subdirectory: "config"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        json["squadSize"] = squadSize
        let match = try Configurations.decode(MatchConfiguration.self, named: "match", schema: MatchConfiguration.schema,
                                              from: JSONSerialization.data(withJSONObject: json))
        let c = base.configurations
        return World(configurations: Configurations(snake: c.snake, tuning: c.tuning, view: c.view, bot: c.bot, match: match),
                     kit: base.kit, map: base.map, setting: base.setting, graph: base.graph, plan: base.plan)
    }

    private func session(in world: World, recording url: URL) throws -> (GameSession, FrameRecorder) {
        let game = Game(world: world, start: try XCTUnwrap(Game.start(in: world)))
        let built = SceneBuilder.scene(for: world.plan, view: world.configurations.view)
        let camera = try XCTUnwrap(built.root.children.first { $0.name == "camera" })
        let session = GameSession(game: game,
                                  snakeEntity: SnakeEntity.make(radius: world.configurations.tuning.bodyRadius,
                                                                segments: game.snake.segments),
                                  botEntities: BotEntity.make(for: game.bots, height: world.configurations.bot.figureHeight),
                                  shotEntities: ShotEntity.make(for: game.bots),
                                  camera: camera, seeThrough: built.seeThrough, distance: 12, fieldOfView: 50)
        let recorder = FrameRecorder(capacity: 10_000, fileURL: url)
        session.recorder = recorder
        return (session, recorder)
    }

    private var file: URL {
        FileManager.default.temporaryDirectory.appending(path: "match-\(UUID().uuidString).csv")
    }

    func testEveryFrameIsRecordedWithItsPhasesAndTheFirstBeginsTheMatch() throws {
        let (session, recorder) = try session(in: try world(), recording: file)
        for _ in 0..<30 { session.step(seconds: 1.0 / 60) }
        let frames = recorder.record.frames
        XCTAssertEqual(frames.count, 30)
        XCTAssertEqual(frames[0].count(of: .matchBegan), 1)
        XCTAssertEqual(frames.dropFirst().map { $0.count(of: .matchBegan) }.reduce(0, +), 0)
        for frame in frames {
            XCTAssertEqual(frame.interval, 1000.0 / 60, accuracy: 1e-9)
            // The match's step holds its deliberation, and nothing takes negative time.
            XCTAssertGreaterThanOrEqual(frame[.step] + 1e-9, frame[.deliberation])
            for phase in FramePhase.allCases { XCTAssertGreaterThanOrEqual(frame[phase], 0) }
        }
        // Drawing is never free: the see-through and the entities were updated.
        XCTAssertGreaterThan(frames.map { $0[.draw] + $0[.seeThrough] }.reduce(0, +), 0)
    }

    func testBotsDeliberatingAreRecordedInTheFramesTheyDeliberatedIn() throws {
        let world = try world()
        let (session, recorder) = try session(in: world, recording: file)
        // Half a second at 60 frames is two and a half deliberation periods of 0.2 s.
        for _ in 0..<30 { session.step(seconds: 1.0 / 60) }
        let deliberations = recorder.record.frames.map { $0.count(of: .deliberation) }.reduce(0, +)
        // Two steps' worth at least, at the configuration's slots per step.
        XCTAssertGreaterThanOrEqual(deliberations, 2 * min(world.configurations.bot.perFrameSlotMaximum,
                                                             session.game.bots.count))
        let deliberatingFrames = recorder.record.frames.filter { $0.count(of: .deliberation) > 0 }
        XCTAssertFalse(deliberatingFrames.isEmpty)
        XCTAssertTrue(deliberatingFrames.allSatisfy { $0[.deliberation] > 0 },
                      "a frame that deliberated recorded no time for it")
    }

    func testAMealIsRecordedWhereItBeganAndWhereItEnded() throws {
        let world = try world()
        let (session, recorder) = try session(in: world, recording: file)
        let game = session.game
        let cell = world.configurations.tuning.navigationGraphCellSize
        let prey = try XCTUnwrap(game.bots.filter { $0.floor == 0 }.first)
        var route = Route.between(game.start,
                                  NavigationGraph.Node(floor: 0, x: Int((prey.position.x / cell).rounded()),
                                                       z: Int((prey.position.z / cell).rounded())),
                                  in: world.graph)
        for _ in 0..<1800 where session.game.bots.count == game.bots.count {
            if let next = route.first {
                let there = SIMD3(Double(next.x) * cell, 0, Double(next.z) * cell)
                let head = session.game.snake.head
                let toward = SIMD2(there.x - head.x, there.z - head.z)
                let length = (toward.x * toward.x + toward.y * toward.y).squareRoot()
                if length < 0.1 { route.removeFirst() }
                session.apply(.move(direction: length > 0 ? SIMD2(toward.x / length, toward.y / length) : .zero))
            }
            if session.canEat { session.apply(.eat) }
            session.step(seconds: 1.0 / 60)
        }
        XCTAssertLessThan(session.game.bots.count, game.bots.count, "the snake never ate, so this proves nothing")
        let frames = recorder.record.frames
        let began = try XCTUnwrap(frames.firstIndex { $0.count(of: .mealBegan) > 0 })
        let ended = try XCTUnwrap(frames.firstIndex { $0.count(of: .mealEnded) > 0 })
        XCTAssertLessThan(began, ended, "the meal ended before it began")
        XCTAssertEqual(frames.map { $0.count(of: .mealBegan) }.reduce(0, +), 1)
        XCTAssertEqual(frames.map { $0.count(of: .mealEnded) }.reduce(0, +), 1)
    }

    func testTheEndOfAMatchIsRecordedAndWritesTheFile() throws {
        // No squads: the arena is empty at the first step, and the match ends there.
        let url = file
        let (session, recorder) = try session(in: try world(squadSize: 0), recording: url)
        session.step(seconds: 1.0 / 60)
        session.step(seconds: 1.0 / 60)
        XCTAssertEqual(session.game.outcome, .arenaEmpty)
        XCTAssertEqual(recorder.record.frames.map { $0.count(of: .matchEnded) }, [1, 0])
        let deadline = Date().addingTimeInterval(5)
        while !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        let written = try String(contentsOf: url, encoding: .utf8)
        // The record as it was when the match ended: the header and the one frame the
        // match began and ended in — the second frame came after the copy was taken.
        let rows = written.split(separator: "\n")
        XCTAssertEqual(rows.count, 2, written)
        XCTAssertTrue(rows[1].hasSuffix(",match_began;match_ended"), String(rows[1]))
    }

    func testARestartBeginsAMatchInTheSameRecord() throws {
        let (session, recorder) = try session(in: try world(), recording: file)
        session.step(seconds: 1.0 / 60)
        session.restart()
        session.step(seconds: 1.0 / 60)
        XCTAssertEqual(recorder.record.frames.map { $0.count(of: .matchBegan) }, [1, 1])
    }

    func testASessionWithoutARecorderRecordsNothingAndStillPlays() throws {
        let world = try world()
        let game = Game(world: world, start: try XCTUnwrap(Game.start(in: world)))
        let built = SceneBuilder.scene(for: world.plan, view: world.configurations.view)
        let camera = try XCTUnwrap(built.root.children.first { $0.name == "camera" })
        let session = GameSession(game: game,
                                  snakeEntity: SnakeEntity.make(radius: world.configurations.tuning.bodyRadius,
                                                                segments: game.snake.segments),
                                  botEntities: BotEntity.make(for: game.bots, height: world.configurations.bot.figureHeight),
                                  shotEntities: ShotEntity.make(for: game.bots),
                                  camera: camera, seeThrough: built.seeThrough, distance: 12, fieldOfView: 50)
        session.apply(.move(direction: SIMD2(1, 0)))
        let before = session.game.snake.head
        session.step(seconds: 1.0 / 60)
        XCTAssertNil(session.recorder)
        XCTAssertNotEqual(session.game.snake.head, before)
    }
}

/// What the match's step and the see-through check report, measured on the real thing.
final class StepReportTests: XCTestCase {
    func testAStepReportsTheBotsThatDeliberatedAndTheTimeItTook() throws {
        let world = try Launch.world().get()
        var game = Game(world: world, start: try XCTUnwrap(Game.start(in: world)))
        // One period exactly: one deliberation step, as many bots as the slots allow.
        let report = game.advance(seconds: world.configurations.bot.deliberationPeriod)
        XCTAssertEqual(report.deliberations, min(world.configurations.bot.perFrameSlotMaximum, game.bots.count))
        XCTAssertGreaterThan(report.deliberationTime, .zero)
    }

    func testAStepShorterThanAPeriodDeliberatesNobody() throws {
        let world = try Launch.world().get()
        var game = Game(world: world, start: try XCTUnwrap(Game.start(in: world)))
        let report = game.advance(seconds: world.configurations.bot.deliberationPeriod / 4)
        XCTAssertEqual(report, Game.StepReport())
    }

    func testAPausedMatchReportsNothing() throws {
        let world = try Launch.world().get()
        var game = Game(world: world, start: try XCTUnwrap(Game.start(in: world)))
        game.apply(.pause)
        XCTAssertEqual(game.advance(seconds: 1), Game.StepReport())
    }

    @MainActor
    func testTheSeeThroughCountsALookChangeOnceAndItsReturnOnce() throws {
        let world = try Launch.world().get()
        var seeThrough = SceneBuilder.scene(for: world.plan, view: world.configurations.view).seeThrough
        let margin = world.configurations.tuning.bodyRadius + world.configurations.view.seeThroughMargin
        let radius = world.configurations.view.visibilityRadius
        // A head on the ground in the middle of the map, seen from where the match's
        // camera would stand: something stands around it that is cut open.
        let centre = world.plan.bounds.centre
        let head = SIMD3(centre.x, 0, centre.z)
        let eye = head + SIMD3(0, 8, 6)
        let first = seeThrough.show(headOn: 0, head: head, surface: 0, snake: [head], from: eye,
                                    margin: margin, visibilityRadius: radius)
        XCTAssertGreaterThan(first.lookChanges, 0, "nothing near the head was cut open, so this proves nothing")
        // The hole shader loads here too, or the count of first holes below is never
        // put to the test.
        XCTAssertGreaterThan(first.firstHoles, 0, "no module was drawn through the hole shader")
        let again = seeThrough.show(headOn: 0, head: head, surface: 0, snake: [head], from: eye,
                                    margin: margin, visibilityRadius: radius)
        XCTAssertEqual(again.lookChanges, 0, "a look that did not change was counted as a change")
        XCTAssertEqual(again.firstHoles, 0, "a module cut open before was counted as cut open for the first time")
        // Nothing to hide and no window to keep: what was cut goes back to solid, each
        // counted once. The floors above the head stay clear — the head is still under
        // them — so fewer come back than first changed, never more.
        let back = seeThrough.show(headOn: 0, head: head, surface: 0, snake: [], from: eye,
                                   margin: margin, visibilityRadius: 0)
        XCTAssertGreaterThan(back.lookChanges, 0)
        XCTAssertLessThanOrEqual(back.lookChanges, first.lookChanges)
    }
}
