// What the prompt bench reports, apart from the model that produced it: one call's
// result, the summary of a variant, the verdict on a run's control and the CSV a run
// leaves behind. Kept free of FoundationModels so that it can be tested on its own —
// the model is what the bench measures, and a test of the report must not need one.
// implements: FR-TOOL-150, FR-TOOL-160
import Foundation

/// One call: what the model did with one variant on one scenario.
struct BenchResult {
    var variant: String
    var scenario: String
    var ok: Bool
    var kind: String       // "ok", "refusal", "guardrail", other error
    var detail: String
    var ms: Int
    var inputTokens: Int
    var outputTokens: Int
    var line: String
    var threat: String = ""
    var order: String = ""
    var panic: Double = -1
}

enum BenchReport {
    /// The summary line of one variant (FR-TOOL-150): how many calls answered, how
    /// many the model blocked and how, the input tokens, the median latency and the
    /// longest output. `setting` names the configuration it covers (FR-TOOL-170).
    static func summary(variant: String, setting: String, results: [BenchResult]) -> String {
        let mine = results.filter { $0.variant == variant }
        let bad = mine.filter { !$0.ok }
        let toks = mine.filter(\.ok).map(\.inputTokens)
        return "BENCH SUMMARY \(variant) [\(setting)]: \(mine.count - bad.count)/\(mine.count) ok, refusals \(bad.filter { $0.kind == "refusal" }.count), guardrail \(bad.filter { $0.kind == "guardrail" }.count), other \(bad.filter { $0.kind != "refusal" && $0.kind != "guardrail" }.count), input tokens \(toks.min() ?? 0)–\(toks.max() ?? 0), median latency \(median(mine.filter(\.ok).map(\.ms)))ms, output tokens \(mine.filter(\.ok).map(\.outputTokens).max() ?? 0) max"
    }

    /// The line a control prints when none of its calls was blocked (FR-TOOL-160); nil
    /// where at least one was, and for a variant that is not a control.
    static func controlVerdict(variant: String, isControl: Bool, results: [BenchResult]) -> String? {
        let mine = results.filter { $0.variant == variant }
        guard isControl, mine.allSatisfy(\.ok) else { return nil }
        return "RUN VOID: the control \(variant) was not blocked in any of its \(mine.count) calls, so this run measured nothing — see FR-TOOL-160"
    }

    /// The run's own verdict (FR-TOOL-160): void when a control went unblocked, a note
    /// when there was no control to tell a block from its absence, nothing otherwise.
    static func runVerdict(controls: [String], results: [BenchResult]) -> String? {
        guard !controls.isEmpty else {
            return "NOTE: no control in this run — a block could go undetected (FR-TOOL-160)"
        }
        let unblocked = controls.filter { c in results.filter { $0.variant == c }.allSatisfy(\.ok) }
        guard !unblocked.isEmpty else { return nil }
        return "RUN VOID: \(unblocked.joined(separator: ", ")) was expected to be blocked and was not; no number in this run is a measurement"
    }

    /// Every call as a row, the line it returned included (FR-TOOL-150). A text field
    /// is quoted, with its own double quotes turned to single ones.
    static func csv(_ results: [BenchResult]) -> String {
        func q(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "'") + "\"" }
        var csv = "variant,scenario,ok,kind,ms,input_tokens,output_tokens,threat,order,panic,line,detail\n"
        for r in results {
            csv += "\(r.variant),\(r.scenario),\(r.ok),\(r.kind),\(r.ms),\(r.inputTokens),\(r.outputTokens),\(r.threat),\(r.order),\(r.panic),\(q(r.line)),\(q(r.detail))\n"
        }
        return csv
    }

    static func median(_ xs: [Int]) -> Int {
        guard !xs.isEmpty else { return 0 }
        let s = xs.sorted(); return s[s.count / 2]
    }
}
