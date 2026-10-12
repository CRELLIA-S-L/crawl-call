// When a commander is called, what it is handed, and what the match does with what
// comes back. No model anywhere: every call here goes through the scripted answerer,
// which is the only thing that can be made to refuse (CON-CMD-020).
//
// file verifies: FR-CMD-010, FR-CMD-020, FR-CMD-025, FR-CMD-027, FR-CMD-070, FR-CMD-080
import XCTest
@testable import CrawlCall

final class CommanderDeskTests: XCTestCase {
    private let lean = CommanderDecision.Lean(name: "Davis", role: "hold the stair", panic: 0.5,
                                              courage: 0.5, discipline: 0.5, aggression: 0.5,
                                              selfSacrifice: 0.5)
    private func decision(_ order: CommanderDecision.Order = .hold) -> CommanderDecision {
        CommanderDecision(threat: .snake, order: order, crew: [lean], truce: .none, line: nil)
    }
    private let state = CommanderInput(crew: [], gone: [], rivals: "not seen", snake: "not seen",
                                       awareness: "calm", lastCall: "none", truce: nil, events: [])

    private func desk(_ script: [ScriptedCommander.Reply], interval: Double = 7)
        -> (desk: CommanderDesk, commander: ScriptedCommander) {
        let commander = ScriptedCommander(script)
        return (CommanderDesk(commander: commander, interval: interval), commander)
    }

    // MARK: once per interval (FR-CMD-020)

    func testTheFirstCallOfASquadIsDueAtOnceAndTheOtherHalfAnIntervalLater() {
        // FR-CMD-080 from the first call rather than only from the second: two
        // inferences that both started at zero would be the thing the requirement
        // exists to prevent, on the frame it matters most.
        let (desk, _) = desk([.decision(decision())], interval: 7)
        XCTAssertTrue(desk.isDue(.red, at: 0))
        XCTAssertFalse(desk.isDue(.blue, at: 0))
        XCTAssertFalse(desk.isDue(.blue, at: 3.0))
        XCTAssertTrue(desk.isDue(.blue, at: 3.5))
    }

    func testASquadIsNotCalledAgainUntilItsIntervalHasPassed() async {
        let (desk, _) = desk([.decision(decision())], interval: 7)
        await desk.call(.red, with: state, at: 0)
        XCTAssertFalse(desk.isDue(.red, at: 6.9))
        XCTAssertTrue(desk.isDue(.red, at: 7.0))
    }

    func testExactlyHalfAnIntervalApartIsFarEnough() async {
        // FR-CMD-080 says "at least half a commander interval", so the boundary
        // belongs to the allowed side. Red at 0 and blue at 3.5 puts red's next call
        // at 7, exactly half an interval from blue's last, and that is far enough.
        let (desk, _) = desk([.decision(decision())], interval: 7)
        await desk.call(.red, with: state, at: 0)
        await desk.call(.blue, with: state, at: 3.5)
        XCTAssertTrue(desk.isDue(.red, at: 7.0))
    }

    func testACallIsHeldBackWhenItWouldCrowdTheOtherCommander() async {
        // The rule doing work: blue called at 4 puts red's due moment at 7 only three
        // seconds after it, so red waits until 7.5. Without this the two inferences
        // would start within three seconds of each other for the rest of the match.
        let (desk, _) = desk([.decision(decision())], interval: 7)
        await desk.call(.red, with: state, at: 0)
        await desk.call(.blue, with: state, at: 4.0)
        XCTAssertFalse(desk.isDue(.red, at: 7.0), "red crowded blue by three seconds")
        XCTAssertFalse(desk.isDue(.red, at: 7.4))
        XCTAssertTrue(desk.isDue(.red, at: 7.5))
    }

    func testASquadWaitingOnACallIsNotCalledAgain() async {
        // A model that takes longer than the interval — measured at 9.2 s against 7 on
        // 2026-10-11 (Q-570) — must not pile a second call on the first.
        let commander = ScriptedCommander([.decision(decision())])
        let desk = CommanderDesk(commander: commander, interval: 7)
        async let first: Void = desk.call(.red, with: state, at: 0)
        _ = await first
        XCTAssertFalse(desk.isWaiting(.red))
        XCTAssertEqual(commander.callCount, 1)
        // And the guard itself: a call started while one is out is dropped, not queued.
        await desk.call(.red, with: state, at: 0)
        XCTAssertEqual(commander.callCount, 2, "a second call at the same moment is a new call")
    }

    // MARK: what comes back

    func testAnAnswerIsTakenOnceAndOnlyOnce() async {
        let (desk, _) = desk([.decision(decision())])
        await desk.call(.red, with: state, at: 0)
        let taken = desk.take()
        XCTAssertEqual(taken.count, 1)
        XCTAssertEqual(taken.first?.squad, .red)
        XCTAssertTrue(desk.take().isEmpty, "an answer taken twice is an order given twice")
    }

    func testTheLastDecisionIsKeptAndARefusalDoesNotReplaceIt() async {
        // CON-CMD-020: a refused call is a missed cycle, and a missed cycle must not
        // lose the order the squad already has.
        let (desk, _) = desk([.decision(decision(.flank)), .failure(.refused)])
        await desk.call(.red, with: state, at: 0)
        XCTAssertEqual(desk.lastDecision(of: .red)?.order, .flank)
        _ = desk.take()
        await desk.call(.red, with: state, at: 7)
        XCTAssertEqual(desk.lastDecision(of: .red)?.order, .flank, "a refusal overwrote the order")
        XCTAssertEqual(desk.take().first?.answer, .failure(.refused))
    }

    func testEachSquadKeepsItsOwnLastDecision() async {
        // FR-CMD-010: one commander per squad is a matter of state, and this is the
        // state — neither squad is ever handed the other's decision.
        let (desk, _) = desk([.decision(decision(.flank)), .decision(decision(.disperse))])
        await desk.call(.red, with: state, at: 0)
        await desk.call(.blue, with: state, at: 3.5)
        XCTAssertEqual(desk.lastDecision(of: .red)?.order, .flank)
        XCTAssertEqual(desk.lastDecision(of: .blue)?.order, .disperse)
    }
}

final class CommanderInTheMatchTests: XCTestCase {
    private let lean = CommanderDecision.Lean(name: "Davis", role: nil, panic: 0.5, courage: 0.5,
                                              discipline: 0.5, aggression: 0.5, selfSacrifice: 0.5)
    private var decision: CommanderDecision {
        CommanderDecision(threat: .snake, order: .flank, crew: [lean], truce: .none, line: nil)
    }

    private func match(_ script: [ScriptedCommander.Reply]? = nil) throws -> (Game, ScriptedCommander?) {
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        guard let script else { return (Game(world: world, start: start), nil) }
        let commander = ScriptedCommander(script)
        return (Game(world: world, start: start, commander: commander), commander)
    }

    func testAMatchWithNoCommanderAsksNobody() throws {
        let (game, _) = try match()
        XCTAssertNil(game.desk)
        XCTAssertTrue(game.dueCalls().isEmpty)
    }

    func testTheFirstFrameOfAMatchHasRedsCallDueAndNotBlues() throws {
        let (game, _) = try match([.decision(decision)])
        let due = game.dueCalls()
        XCTAssertEqual(due.map(\.squad), [.red])
    }

    func testACallCarriesWhatHappenedSinceTheLastOneAndThenForgetsIt() async throws {
        // IF-CMD-010's second half, end to end. The snake takes one of red's, through
        // the game's own act (FR-SNAKE-270 is the player's business and not this
        // test's), and the next call red's commander is handed says so.
        //
        // What the commander heard is read rather than what the match was about to
        // send: a call becomes due inside `advance` and is started and spent there, so
        // there is no moment between the two for a test to look at.
        var (game, scripted) = try match([.decision(decision)])
        let commander = try XCTUnwrap(scripted)
        let frame = 1.0 / 60
        let prey = try XCTUnwrap(game.bots.first { $0.squad == .red && !$0.isCommander })
        game.begin(eating: prey.id)
        var frames = 0
        while game.bots.contains(where: { $0.id == prey.id }) && frames < Int(60 / frame) {
            game.advance(seconds: frame)
            frames += 1
        }
        XCTAssertFalse(game.bots.contains { $0.id == prey.id }, "the meal never finished")

        let name = SquadView.name(of: prey.archetype)
        XCTAssertEqual(game.happenings.lines(of: .red).first, "\(name) gone missing",
                       "the match did not notice that it had lost somebody")

        var told = false
        for _ in 0..<Int(20 / frame) where !told {
            game.advance(seconds: frame)
            await Task.yield()
            told = commander.heard.contains { $0.prompt.contains("just happened: \(name) gone missing") }
        }
        XCTAssertTrue(told, "no call carried what had happened: \(commander.heard.map(\.prompt))")
        XCTAssertEqual(game.happenings.lines(of: .red), [],
                       "the call carried the events and left them to be told again")
    }

    func testACallCarriesTheStateTheRequirementDefines() throws {
        // The end-to-end shape of IF-CMD-010: what the match hands over is the state
        // built from the role-holder's knowledge, not a sketch of it.
        let (game, _) = try match([.decision(decision)])
        let state = try XCTUnwrap(game.dueCalls().first?.state)
        XCTAssertTrue(state.prompt.hasPrefix("crew: "))
        XCTAssertEqual(state.prompt.split(separator: "\n").count, 5,
                       "a first call has no jobs, no truce and no events: \(state.prompt)")
        XCTAssertEqual(state.lastCall, "none", "the first call has no previous decision")
        XCTAssertFalse(state.crew.isEmpty)
    }

    func testACalmSquadIsNotToldAboutTheSnake() throws {
        // FR-CMD-070 end to end: at the start every squad is calm, and the state says
        // the snake is not seen whatever the arena holds.
        let (game, _) = try match([.decision(decision)])
        let state = try XCTUnwrap(game.dueCalls().first?.state)
        XCTAssertEqual(state.snake, "not seen")
        XCTAssertEqual(state.awareness, "calm")
    }

    func testTheSquadsAreToldDifferentThings() throws {
        // FR-CMD-010: each commander reasons only from its own squad's view. The two
        // squads start at opposite ends of the island (FR-BOT-350), so the quarter
        // each crew is in is the plainest thing that must differ.
        var game = try match([.decision(decision)]).0
        let red = try XCTUnwrap(game.dueCalls().first { $0.squad == .red }?.state)
        _ = game.advance(seconds: 4)
        let blue = try XCTUnwrap(game.dueCalls().first { $0.squad == .blue }?.state)
        XCTAssertNotEqual(red.crew.map(\.place), blue.crew.map(\.place),
                          "both commanders were told the same crew was in the same place")
    }

    func testASquadWithNoLivingRoleHolderHasNoStateToSend() throws {
        // FR-CMD-020's "while a squad has a living role-holder", and the first half of
        // FR-CMD-120: the voice goes with the bot. Read at the state rather than
        // through the match, because there is no way to take a bot out of a match from
        // outside it, and this is the rule itself rather than a route to it.
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        var bots = Game(world: world, start: start).bots
        let index = try XCTUnwrap(bots.firstIndex { $0.squad == .red && $0.isCommander })
        XCTAssertNotNil(SquadView.state(of: .red, among: bots, awareness: .calm,
                                        in: world.plan.bounds, configuration: world.configurations.bot,
                                        lastCall: nil, truce: nil, events: []))
        bots[index].health = .zero
        XCTAssertNil(SquadView.state(of: .red, among: bots, awareness: .calm,
                                     in: world.plan.bounds, configuration: world.configurations.bot,
                                     lastCall: nil, truce: nil, events: []),
                     "a squad with its role-holder gone was still given something to say")
        // The other squad still has one, so the game has not simply stopped.
        XCTAssertNotNil(SquadView.state(of: .blue, among: bots, awareness: .calm,
                                        in: world.plan.bounds, configuration: world.configurations.bot,
                                        lastCall: nil, truce: nil, events: []))
    }

    func testThePreviousDecisionGoesIntoTheNextCall() async throws {
        // FR-CMD-025: the session carries the instructions alone, so what the
        // commander said last reaches it through the state and through nothing else.
        let (game, _) = try match([.decision(decision)])
        let desk = try XCTUnwrap(game.desk)
        let first = try XCTUnwrap(game.dueCalls().first)
        XCTAssertEqual(first.state.lastCall, "none")
        await desk.call(first.squad, with: first.state, at: 0)
        var later = game
        _ = later.advance(seconds: 8)
        let next = try XCTUnwrap(later.dueCalls().first { $0.squad == .red })
        XCTAssertEqual(next.state.lastCall, "flank")
        XCTAssertTrue(next.state.prompt.contains("your last call: flank"))
    }

    func testARefusalIsRecordedAndTheMatchGoesOn() async throws {
        // CON-CMD-020's shape, as far as this step reaches: the match takes a failure,
        // keeps running, and holds what it was so a report can count the missed cycles.
        let (game, _) = try match([.failure(.refused)])
        let desk = try XCTUnwrap(game.desk)
        let first = try XCTUnwrap(game.dueCalls().first)
        await desk.call(first.squad, with: first.state, at: 0)
        var later = game
        _ = later.advance(seconds: 0.1)
        XCTAssertEqual(later.commanderFailures.map(\.why), [.refused])
        XCTAssertNil(later.outcome, "a refused call ended the match")
    }
}

final class CommanderCeilingTests: XCTestCase {
    func testTheResponseCeilingComesFromTheMatchConfiguration() throws {
        // FR-CMD-027. The number itself is Q-560: the structure IF-CMD-020 asks for
        // measured 173 to 397 output tokens on 2026-10-11, against the 80 the
        // requirement names as its default, and the shipped file carries what the
        // measurement says the structure needs.
        let match = try Launch.world().get().configurations.match
        XCTAssertGreaterThanOrEqual(match.maximumResponseTokens, 397,
                                    "the shipped ceiling is below the worst answer measured")
        let commander = SystemModelCommander(instructions: "x",
                                             maximumResponseTokens: match.maximumResponseTokens)
        XCTAssertEqual(commander.maximumResponseTokens, match.maximumResponseTokens)
    }
}
