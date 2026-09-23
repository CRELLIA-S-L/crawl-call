// IF-VIEW-010 says "exactly these intents". This is what makes another one a change
// to the requirement rather than a quiet addition.
//
// verifies: IF-VIEW-010
import XCTest
@testable import CrawlCall

final class IntentTests: XCTestCase {
    /// The switch is the guard, not the list: adding a case to `Intent` stops this
    /// file compiling, which is what "exactly these" has to mean in code.
    private func name(of intent: Intent) -> String {
        switch intent {
        case .move:       return "move"
        case .useAbility: return "useAbility"
        case .point:      return "point"
        case .pause:      return "pause"
        case .eat:        return "eat"
        }
    }

    func testTheContractNamesFiveIntentsAndTheTypeCarriesThem() {
        let every: [Intent] = [.move(direction: SIMD2(1, 0)), .useAbility(segment: 0),
                               .point(at: SIMD2(0, 0)), .pause, .eat]
        XCTAssertEqual(every.map(name(of:)), Intent.all)
        XCTAssertEqual(Set(Intent.all).count, Intent.all.count)
    }

    func testEachIntentCanBeBuiltAndCompared() {
        XCTAssertEqual(Intent.move(direction: SIMD2(1, 0)), .move(direction: SIMD2(1, 0)))
        XCTAssertNotEqual(Intent.move(direction: SIMD2(1, 0)), .move(direction: SIMD2(0, 1)))
        XCTAssertEqual(Intent.useAbility(segment: 3), .useAbility(segment: 3))
        XCTAssertEqual(Intent.point(at: SIMD2(2, 2)), .point(at: SIMD2(2, 2)))
        XCTAssertEqual(Intent.pause, .pause)
        XCTAssertNotEqual(Intent.pause, .useAbility(segment: 0))
    }
}
