// The frame record's switch, its size and its file's shape (ART-070).
//
// file implements: FR-TOOL-230, FR-TOOL-240
import Foundation

enum FrameRecording {
    /// The launch environment variable that switches the record on, and the value that
    /// does. Anything else, or nothing, leaves it off.
    static let switchVariable = "CRAWLCALL_FRAMES"
    static let switchedOn = "1"
    /// Frames kept: ten minutes at 60 a second. The oldest go first once it is full.
    static let capacity = 36_000
    /// The file in the app's documents container the record is written to.
    static let fileName = "frames"
    static let fileExtension = "csv"
    /// Milliseconds in a second, for the record's times.
    static let millisecondsPerSecond = 1_000.0
    /// How the record's columns are named, separated and written.
    static let header = "frame,time_ms,interval_ms,step_ms,deliberation_ms,see_through_ms,draw_ms,thermal,events"
    static let columnSeparator = ","
    static let eventSeparator = ";"
    /// An event that happened more than once in a frame is written with its count:
    /// `deliberation*2`.
    static let countMark = "*"
    static let lineBreak = "\n"
    /// The device's thermal state as the column writes it, by the state's raw value:
    /// the names the system gives them, and the match configuration's threshold uses.
    static let thermalNames = ["nominal", "fair", "serious", "critical"]
    static let unknownThermal = "unknown"
    /// Times are written to the microsecond.
    static let timeFormat = "%.3f"
    /// Frames are recorded one at a time, and numbered from one in the file.
    static let framesPerRecord = 1
    static let firstFrameNumber = 1
    /// An event that happened once is written by its name alone.
    static let once = 1
    /// The smallest record that can hold anything.
    static let smallestCapacity = 1
}

extension FrameRecording {
    /// The unit the record's times are kept in.
    static let millisecond = Duration.milliseconds(FrameRecording.once)
}

/// What happened in a frame that its cost might be owed to.
enum FrameEvent: String, CaseIterable {
    case matchBegan = "match_began"
    case matchEnded = "match_ended"
    case deliberation
    case mealBegan = "meal_began"
    case mealEnded = "meal_ended"
    case hit
    /// A module drawn through the hole shader for the first time: the moment its
    /// pipeline may be built on the GPU.
    case firstHole = "first_hole"
    /// A module that changed its look — solid, clear or cut open.
    case lookChanged = "look_changed"
    /// A commander call started on this frame, and one that came back on it
    /// (FR-CMD-020). Both are here because the question NFR-PERF-030 asks is about
    /// the frames *between* them: a record that shows only the slow frames cannot say
    /// whether an inference was running when they happened.
    case commanderCalled = "commander_called"
    case commanderAnswered = "commander_answered"
}
