// The frame record of the match being played: frames added as they are drawn, events
// noted between them, and the whole written to the app's documents container when the
// match ends, the app leaves the foreground or it is asked to terminate (FR-TOOL-230,
// FR-TOOL-240). Exists only when the launch switched the record on.
//
// implements: FR-TOOL-230, FR-TOOL-240
import Foundation

@MainActor
final class FrameRecorder {
    private(set) var record: FrameRecord
    /// Events that happened since the last frame was added — a meal asked for between
    /// frames, a match begun — carried into the next one.
    private var pending = FrameRecord.Frame()
    private let clock = ContinuousClock()
    private let began: ContinuousClock.Instant
    let fileURL: URL

    init(capacity: Int = FrameRecording.capacity, fileURL: URL = FrameRecorder.defaultFileURL) {
        record = FrameRecord(capacity: capacity)
        began = clock.now
        self.fileURL = fileURL
    }

    /// Whether a launch's environment switches the record on.
    nonisolated static func isSwitchedOn(_ environment: [String: String]) -> Bool {
        environment[FrameRecording.switchVariable] == FrameRecording.switchedOn
    }

    nonisolated static var defaultFileURL: URL {
        URL.documentsDirectory.appending(path: Resource.file(FrameRecording.fileName, FrameRecording.fileExtension))
    }

    /// Milliseconds in a duration.
    nonisolated static func milliseconds(_ duration: Duration) -> Double {
        duration / FrameRecording.millisecond
    }

    /// An event that belongs to the next frame added.
    func note(_ event: FrameEvent, times: Int = FrameRecording.once) {
        pending.add(event, times: times)
    }

    /// A frame drawn: the interval the renderer measured since the one before, in
    /// seconds, and what this frame's own step spent and saw.
    func add(interval seconds: Double, _ frame: FrameRecord.Frame) {
        var complete = frame
        complete.time = Self.milliseconds(clock.now - began)
        complete.interval = seconds * FrameRecording.millisecondsPerSecond
        complete.events &+= pending.events
        pending = FrameRecord.Frame()
        record.record(complete)
    }

    /// Writes the record off the main thread, from a copy taken now: a write is the
    /// kind of work that stalls a frame.
    func writeInBackground() {
        let text = record.csv()
        let url = fileURL
        DispatchQueue.global(qos: .utility).async {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Writes the record before returning, for the moment the app is about to end.
    func writeNow() throws {
        try record.csv().write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
