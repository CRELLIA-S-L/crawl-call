// The contract around a commander call, with no model in the room: what a squad's
// commander is told (IF-CMD-010), what it is allowed to answer (IF-CMD-020), what it
// is told beforehand (IF-CMD-040), and the seam that lets a test make a call fail.
//
// file verifies: IF-CMD-010, IF-CMD-020, IF-CMD-040
import XCTest
@testable import CrawlCall

final class CommanderInputTests: XCTestCase {
    private func soldier(_ name: String, standing: String = "up",
                         pouch: String? = nil, place: String = "west side",
                         role: String? = nil) -> CommanderInput.Soldier {
        CommanderInput.Soldier(name: name, standing: standing, pouch: pouch, place: place, role: role)
    }

    private func input(crew: [CommanderInput.Soldier] = [], gone: [String] = [],
                       rivals: String = "not seen", snake: String = "not seen",
                       awareness: String = "calm", lastCall: String = "none",
                       truce: String? = nil, events: [String] = []) -> CommanderInput {
        CommanderInput(crew: crew, gone: gone, rivals: rivals, snake: snake,
                       awareness: awareness, lastCall: lastCall, truce: truce, events: events)
    }

    // MARK: the shape the bench measured

    func testACalmSquadProducesTheFiveLinesTheBenchMeasured() {
        // The prompt bench's own states are five lines, in this order, and that is the
        // configuration its 0-blocks-in-100 reading covers. A state with nothing extra
        // to say must still be that state, or the reading covers nothing we ship.
        let state = input(crew: [soldier("Davis"), soldier("Pike")],
                          rivals: "5 seen, north side", awareness: "calm", lastCall: "hold")
        XCTAssertEqual(state.prompt, """
        crew: Davis and Pike up, west side
        rival crew: 5 seen, north side
        snake: not seen
        awareness: calm
        your last call: hold
        """)
    }

    func testWhatThereIsNothingToSayAboutIsNotSaid() {
        // Roles, a truce and events each add a line only when there is one, so the
        // common call stays the call the bench measured. Four soldiers with nothing
        // the commander gave them cost four names and no clause.
        let bare = input(crew: [soldier("Davis"), soldier("Pike")])
        XCTAssertEqual(bare.prompt.split(separator: "\n").count, 5)
        let full = input(crew: [soldier("Davis", role: "hold the stair"), soldier("Pike")],
                         truce: "they are asking us to stop shooting",
                         events: ["Otto went missing"])
        XCTAssertEqual(full.prompt.split(separator: "\n").count, 8)
        XCTAssertTrue(full.prompt.contains("jobs you gave: Davis hold the stair"))
        XCTAssertTrue(full.prompt.contains("truce: they are asking us to stop shooting"))
        XCTAssertTrue(full.prompt.contains("just happened: Otto went missing"))
    }

    // MARK: every field IF-CMD-010 names

    func testTheStateCarriesEveryFieldTheRequirementNames() {
        let state = input(crew: [soldier("Davis", standing: "up but wobbly", pouch: "running low",
                                          place: "east side, upstairs", role: "cover the door")],
                          gone: ["Kit"],
                          rivals: "3 seen, west side", snake: "4 metres away, middle",
                          awareness: "Kit vanished with no trace", lastCall: "flank",
                          truce: "they want to stop shooting", events: ["Beans went missing"])
        let prompt = state.prompt
        XCTAssertTrue(prompt.contains("up but wobbly"), "health")
        XCTAssertTrue(prompt.contains("running low"), "ammunition")
        XCTAssertTrue(prompt.contains("east side, upstairs"), "position")
        XCTAssertTrue(prompt.contains("cover the door"), "role")
        XCTAssertTrue(prompt.contains("3 seen, west side"), "the enemy")
        XCTAssertTrue(prompt.contains("Kit vanished with no trace"), "awareness")
        XCTAssertTrue(prompt.contains("4 metres away"), "the snake")
        XCTAssertTrue(prompt.contains("your last call: flank"), "the previous decision")
        XCTAssertTrue(prompt.contains("they want to stop shooting"), "a pending truce")
        XCTAssertTrue(prompt.contains("Beans went missing"), "the events since the last call")
        XCTAssertTrue(prompt.contains("Kit gone missing"), "who is gone")
    }

    // MARK: how the crew line is written

    func testSoldiersInDifferentQuartersAreNamedApart() {
        // The grouping is by standing *and* place: a commander told "all up" about a
        // crew spread over two quarters has lost the half of the state it needs to
        // give anybody a position.
        let state = input(crew: [soldier("Davis", place: "west side"),
                                 soldier("Pike", place: "east side")])
        XCTAssertTrue(state.prompt.hasPrefix("crew: Davis up, west side; Pike up, east side\n"),
                      state.prompt)
    }

    func testSoldiersInTheSameStateAreNamedTogether() {
        // Four soldiers the commander need hear nothing particular about cost four
        // names and one clause, not four clauses: the shortest way to say it is the
        // cheapest in tokens and the easiest to read.
        let state = input(crew: [soldier("Davis"), soldier("Pike"), soldier("Marsh"), soldier("Otto")])
        XCTAssertTrue(state.prompt.hasPrefix("crew: Davis, Pike, Marsh and Otto up, west side\n"),
                      state.prompt)
    }

    func testOneWithAnEmptyingPouchIsNamedOnItsOwn() {
        let state = input(crew: [soldier("Davis"), soldier("Pike", pouch: "pouch empty")])
        XCTAssertTrue(state.prompt.hasPrefix("crew: Davis up, west side; Pike up, pouch empty, west side\n"),
                      state.prompt)
    }

    func testASquadWithNobodyLeftSaysSo() {
        // The edge the game can reach: everybody gone. A line reading "crew: " with
        // nothing after it is a state the model has to guess at.
        let state = input(crew: [], gone: ["Davis", "Pike"])
        XCTAssertTrue(state.prompt.hasPrefix("crew: Davis and Pike gone missing\n"))
        let empty = input(crew: [], gone: [])
        XCTAssertTrue(empty.prompt.hasPrefix("crew: nobody left\n"))
    }

    func testNamesAreListedTheWayEnglishListsThem() {
        XCTAssertEqual(CommanderInput.list([]), "")
        XCTAssertEqual(CommanderInput.list(["Davis"]), "Davis")
        XCTAssertEqual(CommanderInput.list(["Davis", "Pike"]), "Davis and Pike")
        XCTAssertEqual(CommanderInput.list(["Davis", "Pike", "Marsh"]), "Davis, Pike and Marsh")
    }

    // MARK: the vocabulary (IF-CMD-010, ADR-0017)

    func testTheStateNeverUsesTheWordsThatWereBlocked() throws {
        // The same situation written as wounds and bodies was blocked in 10 of 10 bench
        // calls and in the game's own words in 0 of 10. These are the words from the
        // "grim" scenario that "grim-soft" replaced, plus the plain ones for dying.
        let forbidden = ["bleed", "blood", "wound", "dead", "death", "died", "kill",
                         "corpse", "body", "bodies", "scream", "crush", "execut", "tear"]
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        let bots = Game(world: world, start: start).bots
        // Every state the words can come from: whole, hurt, gone, and the snake known.
        var hurt = bots
        hurt[try checkedIndex(0, of: hurt)].health = 1
        hurt[try checkedIndex(1, of: hurt)].health = .zero
        for level in [Awareness.calm, .alarm, .confirmed] {
            let crew = SquadView.crew(of: .red, among: hurt, in: world.plan.bounds,
                                      configuration: world.configurations.bot)
            let state = input(crew: crew.crew, gone: crew.gone,
                              snake: "3 metres away, middle",
                              awareness: SquadView.awareness(level, gone: crew.gone))
            let said = state.prompt.lowercased()
            for word in forbidden {
                XCTAssertFalse(said.contains(word), "\(level) said \(word): \(state.prompt)")
            }
        }
    }

    // MARK: the token budget (IF-CMD-010, CON-CMD-010)

    func testTheFullestStateTheGameCanBuildFitsTheBudget() throws {
        // The budget is the match configuration's, 1000 tokens. The state below is
        // fuller than a match produces: six soldiers rather than the four a squad
        // fields, every one of them with a job and an emptying pouch, a truce, and an
        // event for each of them.
        let budget = try Launch.world().get().configurations.match.stateTokenBudget
        let names = ["Davis", "Pike", "Marsh", "Otto", "Beans", "Kit"]
        let crew = names.map { soldier($0, standing: "up but wobbly", pouch: "running low",
                                       place: "north-east, upstairs",
                                       role: "hold the stair by the crates") }
        let state = input(crew: crew, gone: names,
                          rivals: "6 seen, west side, east side and middle",
                          snake: "4 metres away, north-east, upstairs",
                          awareness: "there is a snake and it takes people",
                          lastCall: "withdrawToZone",
                          truce: "they are shouting at us to stop shooting",
                          events: names.map { "\($0) went missing by the crates" })
        XCTAssertLessThan(state.estimatedTokens, budget,
                          "the fullest state is \(state.estimatedTokens) tokens of \(budget)")
        // And the estimate is the conservative side of what was measured: the bench's
        // `alarm` state is 168 characters and counted 52 tokens on 2026-10-11, which is
        // 3.23 characters a token, so dividing by 3 over-counts rather than under.
        XCTAssertLessThan(CommanderInput.charactersPerToken, 168.0 / 52.0)
    }
}

final class SquadViewTests: XCTestCase {
    private func world() throws -> World { try Launch.world().get() }

    func testTheSixFiguresAreTheOnesTheBenchMeasured() {
        // The names are part of the configuration a prompt measurement covers: the
        // instructions name the same six, and a seventh would be a word the guardrail
        // has never seen in this register.
        XCTAssertEqual(Set(Archetype.allCases.map(SquadView.name(of:))),
                       ["Davis", "Pike", "Marsh", "Otto", "Beans", "Kit"])
        XCTAssertEqual(Set(SquadView.names.values).count, Archetype.allCases.count)
    }

    func testWhatIsLeftOfASoldierIsSaidInThreeBands() throws {
        let world = try world()
        let whole = try XCTUnwrap(world.configurations.bot.archetypes["assault"]).health
        let start = try XCTUnwrap(Game.firstStart(in: world))
        var bot = try XCTUnwrap(Game(world: world, start: start).bots.first)
        bot.health = whole
        XCTAssertEqual(SquadView.standing(of: bot, whole: whole), "up")
        bot.health = whole * 0.5
        XCTAssertEqual(SquadView.standing(of: bot, whole: whole), "up but wobbly")
        bot.health = whole * 0.1
        XCTAssertEqual(SquadView.standing(of: bot, whole: whole), "flat on his back")
    }

    func testAHalfFullPouchIsNotWorthSaying() throws {
        let world = try world()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        var bot = try XCTUnwrap(Game(world: world, start: start).bots.first)
        let magazine = try XCTUnwrap(world.configurations.bot.archetypes[bot.archetype.rawValue]).magazine
        bot.ammunition = magazine
        XCTAssertNil(SquadView.pouch(of: bot, magazine: magazine))
        bot.ammunition = magazine / 4
        XCTAssertEqual(SquadView.pouch(of: bot, magazine: magazine), "running low")
        bot.ammunition = .zero
        XCTAssertEqual(SquadView.pouch(of: bot, magazine: magazine), "pouch empty")
    }

    func testAPlaceIsAQuarterOfTheArenaAndNotAPairOfMetres() throws {
        let bounds = ScenePlan.Bounds(lowest: SIMD3(-10, 0, -10), highest: SIMD3(10, 3, 10))
        XCTAssertEqual(SquadView.place(of: SIMD3(0, 0, 0), floor: 0, in: bounds), "middle")
        XCTAssertEqual(SquadView.place(of: SIMD3(9, 0, 0), floor: 0, in: bounds), "east side")
        XCTAssertEqual(SquadView.place(of: SIMD3(-9, 0, 0), floor: 0, in: bounds), "west side")
        XCTAssertEqual(SquadView.place(of: SIMD3(0, 0, -9), floor: 0, in: bounds), "north side")
        XCTAssertEqual(SquadView.place(of: SIMD3(0, 0, 9), floor: 0, in: bounds), "south side")
        XCTAssertEqual(SquadView.place(of: SIMD3(9, 0, 9), floor: 0, in: bounds), "south-east")
        XCTAssertEqual(SquadView.place(of: SIMD3(9, 0, 9), floor: 1, in: bounds), "south-east, upstairs")
    }

    func testACalmSquadIsNotToldAboutTheSnakeItHasSeen() throws {
        // FR-CMD-070's half that lives here: the omission is a property of the state,
        // whatever the knowledge holds.
        var known = Knowledge()
        known.snake = [0: Knowledge.Sighting(point: SIMD3(3, 0, 0), time: 1)]
        let bounds = ScenePlan.Bounds(lowest: SIMD3(-10, 0, -10), highest: SIMD3(10, 3, 10))
        XCTAssertEqual(SquadView.snake(known: known, awareness: .calm, from: .zero, in: bounds),
                       "not seen")
        XCTAssertTrue(SquadView.snake(known: known, awareness: .confirmed, from: .zero, in: bounds)
                        .hasPrefix("3 metres away"))
    }

    func testTheEnemyIsCountedFromWhatWasSeenAndNotFromWhereItIs() throws {
        // A squad that has seen nobody is told nobody, however many there truly are.
        let bounds = ScenePlan.Bounds(lowest: SIMD3(-10, 0, -10), highest: SIMD3(10, 3, 10))
        XCTAssertEqual(SquadView.rivals(known: Knowledge(), in: bounds), "not seen")
        var known = Knowledge()
        known.enemies = [4: Knowledge.Sighting(point: SIMD3(9, 0, 0), time: 1),
                         5: Knowledge.Sighting(point: SIMD3(8, 0, 0), time: 1)]
        XCTAssertEqual(SquadView.rivals(known: known, in: bounds), "2 seen, east side")
    }

    func testAwarenessIsSaidInTheGamesOwnWords() {
        XCTAssertEqual(SquadView.awareness(.calm, gone: []), "calm")
        XCTAssertEqual(SquadView.awareness(.alarm, gone: ["Kit"]), "Kit vanished with no trace")
        XCTAssertEqual(SquadView.awareness(.alarm, gone: ["Kit", "Otto"]),
                       "2 of ours vanished with no trace")
        XCTAssertEqual(SquadView.awareness(.confirmed, gone: []), "there is a snake and it takes people")
    }
}

final class CommanderDecisionTests: XCTestCase {
    func testTheChoicesAreExactlyTheOnesTheRequirementNames() {
        XCTAssertEqual(Set(CommanderDecision.Threat.allCases.map(\.rawValue)),
                       ["enemy", "snake", "withdraw"])
        XCTAssertEqual(Set(CommanderDecision.Order.allCases.map(\.rawValue)),
                       ["hold", "flank", "withdrawToZone", "disperse", "destroyCover"])
        XCTAssertEqual(Set(CommanderDecision.Truce.allCases.map(\.rawValue)),
                       ["none", "propose", "accept", "reject"])
    }

    func testNoJobIsTheWordNoneInAnyCasing() {
        XCTAssertNil(SystemModelCommander.job("none"))
        XCTAssertNil(SystemModelCommander.job("None"))
        XCTAssertNil(SystemModelCommander.job("  NONE  "))
        XCTAssertNil(SystemModelCommander.job(""))
        XCTAssertNil(SystemModelCommander.job("   "))
        XCTAssertEqual(SystemModelCommander.job(" hold the stair "), "hold the stair")
    }

    func testALeanIsFoundByName() {
        let lean = CommanderDecision.Lean(name: "Davis", role: nil, panic: 0.5, courage: 0.5,
                                          discipline: 0.5, aggression: 0.5, selfSacrifice: 0.5)
        let decision = CommanderDecision(threat: .snake, order: .hold, crew: [lean],
                                         truce: .none, line: nil)
        XCTAssertEqual(decision.lean(for: "Davis"), lean)
        XCTAssertNil(decision.lean(for: "Pike"))
    }
}

final class CommanderInstructionsTests: XCTestCase {
    private func instructions() throws -> String {
        try Launch.world().get().configurations.commander.instructions
    }

    func testTheInstructionsEstablishEverythingTheRequirementAsksFor() throws {
        // IF-CMD-040 names five things the instructions must establish. Each is checked
        // by a word the text cannot lose without losing the obligation; the test is
        // what goes red when somebody trims the prompt to save tokens without saying
        // which obligation they dropped.
        let text = try instructions().lowercased()
        XCTAssertTrue(text.contains("rival crew"), "that a rival squad is in the arena")
        XCTAssertTrue(text.contains("snake"), "that a snake is in the arena")
        XCTAssertTrue(text.contains("in charge of one crew"), "that the reader commands one squad")
        XCTAssertTrue(text.contains("never with prose"), "that the answer is a decision and not prose")
        XCTAssertTrue(text.contains("not seen it and you do not know it"),
                      "that nothing outside the squad's own knowledge may be assumed")
    }

    func testTheInstructionsExplainEveryFieldOfTheAnswer() throws {
        let text = try instructions()
        for threat in CommanderDecision.Threat.allCases where threat != .withdraw {
            XCTAssertTrue(text.contains(threat.rawValue), "the threat \(threat.rawValue)")
        }
        for order in CommanderDecision.Order.allCases {
            XCTAssertTrue(text.contains(order.rawValue), "the order \(order.rawValue)")
        }
        for weight in ["panic", "courage", "discipline", "aggression", "selfSacrifice"] {
            XCTAssertTrue(text.contains(weight), "the weight \(weight)")
        }
        XCTAssertTrue(text.contains("0 to 1"), "the range of the weights")
        XCTAssertTrue(text.contains("truce"), "the truce action")
        XCTAssertTrue(text.contains("line"), "the line")
    }

    func testTheInstructionsCarryTheContentRules() throws {
        let text = try instructions().lowercased()
        XCTAssertTrue(text.contains("no real people"), "no real person, organisation or conflict")
        XCTAssertTrue(text.contains("nothing rude"), "nothing beyond the rating")
        XCTAssertTrue(text.contains("nobody hurt and nobody dead"), "no wound and no death")
        XCTAssertTrue(text.contains("slapstick"), "the register the measurement was taken in")
    }

    func testTheInstructionsNameTheSameSixFiguresTheStateDoes() throws {
        let text = try instructions()
        for name in SquadView.names.values {
            XCTAssertTrue(text.contains(name), "the instructions do not name \(name)")
        }
    }
}

final class SeamTests: XCTestCase {
    private let lean = CommanderDecision.Lean(name: "Davis", role: nil, panic: 0.5, courage: 0.5,
                                              discipline: 0.5, aggression: 0.5, selfSacrifice: 0.5)
    private var decision: CommanderDecision {
        CommanderDecision(threat: .snake, order: .hold, crew: [lean], truce: .none, line: nil)
    }
    private let state = CommanderInput(crew: [], gone: [], rivals: "not seen", snake: "not seen",
                                       awareness: "calm", lastCall: "none", truce: nil, events: [])

    func testAScriptedCommanderAnswersInTheOrderItWasGiven() async {
        let commander = ScriptedCommander([.decision(decision), .failure(.refused)])
        let first = await commander.decide(from: state)
        let second = await commander.decide(from: state)
        XCTAssertEqual(try? first.get(), decision)
        XCTAssertEqual(second, .failure(.refused))
        XCTAssertEqual(commander.callCount, 2)
    }

    func testAScriptLoopsSoARefusalRateCanBeScripted() async {
        // CON-CMD-020 is about one call in five being refused, and this is how a test
        // says that: a script of five with one refusal, run ten times, refuses twice.
        let script: [ScriptedCommander.Reply] = [.decision(decision), .decision(decision),
                                                 .failure(.refused), .decision(decision),
                                                 .decision(decision)]
        let commander = ScriptedCommander(script)
        var refusals = 0
        for _ in 0..<10 {
            if await commander.decide(from: state) == .failure(.refused) { refusals += 1 }
        }
        XCTAssertEqual(refusals, 2)
    }

    func testAScriptThatDoesNotLoopRunsOut() async {
        let commander = ScriptedCommander([.decision(decision)], loops: false)
        _ = await commander.decide(from: state)
        let after = await commander.decide(from: state)
        XCTAssertEqual(after, .failure(.unavailable("the script is spent")))
    }

    func testAnEmptyScriptIsNotAnAnswer() async {
        let commander = ScriptedCommander([])
        let answer = await commander.decide(from: state)
        XCTAssertEqual(answer, .failure(.unavailable("the script is empty")))
    }

    func testACommanderThatIsNotThereSaysSoWithoutBeingCalled() {
        XCTAssertFalse(ScriptedCommander([.decision(decision)], available: false).isAvailable)
        XCTAssertTrue(ScriptedCommander([.decision(decision)]).isAvailable)
    }

    func testEveryStateHandedOverIsKept() async {
        // What a test reads to check what the commander was told — which is how
        // FR-CMD-070's omission is checked once there is a call to make.
        let commander = ScriptedCommander([.decision(decision)])
        _ = await commander.decide(from: state)
        XCTAssertEqual(commander.heard, [state])
    }
}
