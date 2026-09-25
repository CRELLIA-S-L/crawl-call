// Text that only the debug build shows (FR-TOOL-070). The player never reads it, so it
// is not in the string catalog and is not translated (IF-VIEW-030); it is named here
// rather than written where it is used (ART-070).
//
// implements: FR-TOOL-070, FR-TOOL-260, FR-TOOL-270
import Foundation

enum DebugText {
    /// Accessibility label of the button that puts the free camera back on the snake.
    static let cameraBackOnTheSnake = "Camera back on the snake"
    /// The see-through switches (FR-TOOL-260, FR-TOOL-270): tint what was cut by what
    /// cut it, and the two cuts, each on or off.
    static let seeThroughTint = "Tint"
    static let seeThroughLine = "Sight line"
    static let seeThroughWindow = "Head window"
}
