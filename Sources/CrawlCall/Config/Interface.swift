// How the interface is drawn and how a thumb on it is read: sizes, spacing, opacities
// and gestures (ART-070). Part of how the interface looks rather than of the world it
// shows, so named here and not in the configuration (ADR-0026).
//
// implements: FR-VIEW-050, FR-VIEW-120, FR-VIEW-160, FR-VIEW-190, FR-TOOL-070
import Foundation

/// The look every plate and mark shares (FR-VIEW-120): a light, translucent plate and
/// a nearly opaque mark on it.
enum Interface {
    static let plateOpacity = 0.28
    static let markOpacity = 0.85
    /// A plate under a control that answers is filled this much more solid.
    static let litPlateOpacity = 0.9
    /// A control that does not answer yet (FR-VIEW-160) is drawn this faint.
    static let dimPlateOpacity = 0.4
    static let dimMarkOpacity = 0.35
    /// The ring around a control that answers.
    static let ringWidth = 3.0
    /// Points between a control and the edge of the screen.
    static let screenMargin = 28.0
    /// Seconds a control takes to change how it looks.
    static let changeDuration = 0.12
}

/// The steering stick (FR-VIEW-050): the size of a thumb on a phone, which no
/// requirement names.
enum Stick {
    /// Points the knob may travel from the stick's centre.
    static let radius = 60.0
    /// Points a thumb must push before it counts as a direction.
    static let deadZone = 8.0
    /// The plate is as wide as the knob's whole travel: this many radii.
    static let plateInRadii = 2.0
    /// The knob, in radii of its travel.
    static let knobInRadii = 0.8
}

/// The eat button (FR-VIEW-050, FR-VIEW-160).
enum EatButton {
    static let size = 96.0
    static let symbolSize = 34.0
}

/// The plate at the end of a match (FR-VIEW-190).
enum MatchEndPlate {
    static let spacing = 18.0
    static let headlineSize = 30.0
    static let controlTextSize = 24.0
    static let controlHorizontalPadding = 34.0
    static let controlVerticalPadding = 14.0
    static let horizontalPadding = 40.0
    static let verticalPadding = 32.0
    static let cornerRadius = 36.0
}

/// Debug mode's button back to the snake and its gestures (FR-TOOL-070, ADR-0023).
enum DebugControls {
    static let symbolSize = 26.0
    static let buttonSize = 64.0
    static let markOpacity = 0.9
    static let plateOpacity = 0.35
    /// Fingers that pan the free camera, and fingers that tilt it; one finger is the
    /// stick's.
    static let panTouches = 2
    static let tiltTouches = 3
    /// A pinch reads its scale as a factor since the last reading, so it is set back
    /// to the factor that changes nothing after each one.
    static let unscaled = 1.0
}
