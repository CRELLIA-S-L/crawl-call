// What a bot is drawn as (FR-VIEW-070): a figure whose headgear and weapon name its
// archetype, whose headgear carries its squad's colour (FR-VIEW-060), and whose eyes
// are where the bot looks from (ADR-0022). Whether six silhouettes can be told apart
// at the game camera's distance is judged on the screen; what a test can hold is that
// they are six different ones and that the figure is built the way that judgement
// assumes.
//
// verifies: FR-VIEW-060, FR-VIEW-070
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
        let tube = try XCTUnwrap(figure.children.first { $0.name == "weapon" })
        let extent = tube.visualBounds(relativeTo: figure).extents
        // Four times as long as it is thick, drawn; three is the least that still
        // says lying rather than standing whatever size the figure is set down at.
        XCTAssertGreaterThan(extent.z, 3 * extent.y, "the tube is not lying along z")
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
