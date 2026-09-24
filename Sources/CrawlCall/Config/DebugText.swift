// Text that only the debug build shows (FR-TOOL-070). The player never reads it, so it
// is not in the string catalog and is not translated (IF-VIEW-030); it is named here
// rather than written where it is used (ART-070).
//
// implements: FR-TOOL-070
import Foundation

enum DebugText {
    /// Accessibility label of the button that puts the free camera back on the snake.
    static let cameraBackOnTheSnake = "Camera back on the snake"
}
