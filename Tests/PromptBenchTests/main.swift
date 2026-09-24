// What the prompt bench reports, checked without the model: the summary of a variant
// (FR-TOOL-150) and the verdict on its control (FR-TOOL-160), over results made here
// so that every count is known. The model is what the bench measures; whether the
// report says what the calls did is a question with an answer, and it is this one.
//
// Built with `BenchReport.swift` alone by `scripts/prompt-bench-selftest.sh`.
//
// verifies: FR-TOOL-150, FR-TOOL-160
import Foundation

var failures = 0
func check(_ what: String, _ ok: Bool, _ got: @autoclosure () -> String = "") {
    if ok { print("ok    \(what)") } else { print("FAIL  \(what)\(got().isEmpty ? "" : ": \(got())")"); failures += 1 }
}

func call(_ variant: String, _ kind: String, ms: Int = 100, input: Int = 300, output: Int = 40,
          line: String = "Davis: Hold!") -> BenchResult {
    BenchResult(variant: variant, scenario: "calm", ok: kind == "ok", kind: kind, detail: kind == "ok" ? "" : "why",
                ms: ms, inputTokens: kind == "ok" ? input : 0, outputTokens: kind == "ok" ? output : 0,
                line: kind == "ok" ? line : "")
}

// FR-TOOL-150: the summary counts what the calls did.
let mixed = [
    call("v1", "ok", ms: 100, input: 320, output: 40),
    call("v1", "ok", ms: 300, input: 330, output: 55),
    call("v1", "ok", ms: 200, input: 325, output: 50),
    call("v1", "refusal"), call("v1", "guardrail"), call("v1", "timeout"),
    call("other", "ok", ms: 9999, input: 1, output: 999),
]
let summary = BenchReport.summary(variant: "v1", setting: "described", results: mixed)
check("the summary counts the answered calls out of all of the variant's", summary.contains("3/6 ok"), summary)
check("and each kind of block apart", summary.contains("refusals 1, guardrail 1, other 1"), summary)
check("the input tokens of the answered calls, lowest to highest", summary.contains("input tokens 320–330"), summary)
check("the median latency of the answered calls", summary.contains("median latency 200ms"), summary)
check("the longest output", summary.contains("output tokens 55 max"), summary)
check("and names the configuration it covers (FR-TOOL-170)", summary.contains("v1 [described]"), summary)
let none = BenchReport.summary(variant: "v1", setting: "lean", results: [call("v1", "refusal")])
check("a variant whose every call was blocked reads zero, not garbage", none.contains("0/1 ok") && none.contains("input tokens 0–0"), none)

// FR-TOOL-150: every line the model returned is in the CSV, quoted.
let csv = BenchReport.csv([call("v1", "ok", line: "Pike: \"Run\", now"), call("v1", "refusal")])
let rows = csv.split(separator: "\n")
check("the CSV has a header and a row per call", rows.count == 3, "\(rows.count) rows")
check("with the line the model returned, its quotes made single", rows[1].contains("\"Pike: 'Run', now\""), String(rows[1]))

// FR-TOOL-160: a control that was never blocked voids the run.
let unblocked = [call("control", "ok"), call("control", "ok")]
check("a control never blocked says the run measured nothing",
      BenchReport.controlVerdict(variant: "control", isControl: true, results: unblocked)?.hasPrefix("RUN VOID") == true)
check("a control blocked once is a working control",
      BenchReport.controlVerdict(variant: "control", isControl: true,
                                 results: [call("control", "ok"), call("control", "guardrail")]) == nil)
check("a variant that is not a control is never a verdict",
      BenchReport.controlVerdict(variant: "v1", isControl: false, results: unblocked.map { var r = $0; r.variant = "v1"; return r }) == nil)
let run = BenchReport.runVerdict(controls: ["c1", "c2"],
                                 results: [call("c1", "refusal"), call("c2", "ok"), call("v1", "ok")])
check("the run's verdict names the control that went unblocked", run?.hasPrefix("RUN VOID: c2 was expected") == true, run ?? "nil")
check("a run whose controls were all blocked has no verdict against it",
      BenchReport.runVerdict(controls: ["c1"], results: [call("c1", "refusal"), call("v1", "ok")]) == nil)
check("a run with no control says a block could go undetected",
      BenchReport.runVerdict(controls: [], results: [call("v1", "ok")])?.hasPrefix("NOTE: no control") == true)

print(failures == 0 ? "prompt bench self-test passed" : "\(failures) check(s) failed")
exit(failures == 0 ? 0 : 1)
