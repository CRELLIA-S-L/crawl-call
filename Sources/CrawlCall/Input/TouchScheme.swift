// Touch, turned into the intents the logic consumes (FR-VIEW-050). The mapping itself
// is arithmetic and lives here so that a test can read it; the gesture that feeds it
// is SwiftUI's and lives in the view.
//
// The camera's yaw does not change (FR-VIEW-010), so the screen's axes and the map's
// are fixed relative to each other: right is +x, and dragging towards the player — down
// the screen — is +z, because the camera looks along −z from above and behind.
//
// implements: FR-VIEW-050
import CoreGraphics
import Foundation

enum TouchScheme {
    /// A drag becomes a direction, held while the finger stays down. Below the dead
    /// zone it is no direction at all rather than a jittery one: a finger resting on
    /// glass is not a command.
    static func direction(fromDrag translation: CGSize, deadZone: Double = 12) -> SIMD2<Double> {
        let x = Double(translation.width)
        let z = Double(translation.height)
        let length = (x * x + z * z).squareRoot()
        guard length > deadZone else { return .zero }
        return SIMD2(x / length, z / length)
    }

    /// The intent a drag produces, or the one that stops the snake when it ends.
    static func intent(fromDrag translation: CGSize, deadZone: Double = 12) -> Intent {
        .move(direction: direction(fromDrag: translation, deadZone: deadZone))
    }

    /// Letting go stops the snake: the direction is held *while the finger stays down*.
    static var release: Intent { .move(direction: .zero) }
}
