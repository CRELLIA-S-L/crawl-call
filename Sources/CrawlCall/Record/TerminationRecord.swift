// Writes the frame record when the app is asked to terminate (FR-TOOL-240). A run on
// the device ends with SIGTERM (FR-TOOL-180), and a process that dies of it leaves
// nothing behind.
//
// A signal dispatch source only reports a signal's arrival and "cannot catch signals to
// prevent termination" (Apple, Concurrency Programming Guide, *Monitoring a Signal*),
// so the default action is set aside with `signal(SIGTERM, SIG_IGN)`, as the guide's
// own listing does, and the app ends itself once the file is written. Installed only
// while the record is switched on: a game played without it terminates as it always did.
//
// implements: FR-TOOL-240
import Foundation

@MainActor
enum TerminationRecord {
    /// Starts listening for SIGTERM; the source is returned for the caller to keep,
    /// since a released source stops listening.
    static func install(writing recorder: FrameRecorder) -> DispatchSourceSignal {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { try? recorder.writeNow() }
            exit(EXIT_SUCCESS)
        }
        source.activate()
        return source
    }
}
