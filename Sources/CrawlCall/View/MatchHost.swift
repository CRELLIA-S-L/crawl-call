// What the window hears and the match must act on: the scene delegate learns when the
// orientation lock comes or goes, and the match on screen is what pauses (FR-VIEW-230).
// The session is created inside the view, so it is handed here when it exists.
//
// implements: FR-VIEW-230, FR-TOOL-230
import Foundation

@MainActor
final class MatchHost {
    /// The match being played, once the scene has built one.
    weak var session: GameSession?
    /// The frame record, where the launch switched it on (FR-TOOL-230): it outlives any
    /// one match, so that a restart continues the same record.
    let recorder: FrameRecorder?

    init(recorder: FrameRecorder? = nil) {
        self.recorder = recorder
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
