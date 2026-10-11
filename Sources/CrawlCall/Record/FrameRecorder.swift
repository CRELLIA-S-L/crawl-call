// The frame record of the match being played: frames added as they are drawn, events
// noted between them, and the whole written to the app's documents container when the
// match ends, the app leaves the foreground or it is asked to terminate (FR-TOOL-230,
// FR-TOOL-240). Exists only when the launch switched the record on.
//
// file implements: FR-TOOL-230, FR-TOOL-240
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
    /// Where the device's thermal state is read from: the system's, but for a test.
    private let thermal: () -> ProcessInfo.ThermalState

    init(capacity: Int = FrameRecording.capacity, fileURL: URL = FrameRecorder.defaultFileURL,
         thermal: @escaping () -> ProcessInfo.ThermalState = { ProcessInfo.processInfo.thermalState }) {
        record = FrameRecord(capacity: capacity)
        self.thermal = thermal
        began = clock.now
        self.fileURL = fileURL
        // A record left by an earlier run must not pass for this one's: a run that
        // writes nothing — a crash, a kill — leaves no file rather than an old one.
        try? FileManager.default.removeItem(at: fileURL)
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
        complete.thermal = thermal()
        for event in FrameEvent.allCases {
            complete.add(event, times: pending.count(of: event))
        }
        pending = FrameRecord.Frame()
        record.record(complete)
    }

    /// Writes the record off the main thread, from a copy taken now: turning a full
    /// ring into text and writing it are the kind of work that stalls a frame, so both
    /// happen off it. The copy is the value as it is — the ring's storage is shared
    /// until a later frame writes to it.
    func writeInBackground() {
        let snapshot = record
        let url = fileURL
        DispatchQueue.global(qos: .utility).async {
            try? snapshot.csv().write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Writes the record before returning, for the moment the app is about to end.
    func writeNow() throws {
        try record.csv().write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
