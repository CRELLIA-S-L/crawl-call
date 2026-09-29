// What a squad knows of the snake (FR-SCORE-130): calm to start with and only ever
// rising; confirmed by a witness of a meal once its report is in (FR-SCORE-070,
// FR-SCORE-080, FR-SCORE-090), and not by one eaten first (FR-SCORE-100); alarmed by a
// squadmate's body gone from where it fell (FR-SCORE-125) — which only the snake can
// have taken, since the squads leave bodies where they lie (INV-BOT-020).
//
// verifies: FR-SCORE-130, FR-SCORE-070, FR-SCORE-080, FR-SCORE-090, FR-SCORE-100, FR-SCORE-125, INV-BOT-020, IF-SCORE-010
import XCTest
@testable import CrawlCall

final class AwarenessTests: XCTestCase {
    private var world: World!
    private let frame = 1.0 / 60

    override func setUpWithError() throws {
        try super.setUpWithError()
        let shipped = try Launch.world().get()
        // An open strip, forty metres long: nothing stands between anybody.
        let rows = Array(repeating: String(repeating: ".", count: 80), count: 3)
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        let cell = shipped.configurations.tuning.navigationGraphCellSize
        world = World(configurations: shipped.configurations, kit: shipped.kit, map: map, setting: shipped.setting,
                      graph: NavigationGraph.derive(from: map, stepHeight: shipped.configurations.tuning.stepHeight),
                      plan: ScenePlan.make(map: map, kit: shipped.kit, cellSize: cell))
    }

    private var scoring: ScoringConfiguration { world.configurations.scoring }

    /// A bot on the strip's middle line at `x` metres, facing +x, or −x where `back`.
    private func bot(_ id: Int, _ squad: Squad = .red, at x: Double, back: Bool = false) throws -> Bot {
        var bot = try XCTUnwrap(Bot(id: id, squad: squad, archetype: .assault, at: SIMD3(x, 0, 0.5), floor: 0,
                                    configuration: world.configurations.bot))
        bot.facing = back ? -.pi / 2 : .pi / 2
        return bot
    }

    private func step(_ stealth: inout Stealth, _ before: [Bot], _ after: [Bot], prey: Int?, at now: Double) {
        stealth.step(before: Interrupts.glance(before), after: after, prey: prey, plan: world.plan,
                     bot: world.configurations.bot, scoring: scoring, now: now)
    }

    func testTheScoringConfigurationIsReadFromItsFile() {
        XCTAssertGreaterThanOrEqual(scoring.witnessWindow, 2, "the window FR-SCORE-070 bounds between 2 and 3 s")
        XCTAssertLessThanOrEqual(scoring.witnessWindow, 3)
        XCTAssertGreaterThan(scoring.reportDelay, 0)
        XCTAssertGreaterThan(scoring.inspectionDistance, 0)
    }

    func testASquadStartsCalmAndItsStateOnlyRises() {
        var stealth = Stealth()
        for squad in Squad.allCases { XCTAssertEqual(stealth.of(squad), .calm) }
        stealth.raise(.red, to: .confirmed)
        stealth.raise(.red, to: .alarm)
        XCTAssertEqual(stealth.of(.red), .confirmed, "the state went down")
        XCTAssertEqual(stealth.of(.blue), .calm, "one squad's state moved the other's")
    }

    func testAWitnessOfAMealConfirmsItsSquadOnceItsReportIsIn() throws {
        let watcher = try bot(0, at: 5)
        let prey = try bot(1, .blue, at: 8)
        var stealth = Stealth()
        var now = 10.0
        step(&stealth, [watcher, prey], [watcher, prey], prey: prey.id, at: now)
        XCTAssertEqual(stealth.of(.red), .calm, "the squad knew before the witness reported")
        // Just before the delay is out, still calm; once it is, confirmed.
        now += scoring.reportDelay - frame
        step(&stealth, [watcher, prey], [watcher, prey], prey: prey.id, at: now)
        XCTAssertEqual(stealth.of(.red), .calm)
        now += frame * 2
        step(&stealth, [watcher, prey], [watcher, prey], prey: prey.id, at: now)
        XCTAssertEqual(stealth.of(.red), .confirmed)
        XCTAssertEqual(stealth.of(.blue), .calm, "the prey's squad saw nothing and learnt it")
    }

    func testABotThatSeesWhereAMealWasWithinTheWindowAfterIsAWitnessAndLaterIsNot() throws {
        let prey = try bot(1, .blue, at: 8)
        for (after, witnessed) in [(scoring.witnessWindow * 0.9, true), (max(scoring.witnessWindow, scoring.lateArrivalWindow) + 0.5, false)] {
            // Looking away while the meal lasts, then turning round to where it was.
            let away = try bot(0, at: 5, back: true)
            let looking = try bot(0, at: 5)
            var stealth = Stealth()
            step(&stealth, [away, prey], [away, prey], prey: prey.id, at: 10)
            step(&stealth, [away, prey], [away], prey: nil, at: 11)   // eaten: the meal is over
            step(&stealth, [looking], [looking], prey: nil, at: 11 + after)
            step(&stealth, [looking], [looking], prey: nil, at: 11 + after + scoring.reportDelay + frame)
            XCTAssertEqual(stealth.of(.red) == .confirmed, witnessed,
                           "\(after) s after the meal, the bot that came to see was \(witnessed ? "not " : "")taken for a witness")
        }
    }

    func testAWitnessEatenBeforeItReportsSaysNothing() throws {
        let watcher = try bot(0, at: 5)
        let prey = try bot(1, .blue, at: 8)
        var stealth = Stealth()
        step(&stealth, [watcher, prey], [watcher, prey], prey: prey.id, at: 10)
        // The witness is taken before its report is due.
        step(&stealth, [watcher, prey], [prey], prey: watcher.id, at: 11)
        step(&stealth, [prey], [prey], prey: nil, at: 10 + scoring.reportDelay + 1)
        XCTAssertEqual(stealth.of(.red), .calm, "a consumed witness reported")
    }

    func testASquadmateGoneFromWhereItFellRaisesTheAlarmWhenSomebodyComesToLook() throws {
        let lost = try bot(0, at: 20)
        let far = try bot(1, at: 5)
        var stealth = Stealth()
        // Taken where it stood, with nobody of its squad near: nothing yet.
        step(&stealth, [lost, far], [far], prey: nil, at: 10)
        XCTAssertEqual(stealth.of(.red), .calm)
        // A squadmate comes to where it was and finds no body.
        let near = try bot(1, at: 20 + scoring.inspectionDistance * 0.5)
        step(&stealth, [far], [near], prey: nil, at: 20)
        XCTAssertEqual(stealth.of(.red), .alarm)
        XCTAssertEqual(stealth.of(.blue), .calm)
    }

    func testABodyLyingWhereItFellRaisesNothing() throws {
        let shot = try bot(0, at: 20)
        var body = shot
        body.health = 0
        let near = try bot(1, at: 20 + scoring.inspectionDistance * 0.5)
        var stealth = Stealth()
        step(&stealth, [shot, near], [body, near], prey: nil, at: 10)
        step(&stealth, [body, near], [body, near], prey: nil, at: 11)
        XCTAssertEqual(stealth.of(.red), .calm, "a body where it fell is a war's, and raised the alarm")
        // Then the snake takes it, and the one standing by finds it gone.
        step(&stealth, [body, near], [near], prey: nil, at: 12)
        XCTAssertEqual(stealth.of(.red), .alarm)
    }

    func testTheSquadsLeaveABodyWhereItLies() throws {
        // Bots crowding round a body and walking over it do not move it (INV-BOT-020).
        var body = try bot(0, at: 10)
        body.health = 0
        var bots = [body]
        for id in 1...4 {
            var walker = try bot(id, at: 10 + Double(id) * 0.1)
            walker.action = .flee(to: NavigationGraph.Node(floor: 0, x: 0, z: 1))
            bots.append(walker)
        }
        for _ in 0..<120 { Execution.walk(&bots, seconds: frame, world: world) }
        let after = try XCTUnwrap(bots.first { $0.id == body.id })
        XCTAssertEqual(Perception.metres(after.position, body.position), 0, accuracy: 1e-12, "the squads moved a body")
    }

    func testInAMatchAMealIsFollowedAndItsPreyCountedLost() throws {
        var game = Game(world: world, start: NavigationGraph.Node(floor: 0, x: 40, z: 1))
        let prey = try XCTUnwrap(game.bots.first)
        game.begin(eating: prey.id)
        game.advance(seconds: frame)
        XCTAssertEqual(game.stealth.meals.last?.prey, prey.id, "the meal was not followed")
        for _ in 0..<(60 * 30) where game.bots.contains(where: { $0.id == prey.id }) { game.advance(seconds: frame) }
        XCTAssertFalse(game.bots.contains { $0.id == prey.id }, "the meal never ended")
        XCTAssertEqual(game.stealth.losses[prey.id]?.squad, prey.squad, "the eaten bot was not counted lost")
    }
}
