// Numbers of how the scene's light is built that the method fixes rather than the
// look (ART-070); the look itself — the sky's colour, the sun's strength and where it
// stands — is the view configuration's (IF-VIEW-020, ADR-0026).
//
// implements: FR-VIEW-130, FR-VIEW-030
import Foundation
import RealityKit

/// How the frame is rendered. No multisampling: at the phone's 2622 × 1206 its edges
/// show little stair-stepping, and it cost the GPU about a thirteenth of its work a
/// frame at the steady performance level a match runs at (ADR-0048).
enum Rendering {
    static let antialiasing = AntialiasingMode.none
}

/// The flat image the ambient light is generated from.
enum AmbientImage {
    /// Pixels on the short side; the colour is flat, so size buys nothing.
    static let side = 8
    /// An equirectangular image is twice as wide as it is tall.
    static let widthInSides = 2
    static let bitsPerComponent = 8
}

/// The sun's shadow.
enum SunShadow {
    /// Shadows are cast over twice the map's larger side, so that none is cut off
    /// before the map's edge whatever the sun's angle.
    static let reachInSpans: Float = 2
    static let depthBias: Float = 1
}

/// Colour components.
enum Colour {
    /// A colour that lets nothing through.
    static let opaque = 1.0
}

/// Numbers of the match's clock (FR-VIEW-030).
enum Frame {
    /// Seconds: a frame longer than this is a stall, and the match is advanced by this
    /// much instead, so the picture does not lurch across the room.
    static let longest = 1.0 / 20
}
