// The same prompt bench, run from the command line on the Mac: the system model is the
// same one the phone runs, and without rendering a variant takes seconds instead of
// minutes. Usage: bench [variants|all] [repeats]; README.md beside this file has the rest.
// implements: FR-TOOL-150
import Foundation
import FoundationModels

@main
struct Bench {
    static func main() async {
        let args = CommandLine.arguments
        let which = args.count > 1 ? args[1] : "all"
        let repeats = args.count > 2 ? Int(args[2]) ?? 3 : 3

        if which == "patterns" {
            await SessionBench.compare(variant: PromptVariants.v2Soft, calls: repeats, budget: 2000) { print($0) }
            exit(0)
        }
        if which.hasPrefix("session") {
            let budget = Int(ProcessInfo.processInfo.environment["BENCH_BUDGET"] ?? "2000") ?? 2000
            await SessionBench.run(variant: PromptVariants.v2Soft, calls: repeats, budget: budget) { print($0) }
            exit(0)
        }
        if which == "anatomy" {
            for v in PromptVariants.all where v.name != "v4-provocative" {
                await PromptAnatomy.measure(variant: v, state: PromptBench.scenarios[1].1) { print($0) }
            }
            exit(0)
        }
        let variants = PromptVariants.named(which)
        guard !variants.isEmpty else {
            FileHandle.standardError.write("no variant matches \(which); known: \(PromptVariants.all.map(\.name).joined(separator: ", "))\n".data(using: .utf8)!)
            exit(2)
        }

        switch SystemLanguageModel.default.availability {
        case .available: break
        case .unavailable(let reason):
            FileHandle.standardError.write("model unavailable: \(reason)\n".data(using: .utf8)!)
            exit(3)
        }

        let schema = SchemaFlavour(rawValue: ProcessInfo.processInfo.environment["BENCH_SCHEMA"] ?? "described") ?? .described
        let includeSchema = ProcessInfo.processInfo.environment["BENCH_NO_SCHEMA_IN_PROMPT"] == nil
        let filter = ProcessInfo.processInfo.environment["BENCH_SCENARIOS"].map { Set($0.split(separator: ",").map(String.init)) }
        let results = await PromptBench.run(variants: variants, repeats: repeats, explainRefusals: true, schema: schema, includeSchema: includeSchema, scenarioFilter: filter, maxOutput: ProcessInfo.processInfo.environment["BENCH_MAX_OUT"].flatMap { Int($0) }) { print($0) }

        // A CSV beside the log, so a run can be compared with the next one.
        var csv = "variant,scenario,ok,kind,ms,input_tokens,output_tokens,threat,order,panic,line,detail\n"
        for r in results {
            func q(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "'") + "\"" }
            csv += "\(r.variant),\(r.scenario),\(r.ok),\(r.kind),\(r.ms),\(r.inputTokens),\(r.outputTokens),\(r.threat),\(r.order),\(r.panic),\(q(r.line)),\(q(r.detail))\n"
        }
        let f = ProcessInfo.processInfo.environment["BENCH_CSV"] ?? "bench.csv"
        try? csv.write(toFile: f, atomically: true, encoding: .utf8)
        print("csv: \(f)")
    }
}
