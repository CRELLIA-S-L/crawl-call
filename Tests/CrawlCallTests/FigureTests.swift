// What a bot is drawn as (FR-VIEW-070): a figure whose headgear and weapon name its
// archetype, whose headgear carries its squad's colour (FR-VIEW-060), and whose eyes
// are where the bot looks from (ADR-0022). Whether six silhouettes can be told apart
// at the game camera's distance is judged on the screen; what a test can hold is that
// they are six different ones and that the figure is built the way that judgement
// assumes.
//
// file verifies: FR-VIEW-060, FR-VIEW-070, FR-VIEW-240, FR-VIEW-340, FR-BOT-520
import RealityKit
import XCTest
@testable import CrawlCall

final class FigureTests: XCTestCase {
    private var bots: BotConfiguration!

    override func setUpWithError() throws {
        try super.setUpWithError()
        bots = try Launch.world().get().configurations.bot
    }

    /// The shipped size, which is what the screen shows.
    private var height: Double { bots.figureHeight }

    /// What an archetype is read by: its headgear and what it carries, and nothing
    /// else of the figure.
    private func silhouette(of archetype: Archetype) -> [Figure.Part] {
        Figure.parts(for: archetype, height: height).filter { $0.role == .headgear || $0.role == .weapon || $0.role == .kit }
    }

    // MARK: what is in the hands and what is stowed (FR-VIEW-340)

    func testEveryArchetypeCarriesItsFourWeaponsAndHoldsTheOneItIsUsing() throws {
        for archetype in Archetype.allCases {
            for using in Figure.Carried.allCases {
                let parts = Figure.parts(for: archetype, height: height, using: using)
                let carried = parts.compactMap(\.carried)
                XCTAssertEqual(Set(carried), Set(Figure.Carried.allCases),
                               "\(archetype) went out without all four of its weapons drawn")
                XCTAssertEqual(carried.count, Figure.Carried.allCases.count, "a weapon is drawn twice")
                // The one in use is out in front of the figure, and every other is
                // behind it or at its belt — never in the same place as the hands.
                let hands = try XCTUnwrap(parts.first { $0.carried == using }).centre
                for part in parts where part.carried != nil && part.carried != using {
                    XCTAssertNotEqual(part.centre, hands, "\(archetype) holds two things at once")
                }
                XCTAssertGreaterThan(hands.z, 0, "\(archetype) holds its \(using) behind itself")
            }
        }
    }

    func testThePrimaryIsAcrossTheBackWhileSomethingElseIsInTheHands() throws {
        for archetype in Archetype.allCases {
            let held = try XCTUnwrap(Figure.parts(for: archetype, height: height, using: .primary)
                .first { $0.carried == .primary })
            let slung = try XCTUnwrap(Figure.parts(for: archetype, height: height, using: .knife)
                .first { $0.carried == .primary })
            XCTAssertGreaterThan(held.centre.z, slung.centre.z, "\(archetype)'s primary is not stowed behind it")
            XCTAssertEqual(held.turn, 0, "\(archetype) holds its primary sideways")
            XCTAssertEqual(slung.turn, .pi / 2, accuracy: 1e-12, "\(archetype)'s primary is not across its back")
        }
    }

    func testWhatABotNoLongerCarriesIsDrawnNowhere() throws {
        // A knife is gone once thrown (FR-BOT-520) and a pouch empties; neither is
        // drawn on a figure that has none.
        let parts = Figure.parts(for: .assault, height: height, using: .primary, carrying: [.primary, .sidearm])
        XCTAssertNil(parts.first { $0.carried == .knife }, "a thrown knife is still on the belt")
        XCTAssertNil(parts.first { $0.carried == .grenade }, "an empty pouch still has a grenade in it")
        XCTAssertNotNil(parts.first { $0.carried == .primary })
    }

    func testTheWeaponAFigureHoldsFollowsWhatTheBotIsDoing() throws {
        // What the view reads off a bot's last decision, which is the whole of how the
        // hands change within a match.
        XCTAssertEqual(Figure.using(.fire(at: .bot(id: 1), with: .primary)), .primary)
        XCTAssertEqual(Figure.using(.fire(at: .bot(id: 1), with: .sidearm)), .sidearm)
        XCTAssertEqual(Figure.using(.throwGrenade(at: .bot(id: 1))), .grenade)
        XCTAssertEqual(Figure.using(.strike(at: .bot(id: 1))), .knife)
        XCTAssertEqual(Figure.using(.throwKnife(at: .bot(id: 1))), .knife)
        // Walking, reloading, doing nothing: the primary, which is what a bot carries
        // about in its hands.
        XCTAssertEqual(Figure.using(.reload(.primary)), .primary)
        XCTAssertEqual(Figure.using(.reload(.sidearm)), .sidearm)
        XCTAssertEqual(Figure.using(nil), .primary)
    }

    @MainActor
    func testTheFigureMovesItsWeaponsWhenTheBotChangesWhatItUses() throws {
        let world = try Launch.world().get()
        var bot = try XCTUnwrap(Bot(id: 0, squad: .red, archetype: .assault, at: .zero, floor: 0,
                                    configuration: world.configurations.bot))
        let entity = BotEntity.make(for: [bot], height: height)
        let figure = try XCTUnwrap(entity.children.first)
        let knife = try XCTUnwrap(figure.children.first { $0.name == EntityName.weapon(Figure.Carried.knife.rawValue) })
        let stowed = knife.position

        bot.action = .strike(at: .bot(id: 1))
        BotEntity.update(entity, from: [bot], height: height)
        XCTAssertNotEqual(knife.position, stowed, "the knife stayed on the belt while the bot was striking with it")
        XCTAssertTrue(knife.isEnabled)

        // Thrown, it is on the figure nowhere (FR-BOT-520).
        bot.arms.throwKnife()
        BotEntity.update(entity, from: [bot], height: height)
        XCTAssertFalse(knife.isEnabled, "a thrown knife is still drawn")
    }

    @MainActor
    func testAStowedPrimaryLiesAcrossTheBackAndNotAlongIt() throws {
        // What a quarter turn about the vertical comes to on the screen, read off the
        // entity rather than off the part: the heavy's tube is long front to back in
        // its hands and long side to side on its back. Which of the two rotations the
        // SDK applies first is not something to remember — this is the observation.
        let world = try Launch.world().get()
        var bot = try XCTUnwrap(Bot(id: 0, squad: .red, archetype: .heavy, at: .zero, floor: 0,
                                    configuration: world.configurations.bot))
        let entity = BotEntity.make(for: [bot], height: height)
        let figure = try XCTUnwrap(entity.children.first)
        let tube = try XCTUnwrap(figure.children.first { $0.name == EntityName.weapon(Figure.Carried.primary.rawValue) })
        bot.action = .fire(at: .bot(id: 1), with: .primary)
        BotEntity.update(entity, from: [bot], height: height)
        let held = tube.visualBounds(relativeTo: figure).extents
        XCTAssertGreaterThan(held.z, 3 * held.x, "the tube is not pointing forward in its hands")

        bot.action = .fire(at: .bot(id: 1), with: .sidearm)
        BotEntity.update(entity, from: [bot], height: height)
        let slung = tube.visualBounds(relativeTo: figure).extents
        XCTAssertGreaterThan(slung.x, 3 * slung.z, "the tube is not lying across the back")
        XCTAssertLessThan(tube.position.z, 0, "the tube is not behind the figure")
    }

    func testEveryArchetypeHasHeadgearAndAWeapon() {
        for archetype in Archetype.allCases {
            let parts = Figure.parts(for: archetype, height: height)
            XCTAssertTrue(parts.contains { $0.role == .headgear }, "\(archetype) has nothing on its head")
            XCTAssertTrue(parts.contains { $0.role == .weapon }, "\(archetype) carries nothing")
        }
    }

    func testSixArchetypesAreSixSilhouettes() {
        // Two archetypes whose headgear and weapons were the same would be one
        // silhouette, however different the rest of them.
        let all = Archetype.allCases
        for (i, a) in all.enumerated() {
            for b in all[(i + 1)...] {
                XCTAssertNotEqual(silhouette(of: a), silhouette(of: b), "\(a) and \(b) look the same")
            }
        }
        // And both what is worn and what is carried differ between any two, not only
        // one of them: FR-VIEW-070 reads an archetype by headgear *and* weapon, and one
        // of the two is always turned away from somebody. What is carried is the
        // weapon and the kit together: the scout and the medic carry the same pistol,
        // as approved, and the medic's satchel is what tells its hands apart.
        for (i, a) in all.enumerated() {
            for b in all[(i + 1)...] {
                let hats = { (x: Archetype) in Figure.parts(for: x, height: self.height).filter { $0.role == .headgear } }
                let arms = { (x: Archetype) in Figure.parts(for: x, height: self.height).filter { $0.role == .weapon || $0.role == .kit } }
                XCTAssertNotEqual(hats(a), hats(b), "\(a) and \(b) wear the same thing")
                XCTAssertNotEqual(arms(a), arms(b), "\(a) and \(b) carry the same thing")
            }
        }
    }

    func testTheHeadgearIsInTheSquadsColour() {
        // The silhouette that names the archetype names the side as well — the second
        // of FR-VIEW-060's three channels, agreeing with the body's colour.
        for archetype in Archetype.allCases {
            let headgear = Figure.parts(for: archetype, height: height).filter { $0.role == .headgear }
            XCTAssertTrue(headgear.contains { $0.paint == .squad }, "\(archetype)'s headgear belongs to no side")
            let body = Figure.parts(for: archetype, height: height).filter { $0.role == .body }
            XCTAssertTrue(body.contains { $0.paint == .squad }, "\(archetype)'s body belongs to no side")
        }
        XCTAssertEqual(Figure.colour(of: .squad, squad: .red), BotEntity.colour(for: .red))
        XCTAssertEqual(Figure.colour(of: .squad, squad: .blue), BotEntity.colour(for: .blue))
    }

    func testTheEyesArePaintedOnTheFaceAtTheModelsEyeShare() {
        // Where the model's eyes are is part of the model: the same share of its
        // height whatever height it is set down at.
        for size in [height, 0.8, 2.0] {
            for archetype in Archetype.allCases {
                let parts = Figure.parts(for: archetype, height: size)
                let eyes = parts.filter { $0.role == .eye }
                let head = parts.first { $0.role == .head }
                XCTAssertEqual(eyes.count, 2)
                for eye in eyes {
                    XCTAssertEqual(eye.centre.y, size * Figure.eyeShare, accuracy: 1e-9)
                    if let head, case .sphere(let radius) = head.shape {
                        let d = eye.centre - head.centre
                        XCTAssertEqual((d * d).sum().squareRoot(), radius, accuracy: 0.03 * size,
                                       "\(archetype)'s eye is not on its face")
                    }
                }
            }
        }
    }

    func testTheShippedEyeHeightIsWhereTheFiguresEyesArePainted() {
        // The configuration may set the two apart — a bot that looks from its chest —
        // but the shipped numbers put the look where the eyes are drawn.
        XCTAssertEqual(bots.eyeHeight, bots.figureHeight * Figure.eyeShare, accuracy: 1e-9)
    }

    @MainActor
    func testTheFigureStandsWithinItsHeightAndTheTallestReachesIt() {
        var tallest: Float = 0
        for archetype in Archetype.allCases {
            let figure = Figure.make(archetype, height: height, materials: Figure.materials(for: .red))
            let bounds = figure.visualBounds(relativeTo: nil)
            XCTAssertEqual(Double(bounds.min.y), 0, accuracy: 0.01, "\(archetype) is not standing on its feet")
            XCTAssertLessThanOrEqual(Double(bounds.max.y), height + 1e-3, "\(archetype) is taller than a bot")
            tallest = max(tallest, bounds.max.y)
        }
        XCTAssertEqual(Double(tallest), height, accuracy: 1e-3)
    }

    @MainActor
    func testTheFigureIsDrawnAtTheHeightItIsGiven() {
        // The model is a model and the size comes from outside: set down at two
        // heights, the same figure is those two heights tall, and the configuration
        // is what decides which (ADR-0022).
        for size in [0.9, 1.8] {
            var tallest: Float = 0
            for archetype in Archetype.allCases {
                let bounds = Figure.make(archetype, height: size, materials: Figure.materials(for: .red))
                    .visualBounds(relativeTo: nil)
                XCTAssertLessThanOrEqual(Double(bounds.max.y), size + 1e-3)
                tallest = max(tallest, bounds.max.y)
            }
            XCTAssertEqual(Double(tallest), size, accuracy: 1e-3)
        }
    }

    @MainActor
    func testTheHeavysTubeLiesAlongItsShoulderPointingForward() throws {
        // The SDK makes a cylinder centred on its origin and does not say along which
        // axis; the figure turns it onto z. What this holds is the outcome: the tube is
        // long front to back and short up and down.
        let figure = Figure.make(.heavy, height: height, materials: Figure.materials(for: .blue))
        let tube = try XCTUnwrap(figure.children.first { $0.name == EntityName.weapon(Figure.Carried.primary.rawValue) })
        let extent = tube.visualBounds(relativeTo: figure).extents
        // Four times as long as it is thick, drawn; three is the least that still
        // says lying rather than standing whatever size the figure is set down at.
        XCTAssertGreaterThan(extent.z, 3 * extent.y, "the tube is not lying along z")
    }

    @MainActor
    func testNoPartOfAFigureIsDrawnWithTensOfThousandsOfTriangles() {
        // Eight figures of RealityKit's own boxes and spheres were four fifths of every
        // triangle in the frame (ADR-0046); the game draws them with its own shapes.
        for archetype in Archetype.allCases {
            let figure = Figure.make(archetype, height: height, materials: Figure.materials(for: .red))
            var parts: [ModelEntity] = []
            func collect(_ entity: Entity) {
                if let model = entity as? ModelEntity { parts.append(model) }
                entity.children.forEach(collect)
            }
            collect(figure)
            XCTAssertFalse(parts.isEmpty)
            for part in parts {
                guard let mesh = part.model?.mesh else { continue }
                XCTAssertLessThanOrEqual(triangles(of: mesh), mostTrianglesOfOneShape,
                                         "a part of the \(archetype) is \(triangles(of: mesh)) triangles")
            }
        }
    }

    @MainActor
    func testTheSameArchetypeInEitherSquadIsTheSameShape() {
        // Six silhouettes, not twelve: the squads differ by colour alone (concept §8).
        for archetype in Archetype.allCases {
            let red = Figure.make(archetype, height: height, materials: Figure.materials(for: .red)).visualBounds(relativeTo: nil)
            let blue = Figure.make(archetype, height: height, materials: Figure.materials(for: .blue)).visualBounds(relativeTo: nil)
            XCTAssertEqual(red.min, blue.min)
            XCTAssertEqual(red.max, blue.max)
        }
    }
}
