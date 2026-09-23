// Touch, turned into the intents the logic consumes (FR-VIEW-050). The mapping itself
// is arithmetic and lives here so that a test can read it; the controls that feed it
// are SwiftUI's and live in the view.
//
// The camera's yaw does not change (FR-VIEW-010), so the screen's axes and the map's
// are fixed relative to each other: right is +x, and dragging towards the player — down
// the screen — is +z, because the camera looks along −z from above and behind.
//
// implements: FR-VIEW-050
import CoreGraphics
import Foundation

enum TouchScheme {
    /// How far the knob may travel from the stick's centre, and how far a thumb must
    /// push before it counts. Neither number is named by any requirement; they are
    /// the size of a thumb on a phone and are said here rather than buried in the
    /// view's geometry.
    static let stickRadius = 60.0
    static let stickDeadZone = 8.0

    /// The stick's reading: where to draw the knob, and the direction it asks for.
    ///
    /// The knob never leaves the base — a thumb that slides off the plate keeps
    /// steering in the direction it left by, which is what a physical stick does and
    /// what a thumb expects.
    static func stick(_ offset: CGSize,
                      radius: Double = stickRadius,
                      deadZone: Double = stickDeadZone) -> (knob: CGSize, direction: SIMD2<Double>) {
        let heading = direction(of: offset, deadZone: deadZone)
        guard heading != .zero else { return (.zero, .zero) }
        let length = (Double(offset.width) * Double(offset.width)
                      + Double(offset.height) * Double(offset.height)).squareRoot()
        let clamped = min(length, radius)
        return (CGSize(width: heading.x * clamped, height: heading.y * clamped), heading)
    }

    /// An offset from the stick's centre becomes a direction. Below the dead zone it
    /// is no direction at all rather than a jittery one: a thumb resting on glass is
    /// not a command.
    static func direction(of offset: CGSize, deadZone: Double = stickDeadZone) -> SIMD2<Double> {
        let x = Double(offset.width)
        let z = Double(offset.height)
        let length = (x * x + z * z).squareRoot()
        guard length > deadZone else { return .zero }
        return SIMD2(x / length, z / length)
    }

    /// The button on the right asks for a meal.
    static let eat = Intent.eat

    /// Lifting the thumb off the stick stops the snake: the direction is held *while
    /// the thumb rests on it*.
    static var release: Intent { .move(direction: .zero) }
}
