// The line along the top that says what each squad stands under (FR-VIEW-380).
//
// What a test can hold of a view is the words it puts up and the colour it puts them
// on; that the plate is rounded and light is inspected (FR-VIEW-120).
//
// file verifies: FR-VIEW-380
import SwiftUI
import XCTest
@testable import CrawlCall

final class SquadOrdersTests: XCTestCase {
    private func command(_ order: CommanderDecision.Order, _ place: Places.Part?,
                         threat: CommanderDecision.Threat = .enemy) -> SquadCommand {
        SquadCommand(threat: threat, order: order, place: place)
    }

    func testAnOrderIsShownInTheCommandersOwnWords() {
        // FR-VIEW-380: the order and the part it names, as the model answered them.
        XCTAssertEqual(SquadOrders.order(of: command(.press, .northEast)), "press north-east")
        XCTAssertEqual(SquadOrders.order(of: command(.withdraw, .middle)), "withdraw middle")
    }

    func testAnOrderThatNamesNoPartIsShownAlone() {
        XCTAssertEqual(SquadOrders.order(of: command(.hold, nil)), "hold")
    }

    func testASquadNobodyHasSpokenToSaysSo() {
        // The half is there either way, so that no order reads as no order rather than
        // as a missing plate.
        XCTAssertEqual(SquadOrders.order(of: nil), TextKey.ordersNone.text())
        XCTAssertFalse(TextKey.ordersNone.text().isEmpty, "the catalog carries no words for it")
        XCTAssertNil(SquadOrders.threat(of: nil))
    }

    func testTheThreatIsShownInTheGamesWordsAroundTheCommandersOwn() {
        let said = try? XCTUnwrap(SquadOrders.threat(of: command(.press, .east, threat: .snake)))
        XCTAssertEqual(said, String(format: TextKey.ordersThreat.text(), "snake"))
        XCTAssertTrue(said?.contains("snake") == true, "the threat's own word is not in the line")
    }

    @MainActor
    func testEachSquadIsWrittenOnAPlateOfItsOwnColourMadeLight() throws {
        // FR-VIEW-380 against FR-VIEW-060 and FR-VIEW-120: the squad's own colour,
        // carried towards white — pink for red, pale blue for blue, and never the
        // other way round.
        for squad in Squad.allCases {
            let own = BotEntity.colour(for: squad)
            let plate = try components(of: SquadOrders.colour(of: squad))
            XCTAssertGreaterThan(plate.red, own.x, "the \(squad.name) plate is no lighter than the squad")
            XCTAssertGreaterThan(plate.green, own.y)
            XCTAssertGreaterThan(plate.blue, own.z)
        }
        let pink = try components(of: SquadOrders.colour(of: .red))
        let pale = try components(of: SquadOrders.colour(of: .blue))
        XCTAssertGreaterThan(pink.red, pink.blue, "the red squad's plate is not pink")
        XCTAssertGreaterThan(pale.blue, pale.red, "the blue squad's plate is not blue")
    }

    @MainActor
    private func components(of colour: Color) throws -> (red: Double, green: Double, blue: Double) {
        var red = CGFloat.zero, green = CGFloat.zero, blue = CGFloat.zero, alpha = CGFloat.zero
        UIColor(colour).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
    }
}
