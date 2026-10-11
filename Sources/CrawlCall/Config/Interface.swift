// How the interface is drawn and how a thumb on it is read: sizes, spacing, opacities
// and gestures (ART-070). Part of how the interface looks rather than of the world it
// shows, so named here and not in the configuration (ADR-0026).
//
// file implements: FR-VIEW-050, FR-VIEW-120, FR-VIEW-160, FR-VIEW-190, FR-TOOL-070, FR-VIEW-210, FR-MAP-140, FR-TOOL-260, FR-TOOL-270, FR-VIEW-155
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

/// Which see-through cuts a match starts with. The window around the head (FR-VIEW-155)
/// is off since 2026-09-25: the maintainer found on the phone that it opened walls and
/// crates beside the head that hide nothing (Q-260). It is kept, not removed, to be
/// switched back on in debug mode (FR-TOOL-270) and compared before it goes.
enum SeeThroughAtStart {
    static let line = true
    static let headWindow = false
}

/// What debug mode tints a module the see-through cut open with, by what cut it
/// (FR-TOOL-260): red, green and blue in 0…1, bright enough to tell apart from any
/// colour of the kit.
enum SeeThroughTint {
    static let line = SIMD3<Double>(0.95, 0.2, 0.85)
    static let window = SIMD3<Double>(0.1, 0.85, 0.95)
    static let both = SIMD3<Double>(1.0, 0.85, 0.1)
    /// The switches' plate and how far a switch that is off fades.
    static let switchOffOpacity = 0.35
    static let switchSpacing = 8.0
    static let switchPadding = 10.0
}

/// The window the game is played in on an iPad (FR-VIEW-210).
enum GameWindow {
    /// Across, the stick's plate and the eat button side by side, with a margin at each
    /// edge and one between them; down, the taller of the two with a margin above and
    /// below. Any narrower and the controls would overlap.
    static let marginsAcross = 3.0
    static let marginsDown = 2.0
    static var minimumSize: CGSize {
        let stick = Stick.radius * Stick.plateInRadii
        return CGSize(width: stick + EatButton.size + Interface.screenMargin * marginsAcross,
                      height: max(stick, EatButton.size) + Interface.screenMargin * marginsDown)
    }

    /// The widest frame, width over height, the game can be given on a screen of this
    /// size: the screen itself where the window is the screen, and the screen's long
    /// side over the smallest height a window may have where windows resize — an
    /// iPad's, which can be as short as the controls (FR-VIEW-210). The surroundings
    /// are sized for it (FR-MAP-140).
    static func widestAspect(screen: CGSize, resizable: Bool) -> Double {
        let long = Double(max(screen.width, screen.height))
        let short = Double(min(screen.width, screen.height))
        let lowest = resizable ? Double(minimumSize.height) : short
        return lowest > .zero ? long / lowest : Fraction.whole
    }
}
