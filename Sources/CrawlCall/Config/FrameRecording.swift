// The frame record's switch, its size and its file's shape (ART-070).
//
// implements: FR-TOOL-230, FR-TOOL-240
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
    static let header = "frame,time_ms,interval_ms,step_ms,deliberation_ms,see_through_ms,draw_ms,events"
    static let columnSeparator = ","
    static let eventSeparator = ";"
    /// An event that happened more than once in a frame is written with its count:
    /// `deliberation*2`.
    static let countMark = "*"
    static let lineBreak = "\n"
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
