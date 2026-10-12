// What losing the role-holder does: no more calls, no order, no roles, and more panic
// in whoever is left (concept §9.4). The player's main lever on the war, and the
// reason the role has no marker — it is found by listening, not by looking.
//
// file verifies: FR-CMD-120, FR-CMD-125, FR-CMD-130
import XCTest
@testable import CrawlCall

final class SquadCollapseTests: XCTestCase {
    private var configuration: BotConfiguration!

    override func setUpWithError() throws {
        try super.setUpWithError()
        configuration = try Launch.world().get().configurations.bot
    }

    private func bot(_ kind: Archetype = .assault, squad: Squad = .red, id: Int = 0,
                     commander: Bool = false, alive: Bool = true) throws -> Bot {
        var made = try XCTUnwrap(Bot(id: id, squad: squad, archetype: kind, at: .zero, floor: 0,
                                     configuration: configuration))
        made.isCommander = commander
        if !alive { made.health = .zero }
        return made
    }

    private func decision(_ order: CommanderDecision.Order = .flank) -> CommanderDecision {
        CommanderDecision(threat: .enemy, order: order,
                          crew: [CommanderDecision.Lean(name: "Davis", role: "hold the stair", panic: 0.4,
                                                        courage: 0.6, discipline: 0.7, aggression: 0.8,
                                                        selfSacrifice: 0.3)],
                          truce: .none, line: nil)
    }

    // MARK: when a squad is counted as fallen

    func testASquadWhoseLivingHolderIsGoneHasFallen() throws {
        let holder = try bot(id: 0, commander: true, alive: false)
        let rest = try bot(.heavy, id: 1)
        XCTAssertTrue(SquadCommands.collapses(.red, among: [holder, rest]))
    }

    func testASquadWithItsHolderAliveHasNot() throws {
        let holder = try bot(id: 0, commander: true)
        let rest = try bot(.heavy, id: 1)
        XCTAssertFalse(SquadCommands.collapses(.red, among: [holder, rest]))
    }

    func testASquadWithNobodyLeftAliveHasNotFallenButEnded() throws {
        // Nothing to take an order away from. A squad wiped out is the match's
        // business (FR-SCORE-150), not the commander's.
        let holder = try bot(id: 0, commander: true, alive: false)
        let rest = try bot(.heavy, id: 1, alive: false)
        XCTAssertFalse(SquadCommands.collapses(.red, among: [holder, rest]))
    }

    func testOneSquadsLossIsNotTheOthers() throws {
        let fallen = try bot(id: 0, commander: true, alive: false)
        let left = try bot(.heavy, id: 1)
        let standing = try bot(squad: .blue, id: 2, commander: true)
        XCTAssertTrue(SquadCommands.collapses(.red, among: [fallen, left, standing]))
        XCTAssertFalse(SquadCommands.collapses(.blue, among: [fallen, left, standing]))
    }

    // MARK: what the collapse does (FR-CMD-120, FR-CMD-125, FR-CMD-130)

    func testTheOrderAndEveryRoleAreVoided() throws {
        var bots = [try bot(id: 0, commander: true, alive: false), try bot(.heavy, id: 1)]
        var commands = SquadCommands()
        commands.apply(decision(), to: .red, among: &bots, configuration: configuration)
        let heavy = try checkedIndex(1, of: bots)
        bots[heavy].role = "cover Davis"
        XCTAssertNotNil(commands.of(.red))

        commands.collapse(.red, among: &bots, configuration: configuration)
        XCTAssertNil(commands.of(.red), "a squad with no commander still stood under an order")
        XCTAssertTrue(commands.hasCollapsed(.red))
        XCTAssertNil(try element(1, of: bots).role)
        XCTAssertNil(try element(0, of: bots).role, "the body kept the role it was given")
    }

    func testTheSurvivorsKeepTheirWeightsWithMorePanic() throws {
        var bots = [try bot(id: 0, commander: true, alive: false), try bot(.heavy, id: 1)]
        var commands = SquadCommands()
        commands.apply(decision(), to: .red, among: &bots, configuration: configuration)
        let before = try element(1, of: bots).weights

        commands.collapse(.red, among: &bots, configuration: configuration)
        let after = try element(1, of: bots).weights
        XCTAssertEqual(after.panic, before.panic + configuration.collapsePanicIncrement, accuracy: 1e-12)
        XCTAssertEqual(after.discipline, before.discipline)
        XCTAssertEqual(after.aggression, before.aggression)
        XCTAssertEqual(after.selfSacrifice, before.selfSacrifice)
        XCTAssertEqual(after.courage, before.courage)
    }

    func testPanicIsNotRaisedPastWhatTheArchetypeAllows() throws {
        var soldier = try bot(.heavy, id: 1)
        soldier.weights = BotConfiguration.Weights(panic: 0.9, discipline: 0.5, aggression: 0.5,
                                                   selfSacrifice: 0.5, courage: 0.5)
        let highest = try XCTUnwrap(configuration.archetypes[Archetype.heavy.rawValue]?
            .allowedRanges["panic"]?.highest)
        XCTAssertGreaterThan(0.9 + configuration.collapsePanicIncrement, highest,
                             "the fixture does not reach the bound it is testing")
        XCTAssertEqual(SquadCommands.panicking(soldier, by: configuration.collapsePanicIncrement,
                                               configuration: configuration).panic, highest)
    }

    func testACollapseHappensOnceAndTheSecondTimeChangesNothing() throws {
        var bots = [try bot(id: 0, commander: true, alive: false), try bot(.heavy, id: 1)]
        var commands = SquadCommands()
        commands.collapse(.red, among: &bots, configuration: configuration)
        let once = try element(1, of: bots).weights
        commands.collapse(.red, among: &bots, configuration: configuration)
        XCTAssertEqual(try element(1, of: bots).weights, once, "the panic was raised twice")
    }

    func testABodyKeepsTheWeightsItDiedWith() throws {
        // FR-CMD-130 says every surviving bot, and a body is not one: nothing reads a
        // dead bot's weights, and raising them would be a number nobody can see.
        var bots = [try bot(id: 0, commander: true, alive: false)]
        let before = try element(0, of: bots).weights
        var commands = SquadCommands()
        commands.collapse(.red, among: &bots, configuration: configuration)
        XCTAssertEqual(try element(0, of: bots).weights, before)
    }

    func testTheOtherSquadIsLeftAlone() throws {
        var bots = [try bot(id: 0, commander: true, alive: false),
                    try bot(squad: .blue, id: 1, commander: true)]
        var commands = SquadCommands()
        commands.apply(decision(.hold), to: .blue, among: &bots, configuration: configuration)
        let before = try element(1, of: bots).weights

        commands.collapse(.red, among: &bots, configuration: configuration)
        XCTAssertEqual(commands.of(.blue)?.order, .hold)
        XCTAssertFalse(commands.hasCollapsed(.blue))
        XCTAssertEqual(try element(1, of: bots).weights, before)
    }
}

/// The whole way through: the snake eats the bot that speaks for a squad, and the
/// squad falls apart (concept §9.4 — the player's main lever on the war).
final class CollapsedMatchTests: XCTestCase {
    private func decision() -> CommanderDecision {
        CommanderDecision(threat: .enemy, order: .hold,
                          crew: [CommanderDecision.Lean(name: "Davis", role: "hold the stair", panic: 0.4,
                                                        courage: 0.6, discipline: 0.7, aggression: 0.8,
                                                        selfSacrifice: 0.3)],
                          truce: .none, line: nil)
    }

    private func match() throws -> Game {
        let world = try Launch.world().get()
        let start = try XCTUnwrap(Game.firstStart(in: world))
        return Game(world: world, start: start, commander: ScriptedCommander([.decision(decision())]))
    }

    func testEatingTheRoleHolderCollapsesItsSquadAndItIsCalledNoMore() throws {
        var game = try match()
        XCTAssertFalse(game.commands.hasCollapsed(.red))
        XCTAssertTrue(game.dueCalls().contains { $0.squad == .red })
        let holder = try XCTUnwrap(game.bots.first { $0.squad == .red && $0.isCommander })

        // The meal itself, through the game's own act: the reach and the intent are
        // the player's business (FR-SNAKE-270) and are not what this test is about.
        game.begin(eating: holder.id)
        let frame = 1.0 / 60
        var frames = 0
        while game.bots.contains(where: { $0.id == holder.id }) && frames < Int(60 / frame) {
            game.advance(seconds: frame)
            frames += 1
        }
        XCTAssertFalse(game.bots.contains { $0.id == holder.id }, "the meal never finished")

        XCTAssertTrue(game.commands.hasCollapsed(.red))
        XCTAssertNil(game.commands.of(.red))
        XCTAssertFalse(game.bots.contains { $0.squad == .red && $0.role != nil })
        // FR-CMD-120: never called again, however long the match runs.
        for _ in 0..<Int(20 / frame) { game.advance(seconds: frame) }
        XCTAssertFalse(game.dueCalls().contains { $0.squad == .red },
                       "a squad with no role-holder was called again")
        // And the other squad is untouched: this is one squad falling apart, not the
        // commander layer switching itself off.
        XCTAssertFalse(game.commands.hasCollapsed(.blue))
        XCTAssertTrue(game.bots.contains { $0.squad == .blue && $0.isAlive && $0.isCommander })
    }

    func testASquadWhoseHolderIsStandingIsNeverCollapsed() throws {
        // The negation: the check runs on every frame, and on every frame it finds
        // nothing to do while the holders are alive.
        var game = try match()
        for _ in 0..<600 { game.advance(seconds: 1.0 / 60) }
        XCTAssertFalse(game.commands.hasCollapsed(.red))
        XCTAssertFalse(game.commands.hasCollapsed(.blue))
    }
}
