// Touch, turned into the intents the logic consumes (FR-VIEW-050): a stick where the
// thumb lands on the left half, and a meal from a touch on the right (ADR-0051). The mapping itself
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
    /// The stick's reading: where to draw the knob, and the direction it asks for.
    ///
    /// The knob never leaves the base — a thumb that slides off the plate keeps
    /// steering in the direction it left by, which is what a physical stick does and
    /// what a thumb expects.
    static func stick(_ offset: CGSize,
                      radius: Double = Stick.radius,
                      deadZone: Double = Stick.deadZone) -> (knob: CGSize, direction: SIMD2<Double>) {
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
    static func direction(of offset: CGSize, deadZone: Double = Stick.deadZone) -> SIMD2<Double> {
        let x = Double(offset.width)
        let z = Double(offset.height)
        let length = (x * x + z * z).squareRoot()
        guard length > deadZone else { return .zero }
        return SIMD2(x / length, z / length)
    }

    /// Where the stick stands for a thumb that lands at `touch` on a half `size` big:
    /// under the thumb, moved in only as far as it takes for the whole plate to be on
    /// the half (FR-VIEW-050). A half narrower or lower than the plate has it centred.
    static func stickCentre(at touch: CGPoint, in size: CGSize, radius: Double = Stick.radius) -> CGPoint {
        let plate = radius * Stick.plateInRadii * Geometry.half
        func within(_ value: Double, _ length: Double) -> Double {
            length < plate * Geometry.bothSides ? length * Geometry.half : min(max(value, plate), length - plate)
        }
        return CGPoint(x: within(Double(touch.x), Double(size.width)), y: within(Double(touch.y), Double(size.height)))
    }

    /// A touch anywhere on the right half asks for a meal.
    static let eat = Intent.eat

    /// Lifting the thumb off the stick stops the snake: the direction is held *while
    /// the thumb rests on it*.
    static var release: Intent { .move(direction: .zero) }
}
