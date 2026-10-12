// A round flies (FR-BOT-060): sent from the shooter's eyes at the point where its target
// is as it fires, at the round speed; it strikes the first body in its way, whoever's
// it is, but never the one that fired it (FR-BOT-400); it stops at a wall and once it
// has flown the round range (FR-BOT-405); and a bot does not fire through a squadmate
// it sees (FR-BOT-410).
//
// file verifies: FR-BOT-060, FR-BOT-400, FR-BOT-405, FR-BOT-410
import XCTest
@testable import CrawlCall

final class RoundTests: XCTestCase {
    private var shipped: World!
    private var configuration: BotConfiguration { shipped.configurations.bot }
    private var radius: Double { shipped.configurations.tuning.bodyRadius }
    private let cell = 0.5
    private let east = Double.pi / 2
    private let frame = 1.0 / 60

    override func setUpWithError() throws {
        try super.setUpWithError()
        shipped = try Launch.world().get()
    }

    private func world(_ rows: String...) throws -> World {
        let map = try MapParser.parse("kit blockout\nsetting greenholm\nfloor 0\n" + rows.joined(separator: "\n") + "\n",
                                      kit: shipped.kit)
        return World(configurations: shipped.configurations, kit: shipped.kit, map: map, setting: shipped.setting,
                     graph: NavigationGraph.derive(from: map, stepHeight: shipped.configurations.tuning.stepHeight),
                     plan: ScenePlan.make(map: map, kit: shipped.kit, cellSize: cell))
    }

    private func at(_ x: Int, _ z: Int) -> SIMD3<Double> { SIMD3(Double(x) * cell, 0, Double(z) * cell) }

    private func bot(_ id: Int, _ squad: Squad, at x: Int, _ z: Int, facing: Double? = nil) throws -> Bot {
        var made = try XCTUnwrap(Bot(id: id, squad: squad, archetype: .assault, at: at(x, z), floor: 0,
                                     configuration: configuration))
        made.facing = facing ?? east
        return made
    }

    /// What one round of an assault's primary deals (FR-BOT-450).
    private var damage: Double {
        configuration.archetypes["assault"].flatMap { configuration.weapons.firearms[$0.arms.primary]?.damage } ?? .nan
    }

    private func round(from shooter: Bot, towards point: SIMD3<Double>) throws -> Round {
        try XCTUnwrap(Round(shooter: shooter.id, squad: shooter.squad, from: shooter.eye, towards: point, damage: damage))
    }

    private func fly(_ rounds: inout [Round], _ bots: inout [Bot], snake: [SIMD3<Double>] = [], in world: World,
                     frames: Int) -> Flight.Struck {
        var struck = Flight.Struck()
        for _ in 0..<frames {
            let one = Flight.fly(&rounds, seconds: frame, bots: &bots, snake: snake, plan: world.plan,
                                 configuration: configuration, bodyRadius: radius)
            struck.damage += one.damage
            struck.hits += one.hits
        }
        return struck
    }

    // MARK: sent, and flying (FR-BOT-060)

    func testABotSendsARoundFromItsEyesAtWhereItsTargetIsNow() throws {
        let floor = try world(String(repeating: ".", count: 24))
        var shooter = try bot(0, .red, at: 1, 0)
        shooter.knowledge.enemies = [1: .init(point: at(9, 0), time: 2)]
        let enemy = try bot(1, .blue, at: 9, 0, facing: -east)
        var bots = [shooter, enemy]
        let volley = Execution.deliberate(&bots, slots: [0], world: floor, now: 2)
        let sent = try XCTUnwrap(volley.rounds.first)
        XCTAssertEqual(volley.rounds.count, 1)
        XCTAssertEqual(Perception.metres(sent.from, shooter.eye), 0, accuracy: 1e-12, "not from the shooter's eyes")
        XCTAssertEqual(Perception.metres(sent.towards, enemy.eye), 0, accuracy: 1e-12, "not at the enemy's eyes")
        XCTAssertEqual(sent.shooter, 0)
        XCTAssertEqual(sent.squad, .red)
        XCTAssertEqual(sent.damage, damage)
        // Nobody is struck at the moment of firing: it has four metres to fly.
        XCTAssertEqual(try element(1, of: bots).health, enemy.health, "the enemy was struck before the round got there")
    }

    func testARoundFliesAtTheRoundSpeed() throws {
        let floor = try world(String(repeating: ".", count: 80))
        var bots = [try bot(0, .red, at: 1, 0)]
        var rounds = [try round(from: try element(0, of: bots), towards: try element(0, of: bots).eye + SIMD3(10, 0, 0))]
        let frames = 6
        _ = fly(&rounds, &bots, in: floor, frames: frames)
        let flown = configuration.roundSpeed * frame * Double(frames)
        let moved = try element(0, of: rounds)
        XCTAssertEqual(moved.flown, flown, accuracy: 1e-9)
        XCTAssertEqual(Perception.metres(moved.position, try element(0, of: bots).eye), flown, accuracy: 1e-9)
        XCTAssertEqual(moved.position.x - (try element(0, of: bots).eye.x), flown, accuracy: 1e-9, "it went off its line")
    }

    // MARK: the first body in its way (FR-BOT-400)

    func testARoundStrikesTheFirstBodyInItsWayWhoeverItIs() throws {
        // A squadmate stands between the shooter and the enemy it fired at: the mate is
        // struck, the enemy is not, and the round is spent.
        let floor = try world(String(repeating: ".", count: 24))
        let shooter = try bot(0, .red, at: 1, 0)
        let mate = try bot(1, .red, at: 5, 0)
        let enemy = try bot(2, .blue, at: 9, 0)
        var bots = [shooter, mate, enemy]
        var rounds = [try round(from: shooter, towards: enemy.eye)]
        _ = fly(&rounds, &bots, in: floor, frames: 60)
        XCTAssertEqual(try element(0, of: bots).health, shooter.health, "the round struck the bot that fired it")
        XCTAssertEqual(try element(1, of: bots).health, mate.health - damage, accuracy: 1e-9, "the mate in the way was not struck")
        XCTAssertEqual(try element(2, of: bots).health, enemy.health, "the round went through the mate")
        XCTAssertTrue(rounds.isEmpty, "the round flew on after it struck")
    }

    func testATargetThatHasMovedOffTheLineIsMissed() throws {
        let floor = try world(String(repeating: ".", count: 40), String(repeating: ".", count: 40),
                              String(repeating: ".", count: 40))
        let shooter = try bot(0, .red, at: 1, 1)
        var enemy = try bot(1, .blue, at: 12, 1)
        var rounds = [try round(from: shooter, towards: enemy.eye)]
        // A metre aside by the time the round gets there: more than two body radii.
        XCTAssertGreaterThan(1.0, radius * 2, "a metre is within a body's reach of the line, so this proves nothing")
        enemy.position.z += 1
        var bots = [shooter, enemy]
        _ = fly(&rounds, &bots, in: floor, frames: 60)
        XCTAssertEqual(try element(1, of: bots).health, enemy.health, "a bot a metre off the line was struck")

        // Where it stood, it is struck: the miss is the move's doing.
        enemy.position.z -= 1
        bots = [shooter, enemy]
        rounds = [try round(from: shooter, towards: enemy.eye)]
        _ = fly(&rounds, &bots, in: floor, frames: 60)
        XCTAssertEqual(try element(1, of: bots).health, enemy.health - damage, accuracy: 1e-9)
    }

    func testARoundStrikesTheSnakeItsPathCrossesAndNotOneBesideIt() throws {
        let floor = try world(String(repeating: ".", count: 40), String(repeating: ".", count: 40),
                              String(repeating: ".", count: 40))
        let shooter = try bot(0, .red, at: 1, 1)
        // A snake lying across the line, north to south, six metres off.
        let across = [at(13, 0), at(13, 1), at(13, 2)]
        var bots = [shooter]
        var rounds = [try round(from: shooter, towards: at(13, 1) + SIMD3(0, radius, 0))]
        let struck = fly(&rounds, &bots, snake: across, in: floor, frames: 60)
        XCTAssertEqual(struck.damage, damage, accuracy: 1e-9)
        XCTAssertEqual(struck.hits, 1)
        XCTAssertTrue(rounds.isEmpty)

        // The same snake moved a metre and a half north before the round got there.
        let moved = across.map { $0 + SIMD3(0, 0, -1.5) }
        rounds = [try round(from: shooter, towards: at(13, 1) + SIMD3(0, radius, 0))]
        XCTAssertEqual(fly(&rounds, &bots, snake: moved, in: floor, frames: 60).hits, 0,
                       "a snake that moved off the line was struck")
    }

    func testABodyLyingOnTheFloorIsNotStruck() throws {
        let floor = try world(String(repeating: ".", count: 24))
        let shooter = try bot(0, .red, at: 1, 0)
        var body = try bot(1, .blue, at: 5, 0)
        body.health = 0
        let enemy = try bot(2, .blue, at: 9, 0)
        var bots = [shooter, body, enemy]
        var rounds = [try round(from: shooter, towards: enemy.eye)]
        _ = fly(&rounds, &bots, in: floor, frames: 60)
        XCTAssertEqual(try element(2, of: bots).health, enemy.health - damage, accuracy: 1e-9,
                       "the body stopped a round flown over it")
    }

    // MARK: a wall, and the range (FR-BOT-405)

    func testARoundStopsAtAWallAndHarmsNothingBehindIt() throws {
        // A crate stands higher than the eyes; a wall lower than them does not stop a round
        // sent level at the eyes (ADR-0022).
        let floor = try world("..........o.............")
        let shooter = try bot(0, .red, at: 1, 0)
        let enemy = try bot(1, .blue, at: 16, 0)
        var bots = [shooter, enemy]
        var rounds = [try round(from: shooter, towards: enemy.eye)]
        _ = fly(&rounds, &bots, in: floor, frames: 60)
        XCTAssertEqual(try element(1, of: bots).health, enemy.health, "the round went through the crate")
        XCTAssertTrue(rounds.isEmpty, "the round is still flying inside the crate")

        let low = try world("..........#.............")
        bots = [shooter, enemy]
        rounds = [try round(from: shooter, towards: enemy.eye)]
        _ = fly(&rounds, &bots, in: low, frames: 60)
        XCTAssertEqual(try element(1, of: bots).health, enemy.health - damage, accuracy: 1e-9,
                       "a wall lower than the eyes stopped a round sent over it")
    }

    func testARoundIsSpentOnceItHasFlownTheRoundRange() throws {
        let length = Int((configuration.roundRange / cell).rounded(.up)) + 20
        let floor = try world(String(repeating: ".", count: length))
        var bots = [try bot(0, .red, at: 1, 0)]
        var rounds = [try round(from: try element(0, of: bots), towards: try element(0, of: bots).eye + SIMD3(1, 0, 0))]
        let lasts = configuration.roundRange / configuration.roundSpeed
        let before = Int((lasts / frame).rounded(.down)) - 1
        _ = fly(&rounds, &bots, in: floor, frames: before)
        XCTAssertEqual(rounds.count, 1, "the round was spent before its range")
        XCTAssertLessThan(try element(0, of: rounds).flown, configuration.roundRange)
        _ = fly(&rounds, &bots, in: floor, frames: 3)
        XCTAssertTrue(rounds.isEmpty, "the round flew past its range")
    }

    func testARoundFliesNoFurtherThanTheRangeEvenInItsLastFrame() throws {
        // A bot standing just past the range, on the line, and frames long enough that the
        // round's last one would carry it well past the range at full speed: it must stop
        // at the range. Sixtieths of a second divide the shipped flight exactly, and would
        // never try it.
        let floor = try world(String(repeating: ".", count: 80))
        let shooter = try bot(0, .red, at: 0, 0)
        let beyond = Int(((configuration.roundRange + radius * 2) / cell).rounded(.up))
        let enemy = try bot(1, .blue, at: beyond, 0)
        let long = configuration.roundRange / configuration.roundSpeed / 2.5
        XCTAssertGreaterThan((configuration.roundSpeed * long * 3 - configuration.roundRange), radius * 4,
                             "the last frame does not reach past the enemy, so this proves nothing")
        var bots = [shooter, enemy]
        var rounds = [try round(from: shooter, towards: enemy.eye)]
        for _ in 0..<3 {
            _ = Flight.fly(&rounds, seconds: long, bots: &bots, snake: [], plan: floor.plan,
                           configuration: configuration, bodyRadius: radius)
        }
        XCTAssertTrue(rounds.isEmpty)
        XCTAssertEqual(try element(1, of: bots).health, enemy.health, "a round struck beyond its range")
    }

    // MARK: not through a squadmate (FR-BOT-410)

    private func situation(_ floor: World) -> Deliberation.Situation {
        var made = Deliberation.Situation(plan: floor.plan, graph: floor.graph, configuration: configuration, cellSize: cell)
        made.bodyRadius = radius
        return made
    }

    func testABotDoesNotFireThroughASquadmateItSees() throws {
        let floor = try world(String(repeating: ".", count: 24), String(repeating: ".", count: 24),
                              String(repeating: ".", count: 24))
        let shooter = try bot(0, .red, at: 1, 1)
        var seen = situation(floor)
        seen.enemiesInView = [(id: 9, point: at(12, 1))]
        func worth(_ metres: Double) -> Double { 1 }
        XCTAssertEqual(Deliberation.target(for: shooter, in: seen, within: .infinity, worth: worth)?.target, .bot(id: 9),
                       "nothing to fire at with nobody in the way, so this proves nothing")

        seen.allies = [shooter, try bot(1, .red, at: 6, 1, facing: -east)]
        XCTAssertNil(Deliberation.target(for: shooter, in: seen, within: .infinity, worth: worth), "the bot fired through its squadmate")

        // A squadmate beside the line, clear of it by more than its body, is no reason not to.
        seen.allies = [shooter, try bot(1, .red, at: 6, 0, facing: -east)]
        XCTAssertGreaterThan(cell, radius, "a cell aside is within the body's reach, so this proves nothing")
        XCTAssertEqual(Deliberation.target(for: shooter, in: seen, within: .infinity, worth: worth)?.target, .bot(id: 9))
    }

    func testASquadmateInTheWayOfTheSnakeSendsTheBotToAnotherTarget() throws {
        // The snake within the override distance is fired at whatever else there is
        // (FR-BOT-120), unless a squadmate stands in the way: then another target it has.
        let floor = try world(String(repeating: ".", count: 24), String(repeating: ".", count: 24),
                              String(repeating: ".", count: 24))
        let shooter = try bot(0, .red, at: 1, 1)
        var seen = situation(floor)
        seen.inView = [at(5, 1)]
        seen.enemiesInView = [(id: 9, point: at(1, 2))]
        func worth(_ metres: Double) -> Double { 1 }
        if case .snake? = Deliberation.target(for: shooter, in: seen, within: .infinity, worth: worth)?.target {} else {
            XCTFail("the snake within the override distance was not the target, so this proves nothing")
        }
        seen.allies = [shooter, try bot(1, .red, at: 3, 1, facing: -east)]
        XCTAssertEqual(Deliberation.target(for: shooter, in: seen, within: .infinity, worth: worth)?.target, .bot(id: 9))
    }
}
