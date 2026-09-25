// What the window hears and the match must act on: the scene delegate learns when the
// orientation lock comes or goes, and the match on screen is what pauses (FR-VIEW-230).
// The session is created inside the view, so it is handed here when it exists.
//
// It also carries what only the window knows and the scene needs before any match: how
// wide a frame this device can give the game, which the surroundings are sized for
// (FR-MAP-140).
//
// implements: FR-VIEW-230, FR-TOOL-230, FR-MAP-140
import Foundation

@MainActor
final class MatchHost {
    /// The match being played, once the scene has built one.
    weak var session: GameSession?
    /// The frame record, where the launch switched it on (FR-TOOL-230): it outlives any
    /// one match, so that a restart continues the same record.
    let recorder: FrameRecorder?
    /// The widest frame the game can be given on this device (`GameWindow.widestAspect`),
    /// set by the scene delegate before the window is built.
    var widestAspect: Double

    init(recorder: FrameRecorder? = nil, widestAspect: Double = Fraction.whole) {
        self.recorder = recorder
        self.widestAspect = widestAspect
    }

    /// The lock before a change of the scene's geometry and after it. A change of the
    /// lock pauses a match the player has steered; a change of geometry that leaves the
    /// lock as it was — a window resized beside another app — does not, and neither
    /// does the lock iPadOS grants as the scene first comes up full screen, which
    /// arrives with its activation and before anybody has touched the stick.
    func orientationLock(was previous: Bool, is current: Bool) {
        guard previous != current else { return }
        session?.pauseIfUnderWay()
    }
}
